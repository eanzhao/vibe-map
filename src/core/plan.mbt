///|
/// Summary of what `Dag::plan_from_docs` did.
pub(all) struct PlanReport {
  added_goals : Array[String]
  added_tasks : Array[String]
  skipped_goals : Array[String]
  skipped_tasks : Array[String]
} derive(Debug, ToJson)

///|
/// Scan markdown files for planning items and synthesize nodes. `format`
/// selects the parser:
///   - `"checklist"` (default): `- [ ]` unchecked items. Each `.md` file
///     becomes a goal; each item becomes a todo task.
///   - `"tlist"`: chengsheng-style `## T<N> — <title>` headings with a
///     `**Status:** ✅|open|partially resolved|blocked` line below. Each
///     `.md` file is a goal; each T-section is a task with status
///     mapped from the Status line.
///
/// `paths` accepts both files and directories. Directories are walked
/// recursively, skipping dot-dirs and `_build`. Re-running on the same DAG
/// only adds new nodes.
pub fn Dag::plan_from_docs(
  self : Dag,
  paths : Array[String],
  format? : String = "checklist",
) -> PlanReport raise DagError {
  let md_files = []
  for p in paths {
    collect_markdown(p, md_files)
  }
  md_files.sort_by((a, b) => a.lexical_compare(b))
  let report : PlanReport = {
    added_goals: [],
    added_tasks: [],
    skipped_goals: [],
    skipped_tasks: [],
  }
  for md_path in md_files {
    let raw = @fs.read_file_to_string(md_path) catch {
      err => raise IoError("read \{md_path}: \{@debug.to_repr(err)}")
    }
    match format {
      "checklist" => self.ingest_checklist(md_path, raw, report)
      "tlist" => self.ingest_tlist(md_path, raw, report)
      other =>
        raise ParseError(
          "unknown plan format: \{other} (expected checklist | tlist)",
        )
    }
  }
  report
}

///|
fn Dag::ingest_checklist(
  self : Dag,
  md_path : String,
  raw : String,
  report : PlanReport,
) -> Unit raise DagError {
  let items = parse_checklist_items(raw)
  if items.length() == 0 {
    return
  }
  let stem = doc_stem(md_path)
  let m_id = "plan-" + slugify(stem)
  if self.has_goal(m_id) {
    report.skipped_goals.push(m_id)
  } else {
    self.add_goal(
      id=m_id,
      title=stem,
      description="Planned items extracted from \{md_path}",
      docs=[md_path],
    )
    report.added_goals.push(m_id)
  }
  for item in items {
    let i_id = m_id + "-" + slug_short(item)
    if self.has_task(i_id) {
      report.skipped_tasks.push(i_id)
    } else {
      self.add_task(id=i_id, goal=m_id, title=item, status=Todo, docs=[md_path])
      report.added_tasks.push(i_id)
    }
  }
}

///|
fn Dag::ingest_tlist(
  self : Dag,
  md_path : String,
  raw : String,
  report : PlanReport,
) -> Unit raise DagError {
  let items = parse_tlist_items(raw)
  if items.length() == 0 {
    return
  }
  let stem = doc_stem(md_path)
  let m_id = "plan-" + slugify(stem)
  if self.has_goal(m_id) {
    report.skipped_goals.push(m_id)
  } else {
    self.add_goal(
      id=m_id,
      title=stem,
      description="T-items extracted from \{md_path}",
      docs=[md_path],
    )
    report.added_goals.push(m_id)
  }
  for item in items {
    let i_id = m_id + "-t" + item.number
    if self.has_task(i_id) {
      report.skipped_tasks.push(i_id)
    } else {
      self.add_task(
        id=i_id,
        goal=m_id,
        title="T\{item.number} — \{item.title}",
        status=item.status,
        docs=[md_path],
      )
      report.added_tasks.push(i_id)
    }
  }
}

///|
/// One parsed T-section.
priv struct TlistItem {
  number : String
  title : String
  status : Status
}

///|
/// Parse `## T<N> — <title>` headings with their `**Status:**` lines.
/// Headings whose title starts with `~~` (struck-through) are skipped.
fn parse_tlist_items(raw : String) -> Array[TlistItem] {
  let out : Array[TlistItem] = []
  let mut in_code = false
  let mut current_number = ""
  let mut current_title = ""
  let mut waiting_for_status = false
  for line_view in raw.split("\n") {
    let line = line_view.to_owned()
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("```") || trimmed.has_prefix("~~~") {
      in_code = !in_code
      continue
    }
    if in_code {
      continue
    }
    match parse_t_header(trimmed) {
      Some(parsed) => {
        // Flush a pending T-section that never got a Status line.
        if waiting_for_status && !current_title.has_prefix("~~") {
          out.push({
            number: current_number,
            title: current_title,
            status: Todo,
          })
        }
        current_number = parsed.0
        current_title = parsed.1
        waiting_for_status = true
        continue
      }
      None => ()
    }
    if waiting_for_status {
      match parse_status_line(trimmed) {
        Some(status) => {
          if !current_title.has_prefix("~~") {
            out.push({ number: current_number, title: current_title, status })
          }
          waiting_for_status = false
        }
        None => ()
      }
    }
  }
  if waiting_for_status && !current_title.has_prefix("~~") {
    out.push({ number: current_number, title: current_title, status: Todo })
  }
  out
}

///|
/// Match `## T<N> — <title>` (em-dash) or `## T<N> - <title>` (hyphen).
/// Returns `Some((number, title))` if matched.
fn parse_t_header(line : String) -> (String, String)? {
  if !line.has_prefix("## T") {
    return None
  }
  let rest = line[4:line.length()].to_owned()
  let sb = StringBuilder::new()
  let mut consumed = 0
  for ch in rest {
    if ch >= '0' && ch <= '9' {
      sb.write_char(ch)
      consumed = consumed + 1
    } else {
      break
    }
  }
  let number = sb.to_string()
  if number == "" {
    return None
  }
  let after = rest[consumed:rest.length()].to_owned().trim().to_owned()
  let title = if after.has_prefix("—") {
    after[1:after.length()].to_owned().trim().to_owned()
  } else if after.has_prefix("-") {
    after[1:after.length()].to_owned().trim().to_owned()
  } else {
    return None
  }
  Some((number, title))
}

///|
/// Match `**Status:** <text>` and map text to a vmap Status.
fn parse_status_line(line : String) -> Status? {
  let prefix = "**Status:**"
  let rest = if line.has_prefix(prefix) {
    line[prefix.length():line.length()].to_owned().trim().to_owned()
  } else {
    let prefix2 = "**Status**:"
    if line.has_prefix(prefix2) {
      line[prefix2.length():line.length()].to_owned().trim().to_owned()
    } else {
      return None
    }
  }
  Some(map_status_text(rest))
}

///|
/// Map free-text status to a vmap Status enum. Lenient: substring match.
fn map_status_text(text : String) -> Status {
  // Check `partial` before `resolved` because "partially resolved" contains
  // both — and we want the more specific match to win.
  if text.contains("partial") ||
    text.contains("in progress") ||
    text.contains("in-progress") {
    InProgress
  } else if text.contains("blocked") || text.contains("阻塞") {
    Blocked
  } else if text.contains("✅") ||
    text.contains("resolved") ||
    text.contains("done") {
    Done
  } else {
    Todo
  }
}

///|
/// Walk a path and append every `.md` (or `.mbt.md`) file path to `out`.
fn collect_markdown(path : String, out : Array[String]) -> Unit raise DagError {
  if !@fs.path_exists(path) {
    raise IoError("path not found: \{path}")
  }
  let is_dir = @fs.is_dir(path) catch {
    err => raise IoError("stat \{path}: \{@debug.to_repr(err)}")
  }
  if is_dir {
    let entries = @fs.read_dir(path) catch {
      err => raise IoError("read_dir \{path}: \{@debug.to_repr(err)}")
    }
    entries.sort_by((a, b) => a.lexical_compare(b))
    for entry in entries {
      if entry.has_prefix(".") || entry == "_build" || entry == "node_modules" {
        continue
      }
      collect_markdown("\{path}/\{entry}", out)
    }
  } else if path.has_suffix(".md") {
    out.push(path)
  }
}

///|
/// Extract every unchecked checklist item (`- [ ]` or `* [ ]`) from a markdown
/// document, skipping anything inside fenced code blocks.
fn parse_checklist_items(raw : String) -> Array[String] {
  let items = []
  let mut in_code = false
  for line_view in raw.split("\n") {
    let line = line_view.to_owned()
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("```") || trimmed.has_prefix("~~~") {
      in_code = !in_code
      continue
    }
    if in_code {
      continue
    }
    let text = checklist_text(trimmed)
    if text != "" {
      items.push(text)
    }
  }
  items
}

///|
/// Return the text after a `- [ ]` marker (or `* [ ]`), or "" if the line
/// isn't an unchecked checklist item. `[x]` / `[X]` (checked) are ignored.
fn checklist_text(line : String) -> String {
  for marker in ["- [ ] ", "* [ ] ", "- [ ]", "* [ ]"] {
    if line.has_prefix(marker) {
      return line[marker.length():line.length()].to_owned().trim().to_owned()
    }
  }
  ""
}

///|
/// Filename stem: drop dir prefix and trailing extensions. Handles `.mbt.md`
/// as a single extension.
fn doc_stem(path : String) -> String {
  let basename = match last_index_of(path, '/') {
    Some(idx) => path[idx + 1:path.length()].to_owned()
    None => path
  }
  if basename.has_suffix(".mbt.md") {
    basename[0:basename.length() - 7].to_owned()
  } else if basename.has_suffix(".md") {
    basename[0:basename.length() - 3].to_owned()
  } else {
    basename
  }
}

///|
fn last_index_of(s : String, ch : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for c in s {
    if c == ch {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    None
  } else {
    Some(found)
  }
}

///|
/// Short slug suitable for a task id: lowercase, alnum, dashes, truncated to
/// 40 chars. Empty input yields "item".
fn slug_short(text : String) -> String {
  let sb = StringBuilder::new()
  let mut last_dash = true
  let mut written = 0
  for ch in text {
    if written >= 40 {
      break
    }
    let c = lower(ch)
    if is_alnum(c) {
      sb.write_char(c)
      last_dash = false
      written = written + 1
    } else if !last_dash {
      sb.write_char('-')
      last_dash = true
      written = written + 1
    }
  }
  let raw = sb.to_string()
  // Trim trailing dash.
  let trimmed = if raw.has_suffix("-") {
    raw[0:raw.length() - 1].to_owned()
  } else {
    raw
  }
  if trimmed == "" {
    "item"
  } else {
    trimmed
  }
}

///|
fn lower(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    let code = ch.to_int() + 32
    code.unsafe_to_char()
  } else {
    ch
  }
}

///|
fn is_alnum(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
}

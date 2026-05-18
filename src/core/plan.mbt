///|
/// Summary of what `Dag::plan_from_docs` did.
pub(all) struct PlanReport {
  added_milestones : Array[String]
  added_issues : Array[String]
  skipped_milestones : Array[String]
  skipped_issues : Array[String]
} derive(Show, ToJson)

///|
/// Scan markdown files for `- [ ]` checklist items and synthesize `todo`
/// nodes. Each `.md` (or `.mbt.md`) file becomes a milestone (file stem →
/// title); each unchecked item becomes an issue.
///
/// `paths` accepts both files and directories. Directories are walked
/// recursively, skipping dot-dirs and `_build`. Re-running on the same DAG
/// only adds new nodes.
pub fn Dag::plan_from_docs(
  self : Dag,
  paths : Array[String],
) -> PlanReport raise DagError {
  let md_files = []
  for p in paths {
    collect_markdown(p, md_files)
  }
  md_files.sort_by((a, b) => a.lexical_compare(b))
  let report : PlanReport = {
    added_milestones: [],
    added_issues: [],
    skipped_milestones: [],
    skipped_issues: [],
  }
  for md_path in md_files {
    let raw = @fs.read_file_to_string(md_path) catch {
      err => raise IoError("read \{md_path}: \{err}")
    }
    let items = parse_checklist_items(raw)
    if items.length() == 0 {
      continue
    }
    let stem = doc_stem(md_path)
    let m_id = "plan-" + slugify(stem)
    if self.has_milestone(m_id) {
      report.skipped_milestones.push(m_id)
    } else {
      self.add_milestone(
        id=m_id,
        title=stem,
        description="Planned items extracted from \{md_path}",
        docs=[md_path],
      )
      report.added_milestones.push(m_id)
    }
    for item in items {
      let i_id = m_id + "-" + slug_short(item)
      if self.has_issue(i_id) {
        report.skipped_issues.push(i_id)
      } else {
        self.add_issue(id=i_id, milestone=m_id, title=item, status=Todo, docs=[
          md_path,
        ])
        report.added_issues.push(i_id)
      }
    }
  }
  report
}

///|
/// Walk a path and append every `.md` (or `.mbt.md`) file path to `out`.
fn collect_markdown(path : String, out : Array[String]) -> Unit raise DagError {
  if not(@fs.path_exists(path)) {
    raise IoError("path not found: \{path}")
  }
  let is_dir = @fs.is_dir(path) catch {
    err => raise IoError("stat \{path}: \{err}")
  }
  if is_dir {
    let entries = @fs.read_dir(path) catch {
      err => raise IoError("read_dir \{path}: \{err}")
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
    let line = line_view.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("```") || trimmed.has_prefix("~~~") {
      in_code = not(in_code)
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
      return line[marker.length():line.length()].to_string().trim().to_string()
    }
  }
  ""
}

///|
/// Filename stem: drop dir prefix and trailing extensions. Handles `.mbt.md`
/// as a single extension.
fn doc_stem(path : String) -> String {
  let basename = match last_index_of(path, '/') {
    Some(idx) => path[idx + 1:path.length()].to_string()
    None => path
  }
  if basename.has_suffix(".mbt.md") {
    basename[0:basename.length() - 7].to_string()
  } else if basename.has_suffix(".md") {
    basename[0:basename.length() - 3].to_string()
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
/// Short slug suitable for an issue id: lowercase, alnum, dashes, truncated to
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
    } else if not(last_dash) {
      sb.write_char('-')
      last_dash = true
      written = written + 1
    }
  }
  let raw = sb.to_string()
  // Trim trailing dash.
  let trimmed = if raw.has_suffix("-") {
    raw[0:raw.length() - 1].to_string()
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

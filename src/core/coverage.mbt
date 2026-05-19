///|
/// `vmap coverage` — report how much of the project's docs / source layout /
/// GitHub issues is actually reflected in the DAG. The output is intentionally
/// flat / boring so it round-trips through `--json` and stays easy to gate on.
pub(all) struct CoverageReport {
  docs : DocsCoverage?
  code : CodeCoverage?
  issues : IssuesCoverage?
  /// Lowest of the three percentages computed in this run.
  overall_score : Double
  /// Which dimension is the bottleneck — `docs` | `code` | `issues` |
  /// `(none)` if nothing was computed.
  weakest : String
  /// Total markdown files inspected as the docs universe.
  scanned_md_files : Int
  /// Top-level source dirs inspected as the code universe.
  scanned_code_dirs : Int
} derive(Show, ToJson)

///|
pub(all) struct DocsCoverage {
  /// Total markdown files found under `roots`.
  total : Int
  /// Files whose path (or basename) appears in some goal/task field.
  referenced : Int
  /// `referenced / total * 100`, or 100.0 if `total == 0`.
  pct : Double
  /// Files not referenced anywhere. Capped at `max_examples` (default 50) so
  /// the JSON stays readable for big repos; full list available in
  /// `unreferenced_total`.
  unreferenced_examples : Array[String]
  unreferenced_total : Int
} derive(Show, ToJson)

///|
pub(all) struct CodeCoverage {
  /// Top-level subdirectories of `src_root` that look like first-class
  /// modules (not hidden, not build/test artifacts).
  total : Int
  /// Dirs whose name appears (case-insensitive substring) in some
  /// goal/task id or title.
  matched : Int
  pct : Double
  /// Dirs without any matching DAG node — these are the most common
  /// "codebase ↔ DAG mismatch" signal.
  unmatched : Array[String]
} derive(Show, ToJson)

///|
pub(all) struct IssuesCoverage {
  total : Int
  open : Int
  closed : Int
  /// Issues whose number/URL appears in some goal/task field. Direct
  /// references only — we don't run gh_query offline, so fuzzy matches
  /// from `gh_query` are surfaced separately via `goals_with_gh_query`.
  referenced_direct : Int
  /// Issues with no direct reference. Capped at `max_examples`. Each
  /// entry is `"#<number> <state> — <title>"`.
  unreferenced_examples : Array[String]
  unreferenced_total : Int
  /// Count of goals whose `gh_query` field is non-empty. These claim
  /// fuzzy coverage but we can't verify offline — the user should run
  /// `tools/audit_github.py` for strict checking.
  goals_with_gh_query : Int
  pct : Double
} derive(Show, ToJson)

///|
/// Minimal shape we accept from `gh issue list --json number,title,state,url`.
/// Anything richer is allowed and ignored.
pub(all) struct IssueEntry {
  number : Int
  title : String
  state : String
  url : String
} derive(Show, ToJson, FromJson)

///|
/// Run all three coverage checks. `scan_roots` is the paths to scan for
/// markdown (empty means "auto-detect: `.` recursively"). `src_root` is the
/// root for top-level code dirs (empty means "auto-detect: `src` if it
/// exists, else `lib`, else skip"). `issues_file` is a path to a JSON file
/// produced by `gh issue list --json number,title,state,url` (empty means
/// skip the issues dimension). `run_docs/code/issues` flags scope which
/// dimensions to actually compute — useful for `--docs-only` etc.
pub fn Dag::coverage(
  self : Dag,
  scan_roots : Array[String],
  src_root : String,
  issues_file : String,
  run_docs : Bool,
  run_code : Bool,
  run_issues : Bool,
  max_examples? : Int = 50,
) -> CoverageReport raise DagError {
  let referenced_text = collect_referenced_text(self)
  let docs_report : DocsCoverage? = if run_docs {
    let roots = if scan_roots.length() == 0 { ["."] } else { scan_roots }
    Some(compute_docs_coverage(roots, referenced_text, max_examples))
  } else {
    None
  }
  let code_report : CodeCoverage? = if run_code {
    let effective_src = if src_root != "" {
      src_root
    } else {
      detect_default_src()
    }
    if effective_src == "" || not(@fs.path_exists(effective_src)) {
      None
    } else {
      Some(compute_code_coverage(self, effective_src))
    }
  } else {
    None
  }
  let issues_report : IssuesCoverage? = if run_issues && issues_file != "" {
    Some(compute_issues_coverage(self, issues_file, max_examples))
  } else {
    None
  }
  let scanned_md = match docs_report {
    Some(d) => d.total
    None => 0
  }
  let scanned_code = match code_report {
    Some(c) => c.total
    None => 0
  }
  let (overall, weakest) = pick_weakest(docs_report, code_report, issues_report)
  {
    docs: docs_report,
    code: code_report,
    issues: issues_report,
    overall_score: overall,
    weakest,
    scanned_md_files: scanned_md,
    scanned_code_dirs: scanned_code,
  }
}

///|
/// Build the universe of text we'll grep for doc-path / issue-number /
/// dirname matches. Every text field of every goal/task contributes.
fn collect_referenced_text(dag : Dag) -> Array[String] {
  let out : Array[String] = []
  for g in dag.goals {
    out.push(g.id)
    out.push(g.title)
    out.push(g.description)
    for d in g.docs {
      out.push(d)
    }
    for t in g.tests {
      out.push(t)
    }
    match g.gh_query {
      Some(q) => out.push(q)
      None => ()
    }
  }
  for t in dag.tasks {
    out.push(t.id)
    out.push(t.title)
    out.push(t.notes)
    for d in t.docs {
      out.push(d)
    }
    for x in t.tests {
      out.push(x)
    }
  }
  out
}

///|
/// Walk `roots` and find every `.md` file, then mark each as referenced or
/// not by checking whether any of `referenced_text` contains the path or
/// basename as a substring.
fn compute_docs_coverage(
  roots : Array[String],
  referenced_text : Array[String],
  max_examples : Int,
) -> DocsCoverage raise DagError {
  let files : Array[String] = []
  for r in roots {
    collect_md_files(r, files)
  }
  files.sort_by((a, b) => a.lexical_compare(b))
  let unreferenced : Array[String] = []
  let mut referenced = 0
  for path in files {
    let base = basename_of_path(path)
    if any_contains(referenced_text, path) ||
      any_contains(referenced_text, base) {
      referenced = referenced + 1
    } else {
      unreferenced.push(path)
    }
  }
  let total = files.length()
  let pct = pct_of(referenced, total)
  let examples = if unreferenced.length() <= max_examples {
    unreferenced
  } else {
    unreferenced[0:max_examples].to_array()
  }
  {
    total,
    referenced,
    pct,
    unreferenced_examples: examples,
    unreferenced_total: unreferenced.length(),
  }
}

///|
/// Walk top-level of `src_root` and mark each child dir as matched or
/// unmatched by whether some goal/task id-or-title contains its name.
fn compute_code_coverage(
  dag : Dag,
  src_root : String,
) -> CodeCoverage raise DagError {
  let dirs = scan_top_dirs(src_root)
  let ids_and_titles : Array[String] = []
  for g in dag.goals {
    ids_and_titles.push(lower_str(g.id))
    ids_and_titles.push(lower_str(g.title))
  }
  for t in dag.tasks {
    ids_and_titles.push(lower_str(t.id))
    ids_and_titles.push(lower_str(t.title))
  }
  let unmatched : Array[String] = []
  let mut matched = 0
  for d in dirs {
    let key = lower_str(basename_of_path(d))
    if any_contains(ids_and_titles, key) {
      matched = matched + 1
    } else {
      unmatched.push(d)
    }
  }
  let total = dirs.length()
  let pct = pct_of(matched, total)
  { total, matched, pct, unmatched }
}

///|
/// Parse the JSON output of `gh issue list --json number,title,state,url`
/// (an array of objects), then mark each issue as direct-referenced or not
/// by checking whether `#<n>` or its URL appears in any goal/task field.
fn compute_issues_coverage(
  dag : Dag,
  issues_file : String,
  max_examples : Int,
) -> IssuesCoverage raise DagError {
  let raw = @fs.read_file_to_string(issues_file) catch {
    err => raise IoError("read \{issues_file}: \{err}")
  }
  let parsed = @json.parse(raw) catch {
    err => raise ParseError("parse \{issues_file}: \{err}")
  }
  let entries : Array[IssueEntry] = @json.from_json(parsed) catch {
    err => raise ParseError("decode \{issues_file}: \{err}")
  }
  let text = collect_referenced_text(dag)
  let unreferenced : Array[String] = []
  let mut open_count = 0
  let mut closed_count = 0
  let mut direct = 0
  for e in entries {
    if e.state == "OPEN" || e.state == "open" {
      open_count = open_count + 1
    } else {
      closed_count = closed_count + 1
    }
    if issue_ref_is_direct(text, e.number, e.url) {
      direct = direct + 1
    } else {
      let state_label = e.state
      unreferenced.push("#\{e.number} \{state_label} — \{e.title}")
    }
  }
  let mut gh_query_count = 0
  for g in dag.goals {
    match g.gh_query {
      Some(q) => if q != "" { gh_query_count = gh_query_count + 1 }
      None => ()
    }
  }
  let total = entries.length()
  let pct = pct_of(direct, total)
  let examples = if unreferenced.length() <= max_examples {
    unreferenced
  } else {
    unreferenced[0:max_examples].to_array()
  }
  {
    total,
    open: open_count,
    closed: closed_count,
    referenced_direct: direct,
    unreferenced_examples: examples,
    unreferenced_total: unreferenced.length(),
    goals_with_gh_query: gh_query_count,
    pct,
  }
}

///|
/// Decide which dimension is the bottleneck. None of them computed = 100/none.
fn pick_weakest(
  d : DocsCoverage?,
  c : CodeCoverage?,
  i : IssuesCoverage?,
) -> (Double, String) {
  let mut min_pct = 100.0
  let mut min_kind = "(none)"
  match d {
    Some(x) =>
      if x.pct < min_pct {
        min_pct = x.pct
        min_kind = "docs"
      }
    None => ()
  }
  match c {
    Some(x) =>
      if x.pct < min_pct {
        min_pct = x.pct
        min_kind = "code"
      }
    None => ()
  }
  match i {
    Some(x) =>
      if x.pct < min_pct {
        min_pct = x.pct
        min_kind = "issues"
      }
    None => ()
  }
  (min_pct, min_kind)
}

///|
/// Recursively collect `.md` files under `path`, skipping hidden / build /
/// dependency dirs. Shared with the doctor + future commands.
fn collect_md_files(path : String, out : Array[String]) -> Unit raise DagError {
  if not(@fs.path_exists(path)) {
    return
  }
  let is_dir = @fs.is_dir(path) catch {
    err => raise IoError("stat \{path}: \{err}")
  }
  if is_dir {
    if should_skip_walk_dir(basename_of_path(path)) {
      return
    }
    let entries = @fs.read_dir(path) catch {
      err => raise IoError("read_dir \{path}: \{err}")
    }
    entries.sort_by((a, b) => a.lexical_compare(b))
    for e in entries {
      if e.has_prefix(".") || should_skip_walk_dir(e) {
        continue
      }
      collect_md_files("\{path}/\{e}", out)
    }
  } else if path.has_suffix(".md") {
    out.push(normalize_dot_slash(path))
  }
}

///|
/// Top-level child directories of `root`, returned as relative paths.
/// Skips dot-dirs and the usual build artifacts.
fn scan_top_dirs(root : String) -> Array[String] raise DagError {
  let out : Array[String] = []
  if not(@fs.path_exists(root)) {
    return out
  }
  let is_dir = @fs.is_dir(root) catch {
    err => raise IoError("stat \{root}: \{err}")
  }
  if not(is_dir) {
    return out
  }
  let entries = @fs.read_dir(root) catch {
    err => raise IoError("read_dir \{root}: \{err}")
  }
  entries.sort_by((a, b) => a.lexical_compare(b))
  for e in entries {
    if e.has_prefix(".") || should_skip_walk_dir(e) {
      continue
    }
    let full = "\{root}/\{e}"
    let child_is_dir = @fs.is_dir(full) catch { _ => false }
    if child_is_dir {
      out.push(full)
    }
  }
  out
}

///|
fn detect_default_src() -> String {
  for candidate in ["src", "lib", "app", "packages"] {
    if @fs.path_exists(candidate) {
      return candidate
    }
  }
  ""
}

///|
fn should_skip_walk_dir(name : String) -> Bool {
  match name {
    "_build" => true
    "node_modules" => true
    "target" => true
    ".venv" => true
    ".vmap" => true
    ".git" => true
    ".mooncakes" => true
    "dist" => true
    "build" => true
    "out" => true
    _ => false
  }
}

///|
fn basename_of_path(path : String) -> String {
  let mut last_slash = -1
  let mut i = 0
  for ch in path {
    if ch == '/' {
      last_slash = i
    }
    i = i + 1
  }
  if last_slash < 0 {
    path
  } else {
    path[last_slash + 1:path.length()].to_string()
  }
}

///|
fn normalize_dot_slash(path : String) -> String {
  if path.has_prefix("./") {
    path[2:path.length()].to_string()
  } else {
    path
  }
}

///|
fn lower_str(s : String) -> String {
  let sb = StringBuilder::new()
  for ch in s {
    if ch >= 'A' && ch <= 'Z' {
      let code = ch.to_int() + 32
      sb.write_char(code.unsafe_to_char())
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn any_contains(haystacks : Array[String], needle : String) -> Bool {
  if needle == "" {
    return false
  }
  for s in haystacks {
    if s.contains(needle) {
      return true
    }
  }
  false
}

///|
fn issue_ref_is_direct(
  texts : Array[String],
  number : Int,
  url : String,
) -> Bool {
  let needle_hash = "#" + number.to_string()
  let needle_path = "issues/" + number.to_string()
  for s in texts {
    if contains_with_digit_boundary(s, needle_hash) ||
      contains_with_digit_boundary(s, needle_path) ||
      contains_with_digit_boundary(s, url) {
      return true
    }
  }
  false
}

///|
/// Match `#7` / `issues/7` / full issue URL without treating `#71` or
/// `issues/71` as a hit for issue 7.
fn contains_with_digit_boundary(text : String, needle : String) -> Bool {
  if needle == "" || text.length() < needle.length() {
    return false
  }
  for i in 0..<=(text.length() - needle.length()) {
    let suffix = text[i:text.length()].to_string()
    if suffix.has_prefix(needle) && not(has_digit_after_prefix(suffix, needle)) {
      return true
    }
  }
  false
}

///|
fn has_digit_after_prefix(text : String, prefix : String) -> Bool {
  text.has_prefix(prefix + "0") ||
  text.has_prefix(prefix + "1") ||
  text.has_prefix(prefix + "2") ||
  text.has_prefix(prefix + "3") ||
  text.has_prefix(prefix + "4") ||
  text.has_prefix(prefix + "5") ||
  text.has_prefix(prefix + "6") ||
  text.has_prefix(prefix + "7") ||
  text.has_prefix(prefix + "8") ||
  text.has_prefix(prefix + "9")
}

///|
fn pct_of(num : Int, denom : Int) -> Double {
  if denom == 0 {
    return 100.0
  }
  num.to_double() * 100.0 / denom.to_double()
}

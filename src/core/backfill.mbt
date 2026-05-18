///|
/// Summary of what `Dag::backfill_moonbit` did. AI-friendly: each field is a
/// stable id list, so callers can diff or display "what changed."
pub(all) struct BackfillReport {
  added_milestones : Array[String]
  added_issues : Array[String]
  skipped_milestones : Array[String]
  skipped_issues : Array[String]
} derive(Show, ToJson)

///|
/// Walk a MoonBit source tree and synthesize milestones (one per package) and
/// issues (one per non-test `.mbt` file). Auto-binds:
///   - `tests` to sibling `*_test.mbt` / `*_wbtest.mbt` for each source file
///   - `docs` to a sibling `<stem>.mbt.md` or the package `README*.md`
/// Nodes whose generated id already exists are left alone (merge semantics).
pub fn Dag::backfill_moonbit(
  self : Dag,
  src_root : String,
) -> BackfillReport raise DagError {
  if not(@fs.path_exists(src_root)) {
    raise IoError("source root not found: \{src_root}")
  }
  let normalized_root = strip_trailing_slash(src_root)
  let packages = discover_packages(normalized_root)
  // Sort by relative path for deterministic id generation. The default String
  // ordering is shortlex (length-first); use `lexical_compare` so paths sort
  // the way humans expect.
  packages.sort_by((a, b) => a.0.lexical_compare(b.0))
  let report : BackfillReport = {
    added_milestones: [],
    added_issues: [],
    skipped_milestones: [],
    skipped_issues: [],
  }
  for pkg in packages {
    let rel_path = pkg.0
    let abs_path = pkg.1
    let m_id = milestone_id_for(rel_path)
    if self.has_milestone(m_id) {
      report.skipped_milestones.push(m_id)
    } else {
      let pkg_docs = find_package_docs(abs_path)
      self.add_milestone(
        id=m_id,
        title=rel_path,
        description="Backfilled MoonBit package",
        regression_testable=true,
        docs=pkg_docs,
      )
      report.added_milestones.push(m_id)
    }
    let files = @fs.read_dir(abs_path) catch {
      err => raise IoError("read_dir \{abs_path}: \{err}")
    }
    files.sort()
    for file in files {
      if not(is_source_file(file)) {
        continue
      }
      let stem = strip_suffix(file, ".mbt")
      let i_id = issue_id_for(rel_path, stem)
      if self.has_issue(i_id) {
        report.skipped_issues.push(i_id)
        continue
      }
      let tests = find_test_files(files, stem)
      let docs = find_issue_docs(files, stem)
      self.add_issue(
        id=i_id,
        milestone=m_id,
        title=file,
        status=Done,
        regression_testable=true,
        tests~,
        docs~,
      )
      report.added_issues.push(i_id)
    }
  }
  report
}

///|
/// True if `name` is a MoonBit source file (and not a test/wbtest file).
fn is_source_file(name : String) -> Bool {
  if not(name.has_suffix(".mbt")) {
    return false
  }
  if name.has_suffix("_test.mbt") {
    return false
  }
  if name.has_suffix("_wbtest.mbt") {
    return false
  }
  if name.has_suffix("_blackbox_test.mbt") {
    return false
  }
  true
}

///|
/// `path/to/dir/` -> `path/to/dir`. Leaves bare names alone.
fn strip_trailing_slash(path : String) -> String {
  if path.length() > 1 && path.has_suffix("/") {
    path[0:path.length() - 1].to_string()
  } else {
    path
  }
}

///|
fn strip_suffix(s : String, suffix : String) -> String {
  if s.has_suffix(suffix) {
    s[0:s.length() - suffix.length()].to_string()
  } else {
    s
  }
}

///|
/// Walk a directory tree and return `(rel_path_from_root, abs_path)` for every
/// directory that contains `moon.pkg` or `moon.pkg.json`.
fn discover_packages(root : String) -> Array[(String, String)] raise DagError {
  let out = []
  walk_for_packages(root, root, out)
  out
}

///|
fn walk_for_packages(
  root : String,
  current : String,
  out : Array[(String, String)],
) -> Unit raise DagError {
  let is_dir = @fs.is_dir(current) catch {
    err => raise IoError("stat \{current}: \{err}")
  }
  if not(is_dir) {
    return
  }
  let has_pkg = @fs.path_exists("\{current}/moon.pkg") ||
    @fs.path_exists("\{current}/moon.pkg.json")
  if has_pkg {
    out.push((relative_path(root, current), current))
  }
  let entries = @fs.read_dir(current) catch {
    err => raise IoError("read_dir \{current}: \{err}")
  }
  entries.sort_by((a, b) => a.lexical_compare(b))
  for entry in entries {
    // Skip dotted dirs (.git, .mooncakes, _build, etc.) and the build output.
    if entry.has_prefix(".") || entry == "_build" {
      continue
    }
    walk_for_packages(root, "\{current}/\{entry}", out)
  }
}

///|
/// Naive relative path: strip the `root` prefix and one leading slash. Both
/// inputs are expected to be normalized (no trailing slash, forward slashes).
fn relative_path(root : String, abs : String) -> String {
  if abs == root {
    return "."
  }
  if abs.has_prefix(root + "/") {
    abs[root.length() + 1:abs.length()].to_string()
  } else {
    abs
  }
}

///|
/// Replace `/`, ` `, and `.` with `-` so paths become safe DAG ids.
fn slugify(path : String) -> String {
  let sb = StringBuilder::new()
  for ch in path {
    if ch == '/' || ch == ' ' || ch == '.' {
      sb.write_char('-')
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn milestone_id_for(rel_path : String) -> String {
  if rel_path == "." {
    "pkg-root"
  } else {
    "pkg-" + slugify(rel_path)
  }
}

///|
fn issue_id_for(rel_path : String, stem : String) -> String {
  let base = if rel_path == "." { "" } else { slugify(rel_path) + "-" }
  base + slugify(stem)
}

///|
/// In `pkg_files`, find tests that go with `stem`: `<stem>_test.mbt`,
/// `<stem>_wbtest.mbt`, `<stem>_blackbox_test.mbt`.
fn find_test_files(pkg_files : Array[String], stem : String) -> Array[String] {
  let out = []
  for
    candidate in [
      stem + "_test.mbt",
      stem + "_wbtest.mbt",
      stem + "_blackbox_test.mbt",
    ] {
    if contains(pkg_files, candidate) {
      out.push(candidate)
    }
  }
  out
}

///|
/// Find docs for an issue: a sibling `<stem>.mbt.md` if present.
fn find_issue_docs(pkg_files : Array[String], stem : String) -> Array[String] {
  let candidate = stem + ".mbt.md"
  if contains(pkg_files, candidate) {
    [candidate]
  } else {
    []
  }
}

///|
/// Find docs for a package: `README.md`, `README.mbt.md`.
fn find_package_docs(pkg_dir : String) -> Array[String] {
  let out = []
  for name in ["README.md", "README.mbt.md"] {
    if @fs.path_exists("\{pkg_dir}/\{name}") {
      out.push(name)
    }
  }
  out
}

///|
fn contains(arr : Array[String], needle : String) -> Bool {
  for item in arr {
    if item == needle {
      return true
    }
  }
  false
}

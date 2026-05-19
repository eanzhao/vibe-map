///|
/// Summary of what a backfill run did. AI-friendly: each field is a stable id
/// list, so callers can diff or display "what changed."
pub(all) struct BackfillReport {
  template : String
  added_milestones : Array[String]
  added_issues : Array[String]
  skipped_milestones : Array[String]
  skipped_issues : Array[String]
} derive(Show, ToJson)

///|
/// Run a backfill template against `src_root` and merge the result into this
/// DAG. Existing milestone/issue ids are left alone. Returns a report of
/// what was added vs skipped.
pub fn Dag::backfill(
  self : Dag,
  src_root : String,
  template : Template,
) -> BackfillReport raise DagError {
  let packages = template.discover(src_root)
  let report : BackfillReport = {
    template: template.name,
    added_milestones: [],
    added_issues: [],
    skipped_milestones: [],
    skipped_issues: [],
  }
  for pkg in packages {
    let m_id = milestone_id_for(pkg.rel_path)
    if self.has_milestone(m_id) {
      report.skipped_milestones.push(m_id)
    } else {
      self.add_milestone(
        id=m_id,
        title=pkg.title,
        description="Backfilled via template `\{template.name}`",
        regression_testable=true,
        docs=pkg.docs,
      )
      report.added_milestones.push(m_id)
    }
    for issue in pkg.issues {
      let i_id = issue_id_for(pkg.rel_path, issue.stem)
      if self.has_issue(i_id) {
        report.skipped_issues.push(i_id)
      } else {
        self.add_issue(
          id=i_id,
          milestone=m_id,
          title=issue.title,
          status=Done,
          regression_testable=true,
          tests=issue.tests,
          docs=issue.docs,
        )
        report.added_issues.push(i_id)
      }
    }
  }
  report
}

///|
/// Convenience wrapper: backfill using the built-in MoonBit template.
pub fn Dag::backfill_moonbit(
  self : Dag,
  src_root : String,
) -> BackfillReport raise DagError {
  let template = match find_template_by_name("moonbit") {
    Some(t) => t
    None => raise ParseError("built-in moonbit template missing")
  }
  self.backfill(src_root, template)
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
/// `path/to/dir/` -> `path/to/dir`. Leaves bare names alone.
fn strip_trailing_slash(path : String) -> String {
  if path.length() > 1 && path.has_suffix("/") {
    path[0:path.length() - 1].to_string()
  } else {
    path
  }
}

///|
/// Naive relative path: strip the `root` prefix and one leading slash.
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

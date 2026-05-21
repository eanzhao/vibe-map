///|
/// Summary of what a backfill run did. AI-friendly: each field is a stable id
/// list, so callers can diff or display "what changed."
pub(all) struct BackfillReport {
  template : String
  added_goals : Array[String]
  added_tasks : Array[String]
  skipped_goals : Array[String]
  skipped_tasks : Array[String]
} derive(Debug, ToJson)

///|
/// Run a backfill template against `src_root` and merge the result into this
/// DAG. Existing goal/task ids are left alone. Returns a report of
/// what was added vs skipped.
pub fn Dag::backfill(
  self : Dag,
  src_root : String,
  template : Template,
) -> BackfillReport raise DagError {
  let packages = template.discover(src_root)
  let report : BackfillReport = {
    template: template.name,
    added_goals: [],
    added_tasks: [],
    skipped_goals: [],
    skipped_tasks: [],
  }
  for pkg in packages {
    let m_id = goal_id_for(pkg.rel_path)
    if self.has_goal(m_id) {
      report.skipped_goals.push(m_id)
    } else {
      self.add_goal(
        id=m_id,
        title=pkg.title,
        description="Backfilled via template `\{template.name}`",
        regression_testable=true,
        docs=pkg.docs,
      )
      report.added_goals.push(m_id)
    }
    for task in pkg.tasks {
      let i_id = task_id_for(pkg.rel_path, task.stem)
      if self.has_task(i_id) {
        report.skipped_tasks.push(i_id)
      } else {
        self.add_task(
          id=i_id,
          goal=m_id,
          title=task.title,
          status=Done,
          regression_testable=true,
          tests=task.tests,
          docs=task.docs,
        )
        report.added_tasks.push(i_id)
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
fn goal_id_for(rel_path : String) -> String {
  if rel_path == "." {
    "pkg-root"
  } else {
    "pkg-" + slugify(rel_path)
  }
}

///|
fn task_id_for(rel_path : String, stem : String) -> String {
  let base = if rel_path == "." { "" } else { slugify(rel_path) + "-" }
  base + slugify(stem)
}

///|
/// `path/to/dir/` -> `path/to/dir`. Leaves bare names alone.
fn strip_trailing_slash(path : String) -> String {
  if path.length() > 1 && path.has_suffix("/") {
    path[0:path.length() - 1].to_owned()
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
    abs[root.length() + 1:abs.length()].to_owned()
  } else {
    abs
  }
}

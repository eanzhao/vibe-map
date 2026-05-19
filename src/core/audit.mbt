///|
/// A single audit finding. Flat-shaped so it serializes cleanly for AI
/// consumption: `kind` discriminates, `message` is human-readable.
pub(all) struct Violation {
  kind : String
  node_id : String
  node_kind : String
  message : String
} derive(Eq, Show, ToJson)

///|
fn is_empty_option(value : String?) -> Bool {
  match value {
    Some(v) => v == ""
    None => true
  }
}

///|
fn is_none_int(value : Int?) -> Bool {
  match value {
    Some(_) => false
    None => true
  }
}

///|
fn is_none_bool(value : Bool?) -> Bool {
  match value {
    Some(_) => false
    None => true
  }
}

///|
fn is_none_map(value : Map[String, String]?) -> Bool {
  match value {
    Some(_) => false
    None => true
  }
}

///|
fn add_missing_region_metadata(
  violations : Array[Violation],
  goal : Goal,
  field : String,
  reason : String,
) -> Unit {
  violations.push({
    kind: "missing_region_metadata",
    node_id: goal.id,
    node_kind: "goal",
    message: "goal is missing `\{field}` (\{reason})",
  })
}

///|
/// Result of running `audit` over a DAG.
pub(all) struct AuditReport {
  ok : Bool
  violations : Array[Violation]
} derive(Eq, Show, ToJson)

///|
/// Two rules:
/// 1. `MissingTests` — any node with `regression_testable=true` and an empty
///    `tests` list. The author has declared that tests should exist.
/// 2. `MissingDocs` — any node where `status != Todo` and `docs` is empty.
///    Anything that's shipped or being shipped should be documented.
///    Pure todo nodes are skipped (you can't doc what's not built yet).
pub fn Dag::audit(self : Dag) -> AuditReport {
  let violations = []
  for m in self.goals {
    if is_empty_option(m.closure) {
      add_missing_region_metadata(
        violations, m, "closure", "monotonic region stage",
      )
    }
    if is_empty_option(m.formal) {
      add_missing_region_metadata(
        violations, m, "formal", "automation/evidence level",
      )
    }
    if is_empty_option(m.product) {
      add_missing_region_metadata(
        violations, m, "product", "config-backed product key",
      )
    }
    if is_empty_option(m.owner) {
      add_missing_region_metadata(
        violations, m, "owner", "GitHub owner or team",
      )
    }
    if is_none_int(m.issue_count) {
      add_missing_region_metadata(
        violations, m, "issue_count", "GitHub issue/task count",
      )
    }
    if is_none_bool(m.focus) {
      add_missing_region_metadata(violations, m, "focus", "current-focus flag")
    }
    if is_none_bool(m.archived) {
      add_missing_region_metadata(violations, m, "archived", "archive flag")
    }
    if is_none_map(m.promoted_at) {
      add_missing_region_metadata(
        violations, m, "promoted_at", "promotion timeline",
      )
    }
    if is_empty_option(m.gh_query) {
      add_missing_region_metadata(
        violations, m, "gh_query", "GitHub drift query",
      )
    }
    if m.regression_testable && m.tests.length() == 0 {
      violations.push({
        kind: "missing_tests",
        node_id: m.id,
        node_kind: "goal",
        message: "goal is regression-testable but has no `tests` entries",
      })
    }
    // Goals don't have a status field, so always check docs.
    if m.docs.length() == 0 {
      violations.push({
        kind: "missing_docs",
        node_id: m.id,
        node_kind: "goal",
        message: "goal has no `docs` entries",
      })
    }
  }
  for i in self.tasks {
    if i.regression_testable && i.tests.length() == 0 {
      violations.push({
        kind: "missing_tests",
        node_id: i.id,
        node_kind: "task",
        message: "task is regression-testable but has no `tests` entries",
      })
    }
    if not(i.status is Todo) && i.docs.length() == 0 {
      violations.push({
        kind: "missing_docs",
        node_id: i.id,
        node_kind: "task",
        message: "task is past `todo` but has no `docs` entries",
      })
    }
  }
  { ok: violations.length() == 0, violations }
}

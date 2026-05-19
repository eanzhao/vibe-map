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

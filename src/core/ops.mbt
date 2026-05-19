///|
/// True if `id` names a milestone in the DAG.
pub fn Dag::has_milestone(self : Dag, id : String) -> Bool {
  for m in self.milestones {
    if m.id == id {
      return true
    }
  }
  false
}

///|
/// True if `id` names an issue in the DAG.
pub fn Dag::has_issue(self : Dag, id : String) -> Bool {
  for i in self.issues {
    if i.id == id {
      return true
    }
  }
  false
}

///|
/// True if `id` names either a milestone or an issue.
pub fn Dag::has_id(self : Dag, id : String) -> Bool {
  self.has_milestone(id) || self.has_issue(id)
}

///|
/// Find an issue by id (linear scan; DAGs stay small enough that a map is
/// premature).
pub fn Dag::find_issue(self : Dag, id : String) -> (Int, Issue)? {
  for idx, issue in self.issues {
    if issue.id == id {
      return Some((idx, issue))
    }
  }
  None
}

///|
/// Find a milestone by id.
pub fn Dag::find_milestone(self : Dag, id : String) -> (Int, Milestone)? {
  for idx, m in self.milestones {
    if m.id == id {
      return Some((idx, m))
    }
  }
  None
}

///|
/// Append a new milestone. Raises `DuplicateId` if the id exists, or
/// `UnknownId` if any dep is unknown. Cycle detection runs after insertion.
pub fn Dag::add_milestone(
  self : Dag,
  id~ : String,
  title~ : String,
  description? : String = "",
  deps? : Array[String] = [],
  regression_testable? : Bool = false,
  tests? : Array[String] = [],
  docs? : Array[String] = [],
) -> Unit raise DagError {
  if self.has_id(id) {
    raise DuplicateId(id)
  }
  for d in deps {
    if not(self.has_milestone(d)) {
      raise UnknownId("milestone dep \{d}")
    }
  }
  self.milestones.push({
    id,
    title,
    description,
    deps,
    regression_testable,
    tests,
    docs,
  })
  self.assert_acyclic()
}

///|
/// Append a new issue. The owning milestone must exist; deps must be other
/// existing issues. Cycle detection runs after insertion.
pub fn Dag::add_issue(
  self : Dag,
  id~ : String,
  milestone~ : String,
  title~ : String,
  deps? : Array[String] = [],
  notes? : String = "",
  status? : Status = Todo,
  regression_testable? : Bool = false,
  tests? : Array[String] = [],
  docs? : Array[String] = [],
) -> Unit raise DagError {
  if self.has_id(id) {
    raise DuplicateId(id)
  }
  if not(self.has_milestone(milestone)) {
    raise UnknownMilestone(milestone)
  }
  for d in deps {
    if not(self.has_issue(d)) {
      raise UnknownId("issue dep \{d}")
    }
  }
  self.issues.push({
    id,
    milestone,
    title,
    status,
    deps,
    notes,
    regression_testable,
    tests,
    docs,
  })
  self.assert_acyclic()
}

///|
/// Mutate the status of an issue in place. Errors if the id is not an issue.
pub fn Dag::update_status(
  self : Dag,
  id : String,
  status : Status,
) -> Unit raise DagError {
  match self.find_issue(id) {
    Some((idx, issue)) => self.issues[idx] = { ..issue, status, }
    None => raise UnknownId(id)
  }
}

///|
/// Set the title on either a milestone or an issue.
pub fn Dag::update_title(
  self : Dag,
  id : String,
  title : String,
) -> Unit raise DagError {
  match self.find_milestone(id) {
    Some((idx, m)) => {
      self.milestones[idx] = { ..m, title, }
      return
    }
    None => ()
  }
  match self.find_issue(id) {
    Some((idx, issue)) => self.issues[idx] = { ..issue, title, }
    None => raise UnknownId(id)
  }
}

///|
/// Set `regression_testable` on either a milestone or an issue.
pub fn Dag::set_regression_testable(
  self : Dag,
  id : String,
  value : Bool,
) -> Unit raise DagError {
  match self.find_milestone(id) {
    Some((idx, m)) => {
      self.milestones[idx] = { ..m, regression_testable: value }
      return
    }
    None => ()
  }
  match self.find_issue(id) {
    Some((idx, issue)) =>
      self.issues[idx] = { ..issue, regression_testable: value }
    None => raise UnknownId(id)
  }
}

///|
/// Replace the test list on either a milestone or an issue.
pub fn Dag::set_tests(
  self : Dag,
  id : String,
  tests : Array[String],
) -> Unit raise DagError {
  match self.find_milestone(id) {
    Some((idx, m)) => {
      self.milestones[idx] = { ..m, tests, }
      return
    }
    None => ()
  }
  match self.find_issue(id) {
    Some((idx, issue)) => self.issues[idx] = { ..issue, tests, }
    None => raise UnknownId(id)
  }
}

///|
/// Replace the docs list on either a milestone or an issue.
pub fn Dag::set_docs(
  self : Dag,
  id : String,
  docs : Array[String],
) -> Unit raise DagError {
  match self.find_milestone(id) {
    Some((idx, m)) => {
      self.milestones[idx] = { ..m, docs, }
      return
    }
    None => ()
  }
  match self.find_issue(id) {
    Some((idx, issue)) => self.issues[idx] = { ..issue, docs, }
    None => raise UnknownId(id)
  }
}

///|
/// Remove a node by id. Also strips it from any other node's deps. If the id
/// names a milestone, all issues under it are removed too.
pub fn Dag::remove(self : Dag, id : String) -> Unit raise DagError {
  if self.has_milestone(id) {
    // Drop the milestone, drop dependent issues, then scrub remaining deps.
    self.milestones.retain(m => m.id != id)
    self.issues.retain(i => i.milestone != id)
    for idx, m in self.milestones {
      let next = m.deps.copy()
      next.retain(d => d != id)
      self.milestones[idx] = { ..m, deps: next }
    }
  } else if self.has_issue(id) {
    self.issues.retain(i => i.id != id)
    for idx, i in self.issues {
      let next = i.deps.copy()
      next.retain(d => d != id)
      self.issues[idx] = { ..i, deps: next }
    }
  } else {
    raise UnknownId(id)
  }
}

///|
/// Run every structural validator against this DAG: id uniqueness across
/// milestones+issues, issue→milestone references resolve, dep references
/// resolve at their layer (milestone deps point at milestones, issue deps at
/// issues), and the dep graph is acyclic. Raises on the first violation.
pub fn Dag::validate(self : Dag) -> Unit raise DagError {
  let seen : Map[String, Bool] = {}
  for m in self.milestones {
    if seen.contains(m.id) {
      raise DuplicateId(m.id)
    }
    seen[m.id] = true
  }
  for i in self.issues {
    if seen.contains(i.id) {
      raise DuplicateId(i.id)
    }
    seen[i.id] = true
  }
  for i in self.issues {
    if not(self.has_milestone(i.milestone)) {
      raise UnknownMilestone("issue \{i.id} -> \{i.milestone}")
    }
  }
  for m in self.milestones {
    for d in m.deps {
      if not(self.has_milestone(d)) {
        raise UnknownId("milestone \{m.id} dep -> \{d}")
      }
    }
  }
  for i in self.issues {
    for d in i.deps {
      if not(self.has_issue(d)) {
        raise UnknownId("issue \{i.id} dep -> \{d}")
      }
    }
  }
  self.assert_acyclic()
}

///|
/// Run depth-first cycle detection across milestones and issues. Edges go
/// from a node to each of its deps; a back-edge means a cycle.
pub fn Dag::assert_acyclic(self : Dag) -> Unit raise DagError {
  // 0 = unseen, 1 = on stack, 2 = done
  let state : Map[String, Int] = {}
  for m in self.milestones {
    state[m.id] = 0
  }
  for i in self.issues {
    state[i.id] = 0
  }
  fn deps_of(id : String) -> Array[String] {
    match self.find_milestone(id) {
      Some((_, m)) => m.deps
      None =>
        match self.find_issue(id) {
          Some((_, i)) => i.deps
          None => []
        }
    }
  }

  fn visit(id : String) -> Unit raise DagError {
    match state.get(id) {
      Some(1) => raise CycleDetected(id)
      Some(2) => ()
      _ => {
        state[id] = 1
        for d in deps_of(id) {
          visit(d)
        }
        state[id] = 2
      }
    }
  }

  for m in self.milestones {
    visit(m.id)
  }
  for i in self.issues {
    visit(i.id)
  }
}

///|
/// Issues filed under a milestone, in insertion order.
pub fn Dag::issues_of(self : Dag, milestone_id : String) -> Array[Issue] {
  let out = []
  for i in self.issues {
    if i.milestone == milestone_id {
      out.push(i)
    }
  }
  out
}

///|
/// Progress of a milestone as `(done, total)` issues.
pub fn Dag::progress(self : Dag, milestone_id : String) -> (Int, Int) {
  let mut done = 0
  let mut total = 0
  for i in self.issues {
    if i.milestone == milestone_id {
      total = total + 1
      if i.status is Done {
        done = done + 1
      }
    }
  }
  (done, total)
}

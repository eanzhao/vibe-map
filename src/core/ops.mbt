///|
/// True if `id` names a goal in the DAG.
pub fn Dag::has_goal(self : Dag, id : String) -> Bool {
  for m in self.goals {
    if m.id == id {
      return true
    }
  }
  false
}

///|
/// True if `id` names a task in the DAG.
pub fn Dag::has_task(self : Dag, id : String) -> Bool {
  for i in self.tasks {
    if i.id == id {
      return true
    }
  }
  false
}

///|
/// True if `id` names either a goal or a task.
pub fn Dag::has_id(self : Dag, id : String) -> Bool {
  self.has_goal(id) || self.has_task(id)
}

///|
/// Find a task by id (linear scan; DAGs stay small enough that a map is
/// premature).
pub fn Dag::find_task(self : Dag, id : String) -> (Int, Task)? {
  for idx, task in self.tasks {
    if task.id == id {
      return Some((idx, task))
    }
  }
  None
}

///|
/// Find a goal by id.
pub fn Dag::find_goal(self : Dag, id : String) -> (Int, Goal)? {
  for idx, m in self.goals {
    if m.id == id {
      return Some((idx, m))
    }
  }
  None
}

///|
/// Append a new goal. Raises `DuplicateId` if the id exists, or
/// `UnknownId` if any dep is unknown. Cycle detection runs after insertion.
pub fn Dag::add_goal(
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
    if not(self.has_goal(d)) {
      raise UnknownId("goal dep \{d}")
    }
  }
  self.goals.push({
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
/// Append a new task. The owning goal must exist; deps must be other
/// existing tasks. Cycle detection runs after insertion.
pub fn Dag::add_task(
  self : Dag,
  id~ : String,
  goal~ : String,
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
  if not(self.has_goal(goal)) {
    raise UnknownGoal(goal)
  }
  for d in deps {
    if not(self.has_task(d)) {
      raise UnknownId("task dep \{d}")
    }
  }
  self.tasks.push({
    id,
    goal,
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
/// Mutate the status of a task in place. Errors if the id is not a task.
pub fn Dag::update_status(
  self : Dag,
  id : String,
  status : Status,
) -> Unit raise DagError {
  match self.find_task(id) {
    Some((idx, task)) => self.tasks[idx] = { ..task, status, }
    None => raise UnknownId(id)
  }
}

///|
/// Set the title on either a goal or a task.
pub fn Dag::update_title(
  self : Dag,
  id : String,
  title : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => {
      self.goals[idx] = { ..m, title, }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, task)) => self.tasks[idx] = { ..task, title, }
    None => raise UnknownId(id)
  }
}

///|
/// Set `regression_testable` on either a goal or a task.
pub fn Dag::set_regression_testable(
  self : Dag,
  id : String,
  value : Bool,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => {
      self.goals[idx] = { ..m, regression_testable: value }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, task)) =>
      self.tasks[idx] = { ..task, regression_testable: value }
    None => raise UnknownId(id)
  }
}

///|
/// Replace the test list on either a goal or a task.
pub fn Dag::set_tests(
  self : Dag,
  id : String,
  tests : Array[String],
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => {
      self.goals[idx] = { ..m, tests, }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, task)) => self.tasks[idx] = { ..task, tests, }
    None => raise UnknownId(id)
  }
}

///|
/// Replace the docs list on either a goal or a task.
pub fn Dag::set_docs(
  self : Dag,
  id : String,
  docs : Array[String],
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => {
      self.goals[idx] = { ..m, docs, }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, task)) => self.tasks[idx] = { ..task, docs, }
    None => raise UnknownId(id)
  }
}

///|
/// Remove a node by id. Also strips it from any other node's deps. If the id
/// names a goal, all tasks under it are removed too.
pub fn Dag::remove(self : Dag, id : String) -> Unit raise DagError {
  if self.has_goal(id) {
    // Drop the goal, drop dependent tasks, then scrub remaining deps.
    self.goals.retain(m => m.id != id)
    self.tasks.retain(i => i.goal != id)
    for idx, m in self.goals {
      let next = m.deps.copy()
      next.retain(d => d != id)
      self.goals[idx] = { ..m, deps: next }
    }
  } else if self.has_task(id) {
    self.tasks.retain(i => i.id != id)
    for idx, i in self.tasks {
      let next = i.deps.copy()
      next.retain(d => d != id)
      self.tasks[idx] = { ..i, deps: next }
    }
  } else {
    raise UnknownId(id)
  }
}

///|
/// Run every structural validator against this DAG: id uniqueness across
/// goals+tasks, task→goal references resolve, dep references
/// resolve at their layer (goal deps point at goals, task deps at
/// tasks), and the dep graph is acyclic. Raises on the first violation.
pub fn Dag::validate(self : Dag) -> Unit raise DagError {
  let seen : Map[String, Bool] = {}
  for m in self.goals {
    if seen.contains(m.id) {
      raise DuplicateId(m.id)
    }
    seen[m.id] = true
  }
  for i in self.tasks {
    if seen.contains(i.id) {
      raise DuplicateId(i.id)
    }
    seen[i.id] = true
  }
  for i in self.tasks {
    if not(self.has_goal(i.goal)) {
      raise UnknownGoal("task \{i.id} -> \{i.goal}")
    }
  }
  for m in self.goals {
    for d in m.deps {
      if not(self.has_goal(d)) {
        raise UnknownId("goal \{m.id} dep -> \{d}")
      }
    }
  }
  for i in self.tasks {
    for d in i.deps {
      if not(self.has_task(d)) {
        raise UnknownId("task \{i.id} dep -> \{d}")
      }
    }
  }
  self.assert_acyclic()
}

///|
/// Run depth-first cycle detection across goals and tasks. Edges go
/// from a node to each of its deps; a back-edge means a cycle.
pub fn Dag::assert_acyclic(self : Dag) -> Unit raise DagError {
  // 0 = unseen, 1 = on stack, 2 = done
  let state : Map[String, Int] = {}
  for m in self.goals {
    state[m.id] = 0
  }
  for i in self.tasks {
    state[i.id] = 0
  }
  fn deps_of(id : String) -> Array[String] {
    match self.find_goal(id) {
      Some((_, m)) => m.deps
      None =>
        match self.find_task(id) {
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

  for m in self.goals {
    visit(m.id)
  }
  for i in self.tasks {
    visit(i.id)
  }
}

///|
/// Tasks filed under a goal, in insertion order.
pub fn Dag::tasks_of(self : Dag, goal_id : String) -> Array[Task] {
  let out = []
  for i in self.tasks {
    if i.goal == goal_id {
      out.push(i)
    }
  }
  out
}

///|
/// Progress of a goal as `(done, total)` tasks.
pub fn Dag::progress(self : Dag, goal_id : String) -> (Int, Int) {
  let mut done = 0
  let mut total = 0
  for i in self.tasks {
    if i.goal == goal_id {
      total = total + 1
      if i.status is Done {
        done = done + 1
      }
    }
  }
  (done, total)
}

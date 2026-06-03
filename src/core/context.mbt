///|
/// Minimal context derived from DAG edges and node-owned file lists.
///
/// `files` is the de-duplicated, lexicographically sorted union of `docs` and
/// `tests` attached to the target node and the dependency slice.
/// `ancestor_goals` contains goal ids only; the target goal itself is excluded.
pub(all) struct ContextSlice {
  files : Array[String]
  ancestor_goals : Array[String]
} derive(Eq, Debug)

///|
pub impl ToJson for ContextSlice with to_json(self) {
  let payload : Map[String, Json] = {
    "files": self.files.to_json(),
    "ancestorGoals": self.ancestor_goals.to_json(),
  }
  payload.to_json()
}

///|
fn push_unique_context_value(
  out : Array[String],
  seen : Map[String, Bool],
  value : String,
) -> Unit {
  if value == "" || seen.contains(value) {
    return
  }
  seen[value] = true
  out.push(value)
}

///|
fn add_file_list(
  files : Array[String],
  seen : Map[String, Bool],
  values : Array[String],
) -> Unit {
  for value in values {
    push_unique_context_value(files, seen, value)
  }
}

///|
fn add_goal_self_files(
  goal : Goal,
  files : Array[String],
  seen : Map[String, Bool],
) -> Unit {
  add_file_list(files, seen, goal.docs)
  add_file_list(files, seen, goal.tests)
}

///|
fn add_task_self_files(
  task : Task,
  files : Array[String],
  seen : Map[String, Bool],
) -> Unit {
  add_file_list(files, seen, task.docs)
  add_file_list(files, seen, task.tests)
}

///|
fn Dag::add_goal_owned_files(
  self : Dag,
  goal_id : String,
  files : Array[String],
  seen : Map[String, Bool],
) -> Unit raise DagError {
  match self.find_goal(goal_id) {
    Some((_, goal)) => add_goal_self_files(goal, files, seen)
    None => raise UnknownGoal(goal_id)
  }
  for task in self.tasks {
    if task.goal == goal_id {
      add_task_self_files(task, files, seen)
    }
  }
}

///|
fn Dag::collect_ancestor_goals(
  self : Dag,
  goal_id : String,
  seen : Map[String, Bool],
  out : Array[String],
) -> Unit raise DagError {
  match self.find_goal(goal_id) {
    Some((_, goal)) =>
      for dep in goal.deps {
        if !self.has_goal(dep) {
          raise UnknownId("goal \{goal_id} dep -> \{dep}")
        }
        if !seen.contains(dep) {
          seen[dep] = true
          out.push(dep)
          self.collect_ancestor_goals(dep, seen, out)
        }
      }
    None => raise UnknownGoal(goal_id)
  }
}

///|
fn Dag::collect_upstream_tasks(
  self : Dag,
  task_id : String,
  seen : Map[String, Bool],
  out : Array[String],
) -> Unit raise DagError {
  match self.find_task(task_id) {
    Some((_, task)) =>
      for dep in task.deps {
        if !self.has_task(dep) {
          raise UnknownId("task \{task_id} dep -> \{dep}")
        }
        if !seen.contains(dep) {
          seen[dep] = true
          out.push(dep)
          self.collect_upstream_tasks(dep, seen, out)
        }
      }
    None => raise UnknownId(task_id)
  }
}

///|
fn sorted_context_values(values : Array[String]) -> Array[String] {
  let out = values.copy()
  out.sort_by((a, b) => a.lexical_compare(b))
  out
}

///|
fn Dag::context_for_goal(
  self : Dag,
  goal : Goal,
) -> ContextSlice raise DagError {
  let files : Array[String] = []
  let file_seen : Map[String, Bool] = {}
  let ancestor_goals : Array[String] = []
  let goal_seen : Map[String, Bool] = {}
  self.collect_ancestor_goals(goal.id, goal_seen, ancestor_goals)
  self.add_goal_owned_files(goal.id, files, file_seen)
  for goal_id in ancestor_goals {
    self.add_goal_owned_files(goal_id, files, file_seen)
  }
  {
    files: sorted_context_values(files),
    ancestor_goals: sorted_context_values(ancestor_goals),
  }
}

///|
fn Dag::context_for_task(
  self : Dag,
  task : Task,
) -> ContextSlice raise DagError {
  let files : Array[String] = []
  let file_seen : Map[String, Bool] = {}
  let ancestor_goals : Array[String] = []
  let goal_seen : Map[String, Bool] = {}
  self.collect_ancestor_goals(task.goal, goal_seen, ancestor_goals)
  match self.find_goal(task.goal) {
    Some((_, goal)) => add_goal_self_files(goal, files, file_seen)
    None => raise UnknownGoal(task.goal)
  }
  add_task_self_files(task, files, file_seen)
  for goal_id in ancestor_goals {
    self.add_goal_owned_files(goal_id, files, file_seen)
  }
  let upstream_tasks : Array[String] = []
  let task_seen : Map[String, Bool] = {}
  self.collect_upstream_tasks(task.id, task_seen, upstream_tasks)
  for task_id in upstream_tasks {
    match self.find_task(task_id) {
      Some((_, dep_task)) => {
        add_task_self_files(dep_task, files, file_seen)
        if dep_task.goal != task.goal && !goal_seen.contains(dep_task.goal) {
          goal_seen[dep_task.goal] = true
          ancestor_goals.push(dep_task.goal)
          self.collect_ancestor_goals(dep_task.goal, goal_seen, ancestor_goals)
          match self.find_goal(dep_task.goal) {
            Some((_, dep_goal)) =>
              add_goal_self_files(dep_goal, files, file_seen)
            None => raise UnknownGoal(dep_task.goal)
          }
        }
      }
      None => raise UnknownId(task_id)
    }
  }
  {
    files: sorted_context_values(files),
    ancestor_goals: sorted_context_values(ancestor_goals),
  }
}

///|
/// Derive the minimal deterministic context slice for a goal or task.
///
/// The current schema already carries the needed information:
///   - `deps` encodes goal→goal and task→task dependency edges.
///   - `docs` and `tests` encode file ownership / reading-list entries.
pub fn Dag::context(self : Dag, id : String) -> ContextSlice raise DagError {
  match self.find_goal(id) {
    Some((_, goal)) => return self.context_for_goal(goal)
    None => ()
  }
  match self.find_task(id) {
    Some((_, task)) => self.context_for_task(task)
    None => raise UnknownId(id)
  }
}

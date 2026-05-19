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
fn non_empty_or_none(value : String) -> String? {
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn config_has_closure(cfg : VmapConfig, key : String) -> Bool {
  for tier in cfg.closure_tiers {
    if tier.key == key {
      return true
    }
  }
  false
}

///|
fn config_has_formal(cfg : VmapConfig, key : String) -> Bool {
  for level in cfg.formal_levels {
    if level.key == key {
      return true
    }
  }
  false
}

///|
fn config_has_product(cfg : VmapConfig, key : String) -> Bool {
  for product in cfg.products {
    if product.key == key {
      return true
    }
  }
  false
}

///|
fn hex_color_like(color : String) -> Bool {
  color.length() == 7 && color.has_prefix("#")
}

///|
fn check_unique_key(
  seen : Map[String, Bool],
  key : String,
  context : String,
) -> Unit raise DagError {
  if key == "" {
    raise InvalidMetadata("\{context}.key must not be empty")
  }
  if seen.contains(key) {
    raise InvalidMetadata("\{context}.key duplicate: \{key}")
  }
  seen[key] = true
}

///|
fn check_config(cfg : VmapConfig) -> Unit raise DagError {
  if cfg.products.length() == 0 {
    raise InvalidMetadata("config.products must not be empty")
  }
  if cfg.closure_tiers.length() == 0 {
    raise InvalidMetadata("config.closure_tiers must not be empty")
  }
  if cfg.formal_levels.length() == 0 {
    raise InvalidMetadata("config.formal_levels must not be empty")
  }
  let seen_products : Map[String, Bool] = {}
  for product in cfg.products {
    check_unique_key(seen_products, product.key, "config.products")
  }
  let seen_closures : Map[String, Bool] = {}
  for tier in cfg.closure_tiers {
    check_unique_key(seen_closures, tier.key, "config.closure_tiers")
    if not(hex_color_like(tier.color)) {
      raise InvalidMetadata(
        "config.closure_tiers.\{tier.key}.color must be #RRGGBB",
      )
    }
  }
  let seen_formals : Map[String, Bool] = {}
  for formal in cfg.formal_levels {
    check_unique_key(seen_formals, formal.key, "config.formal_levels")
  }
}

///|
fn closure_index(cfg : VmapConfig, key : String) -> Int? {
  for i, tier in cfg.closure_tiers {
    if tier.key == key {
      return Some(i)
    }
  }
  None
}

///|
fn check_goal_region(
  cfg : VmapConfig,
  id : String,
  closure : String?,
  formal : String?,
  product : String?,
  issue_count : Int?,
  promoted_at : Map[String, String]?,
) -> Unit raise DagError {
  match closure {
    Some(key) =>
      if not(config_has_closure(cfg, key)) {
        raise InvalidMetadata(
          "goal \{id}.closure='\{key}' is not in config.closure_tiers",
        )
      }
    None => ()
  }
  match formal {
    Some(key) =>
      if not(config_has_formal(cfg, key)) {
        raise InvalidMetadata(
          "goal \{id}.formal='\{key}' is not in config.formal_levels",
        )
      }
    None => ()
  }
  match product {
    Some(key) =>
      if not(config_has_product(cfg, key)) {
        raise InvalidMetadata(
          "goal \{id}.product='\{key}' is not in config.products",
        )
      }
    None => ()
  }
  match issue_count {
    Some(n) =>
      if n < 0 {
        raise InvalidMetadata("goal \{id}.issue_count must be >= 0")
      }
    None => ()
  }
  match promoted_at {
    Some(timeline) =>
      for key, _ in timeline {
        if not(config_has_closure(cfg, key)) {
          raise InvalidMetadata(
            "goal \{id}.promoted_at contains unknown closure '\{key}'",
          )
        }
      }
    None => ()
  }
}

///|
fn default_formal(regression_testable : Bool, formal : String) -> String {
  if formal != "" {
    formal
  } else if regression_testable {
    "checked"
  } else {
    "none"
  }
}

///|
fn default_product(cfg : VmapConfig, product : String) -> String {
  if product != "" {
    product
  } else if cfg.products.length() > 0 {
    cfg.products[0].key
  } else {
    "default"
  }
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
  closure? : String = "",
  formal? : String = "",
  product? : String = "",
  milestone? : String = "",
  owner? : String = "",
  issue_count? : Int = 0,
  focus? : Bool = false,
  archived? : Bool = false,
  promoted_at? : Map[String, String] = {},
  gh_query? : String = "",
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
  let cfg = self.effective_config()
  check_config(cfg)
  let closure_value = if closure == "" { "seed" } else { closure }
  let formal_value = default_formal(regression_testable, formal)
  let product_value = default_product(cfg, product)
  check_goal_region(
    cfg,
    id,
    Some(closure_value),
    Some(formal_value),
    Some(product_value),
    Some(issue_count),
    Some(promoted_at),
  )
  self.goals.push({
    id,
    title,
    description,
    deps,
    closure: Some(closure_value),
    formal: Some(formal_value),
    product: Some(product_value),
    milestone: non_empty_or_none(milestone),
    owner: non_empty_or_none(owner),
    issue_count: Some(issue_count),
    focus: Some(focus),
    archived: Some(archived),
    promoted_at: Some(promoted_at),
    gh_query: non_empty_or_none(gh_query),
    regression_testable,
    tests,
    docs,
  })
  self.assert_acyclic()
}

///|
pub fn Dag::set_goal_closure(
  self : Dag,
  id : String,
  closure : String,
) -> Unit raise DagError {
  let cfg = self.effective_config()
  check_config(cfg)
  if not(config_has_closure(cfg, closure)) {
    raise InvalidMetadata("closure '\{closure}' is not in config.closure_tiers")
  }
  match self.find_goal(id) {
    Some((idx, goal)) => {
      match goal.closure {
        Some(old) =>
          match (closure_index(cfg, old), closure_index(cfg, closure)) {
            (Some(old_i), Some(new_i)) =>
              if new_i < old_i {
                raise InvalidMetadata(
                  "goal \{id}.closure cannot move backward from '\{old}' to '\{closure}'",
                )
              }
            _ => ()
          }
        None => ()
      }
      self.goals[idx] = { ..goal, closure: Some(closure) }
    }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_formal(
  self : Dag,
  id : String,
  formal : String,
) -> Unit raise DagError {
  let cfg = self.effective_config()
  check_config(cfg)
  if not(config_has_formal(cfg, formal)) {
    raise InvalidMetadata("formal '\{formal}' is not in config.formal_levels")
  }
  match self.find_goal(id) {
    Some((idx, goal)) => self.goals[idx] = { ..goal, formal: Some(formal) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_product(
  self : Dag,
  id : String,
  product : String,
) -> Unit raise DagError {
  let cfg = self.effective_config()
  check_config(cfg)
  if not(config_has_product(cfg, product)) {
    raise InvalidMetadata("product '\{product}' is not in config.products")
  }
  match self.find_goal(id) {
    Some((idx, goal)) => self.goals[idx] = { ..goal, product: Some(product) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_milestone(
  self : Dag,
  id : String,
  milestone : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, goal)) =>
      self.goals[idx] = { ..goal, milestone: non_empty_or_none(milestone) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_owner(
  self : Dag,
  id : String,
  owner : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, goal)) =>
      self.goals[idx] = { ..goal, owner: non_empty_or_none(owner) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_issue_count(
  self : Dag,
  id : String,
  issue_count : Int,
) -> Unit raise DagError {
  if issue_count < 0 {
    raise InvalidMetadata("issue_count must be >= 0")
  }
  match self.find_goal(id) {
    Some((idx, goal)) =>
      self.goals[idx] = { ..goal, issue_count: Some(issue_count) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_focus(
  self : Dag,
  id : String,
  focus : Bool,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, goal)) => self.goals[idx] = { ..goal, focus: Some(focus) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_archived(
  self : Dag,
  id : String,
  archived : Bool,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, goal)) => self.goals[idx] = { ..goal, archived: Some(archived) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_promoted_at(
  self : Dag,
  id : String,
  promoted_at : Map[String, String],
) -> Unit raise DagError {
  let cfg = self.effective_config()
  check_config(cfg)
  check_goal_region(cfg, id, None, None, None, None, Some(promoted_at))
  match self.find_goal(id) {
    Some((idx, goal)) =>
      self.goals[idx] = { ..goal, promoted_at: Some(promoted_at) }
    None => raise UnknownId(id)
  }
}

///|
pub fn Dag::set_goal_gh_query(
  self : Dag,
  id : String,
  gh_query : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, goal)) =>
      self.goals[idx] = { ..goal, gh_query: non_empty_or_none(gh_query) }
    None => raise UnknownId(id)
  }
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
  let cfg = self.effective_config()
  check_config(cfg)
  for m in self.goals {
    check_goal_region(
      cfg,
      m.id,
      m.closure,
      m.formal,
      m.product,
      m.issue_count,
      m.promoted_at,
    )
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

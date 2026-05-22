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
    if !hex_color_like(tier.color) {
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
      if !config_has_closure(cfg, key) {
        raise InvalidMetadata(
          "goal \{id}.closure='\{key}' is not in config.closure_tiers",
        )
      }
    None => ()
  }
  match formal {
    Some(key) =>
      if !config_has_formal(cfg, key) {
        raise InvalidMetadata(
          "goal \{id}.formal='\{key}' is not in config.formal_levels",
        )
      }
    None => ()
  }
  match product {
    Some(key) =>
      if !config_has_product(cfg, key) {
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
        if !config_has_closure(cfg, key) {
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
  probes? : Array[String]? = None,
) -> Unit raise DagError {
  if self.has_id(id) {
    raise DuplicateId(id)
  }
  for d in deps {
    if !self.has_goal(d) {
      raise UnknownId("goal dep \{d}")
    }
  }
  let cfg = self.effective_config()
  check_config(cfg)
  let closure_value = if closure == "" { "seed" } else { closure }
  let formal_value = default_formal(regression_testable, formal)
  let product_value = default_product(cfg, product)
  self.validate_release_reference(milestone)
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
    probes,
    probe_results: None,
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
  if !config_has_closure(cfg, closure) {
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
  if !config_has_formal(cfg, formal) {
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
  if !config_has_product(cfg, product) {
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
  self.validate_release_reference(milestone)
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
  if !self.has_goal(goal) {
    raise UnknownGoal(goal)
  }
  for d in deps {
    if !self.has_task(d) {
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
/// Set probes on a goal.
pub fn Dag::set_goal_probes(
  self : Dag,
  id : String,
  probes : Array[String]?,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => self.goals[idx] = { ..m, probes, }
    None => raise UnknownId(id)
  }
}

///|
/// Set probe results on a goal.
pub fn Dag::set_goal_probe_results(
  self : Dag,
  id : String,
  probe_results : Array[ProbeResult]?,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, m)) => self.goals[idx] = { ..m, probe_results, }
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
    if !self.has_goal(i.goal) {
      raise UnknownGoal("task \{i.id} -> \{i.goal}")
    }
  }
  for m in self.goals {
    for d in m.deps {
      if !self.has_goal(d) {
        raise UnknownId("goal \{m.id} dep -> \{d}")
      }
    }
  }
  for i in self.tasks {
    for d in i.deps {
      if !self.has_task(d) {
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
  self.validate_releases()
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

///|
/// Rank a release status for monotonic transition checks.
fn release_status_rank(status : String) -> Int? {
  match status {
    "planned" => Some(0)
    "open" => Some(1)
    "closed" => Some(2)
    _ => None
  }
}

///|
/// Reject statuses outside the known set.
fn validate_release_status(status : String) -> Unit raise DagError {
  if release_status_rank(status) is None {
    raise InvalidMetadata(
      "release status '\{status}' must be one of: planned, open, closed",
    )
  }
}

///|
/// When releases are configured, goal.milestone must point at one of them.
fn Dag::validate_release_reference(
  self : Dag,
  release_key : String,
) -> Unit raise DagError {
  if release_key == "" {
    return
  }
  match self.releases {
    Some(arr) =>
      if arr.length() > 0 && !self.has_release(release_key) {
        raise UnknownRelease(release_key)
      }
    None => ()
  }
}

///|
/// Validate release lane metadata and, once releases exist, goal membership.
fn Dag::validate_releases(self : Dag) -> Unit raise DagError {
  match self.releases {
    Some(arr) => {
      let seen : Map[String, Bool] = {}
      for r in arr {
        if r.key == "" {
          raise InvalidMetadata("release key must not be empty")
        }
        if seen.contains(r.key) {
          raise DuplicateRelease(r.key)
        }
        seen[r.key] = true
        validate_release_status(r.status)
      }
      if arr.length() > 0 {
        for g in self.goals {
          match g.milestone {
            Some(m) => self.validate_release_reference(m)
            None => ()
          }
        }
      }
    }
    None => ()
  }
}

///|
/// True if any release entry exists in this DAG.
pub fn Dag::has_any_release(self : Dag) -> Bool {
  match self.releases {
    Some(arr) => arr.length() > 0
    None => false
  }
}

///|
/// Find a release by key.
pub fn Dag::find_release(self : Dag, key : String) -> (Int, ReleaseConfig)? {
  match self.releases {
    Some(arr) =>
      for idx, r in arr {
        if r.key == key {
          return Some((idx, r))
        }
      }
    None => ()
  }
  None
}

///|
/// True if `key` names a release in the DAG.
pub fn Dag::has_release(self : Dag, key : String) -> Bool {
  self.find_release(key) is Some(_)
}

///|
/// Append a new release lane. `status` defaults to "planned"; raises
/// `DuplicateRelease` if `key` already exists.
pub fn Dag::add_release(
  self : Dag,
  key~ : String,
  label_en~ : String,
  label_zh~ : String,
  target? : String = "",
  status? : String = "planned",
  notes? : String = "",
) -> Unit raise DagError {
  if key == "" {
    raise InvalidMetadata("release key must not be empty")
  }
  validate_release_status(status)
  if self.has_release(key) {
    raise DuplicateRelease(key)
  }
  let new_release : ReleaseConfig = {
    key,
    label: { en: label_en, zh: label_zh },
    target: non_empty_or_none(target),
    status,
    notes: non_empty_or_none(notes),
    closed_at: None,
  }
  match self.releases {
    Some(arr) => arr.push(new_release)
    None => self.releases = Some([new_release])
  }
}

///|
/// Modify an existing release lane in place. Each argument is treated as
/// "unset" when it equals its sentinel (empty string for strings); pass only
/// the fields you want to change. Status transitions cannot move backward
/// (planned → open → closed only).
pub fn Dag::update_release(
  self : Dag,
  key : String,
  label_en? : String = "",
  label_zh? : String = "",
  target? : String = "",
  status? : String = "",
  notes? : String = "",
  clear_target? : Bool = false,
  clear_notes? : Bool = false,
) -> Unit raise DagError {
  match self.releases {
    Some(arr) =>
      match self.find_release(key) {
        Some((idx, old)) => {
          let mut new_status = old.status
          let new_closed_at = old.closed_at
          if status != "" {
            validate_release_status(status)
            match
              (release_status_rank(old.status), release_status_rank(status)) {
              (Some(old_rank), Some(new_rank)) =>
                if new_rank < old_rank {
                  raise ReleaseStatusRegression(key, old.status, status)
                }
              _ => ()
            }
            new_status = status
            // Closing or unclosing leaves closed_at to the close op; we only
            // clear closed_at if a release is moved back from closed (which
            // is currently forbidden anyway).
          }
          let new_label_en = if label_en != "" {
            label_en
          } else {
            old.label.en
          }
          let new_label_zh = if label_zh != "" {
            label_zh
          } else {
            old.label.zh
          }
          let new_target = if clear_target {
            None
          } else if target != "" {
            Some(target)
          } else {
            old.target
          }
          let new_notes = if clear_notes {
            None
          } else if notes != "" {
            Some(notes)
          } else {
            old.notes
          }
          arr[idx] = {
            ..old,
            label: { en: new_label_en, zh: new_label_zh },
            target: new_target,
            status: new_status,
            notes: new_notes,
            closed_at: new_closed_at,
          }
        }
        None => raise UnknownRelease(key)
      }
    None => raise UnknownRelease(key)
  }
}

///|
/// Set `closed_at` on a release (used by `release close`). Caller is
/// responsible for transitioning status separately.
pub fn Dag::set_release_closed_at(
  self : Dag,
  key : String,
  closed_at : String,
) -> Unit raise DagError {
  match self.releases {
    Some(arr) =>
      match self.find_release(key) {
        Some((idx, old)) =>
          arr[idx] = { ..old, closed_at: non_empty_or_none(closed_at) }
        None => raise UnknownRelease(key)
      }
    None => raise UnknownRelease(key)
  }
}

///|
/// Remove a release. By default refuses if any goal still points at it;
/// `force=true` clears the milestone on each member first.
pub fn Dag::remove_release(
  self : Dag,
  key : String,
  force? : Bool = false,
) -> Unit raise DagError {
  match self.releases {
    Some(arr) =>
      match self.find_release(key) {
        Some(_) => {
          let members = self.release_member_ids(key)
          if members.length() > 0 && !force {
            raise ReleaseHasMembers(key, members)
          }
          if force {
            for idx, g in self.goals {
              match g.milestone {
                Some(m) =>
                  if m == key {
                    self.goals[idx] = { ..g, milestone: None }
                  }
                None => ()
              }
            }
          }
          arr.retain(r => r.key != key)
        }
        None => raise UnknownRelease(key)
      }
    None => raise UnknownRelease(key)
  }
}

///|
/// Set `goal.milestone` to `release_key`, validating against the release
/// list. Raises `UnknownGoal` if the goal does not exist or
/// `UnknownRelease` if the release is not registered.
pub fn Dag::assign_release(
  self : Dag,
  goal_id : String,
  release_key : String,
) -> Unit raise DagError {
  if !self.has_release(release_key) {
    raise UnknownRelease(release_key)
  }
  match self.find_goal(goal_id) {
    Some((idx, g)) => self.goals[idx] = { ..g, milestone: Some(release_key) }
    None => raise UnknownGoal(goal_id)
  }
}

///|
/// Goal ids currently pointing at this release via their `milestone` field.
pub fn Dag::release_member_ids(self : Dag, key : String) -> Array[String] {
  let out = []
  for g in self.goals {
    match g.milestone {
      Some(m) => if m == key { out.push(g.id) }
      None => ()
    }
  }
  out
}

///|
/// Goals currently pointing at this release.
pub fn Dag::release_members(self : Dag, key : String) -> Array[Goal] {
  let out = []
  for g in self.goals {
    match g.milestone {
      Some(m) => if m == key { out.push(g) }
      None => ()
    }
  }
  out
}

///|
/// Derived snapshot of a release: tally goals by closure stage, list any
/// goals whose closure is still below `public` (the ship gate), and surface
/// `ready_to_close` when no blockers remain.
pub(all) struct ReleaseProgress {
  release : ReleaseConfig
  total_goals : Int
  by_closure : Map[String, Int]
  blocked : Array[String]
  ready_to_close : Bool
} derive(Debug, ToJson)

///|
pub impl Show for ReleaseProgress with output(self, logger) {
  logger.write_string(@debug.to_repr(self).to_string())
}

///|
/// Compute the snapshot. Raises `UnknownRelease` if the key is not registered.
pub fn Dag::release_progress(
  self : Dag,
  key : String,
) -> ReleaseProgress raise DagError {
  let release = match self.find_release(key) {
    Some((_, r)) => r
    None => raise UnknownRelease(key)
  }
  let cfg = self.effective_config()
  let public_idx = match closure_index(cfg, "public") {
    Some(i) => i
    None => raise InvalidMetadata("config.closure_tiers must contain 'public'")
  }
  let members = self.release_members(key)
  let by_closure : Map[String, Int] = {}
  let blocked = []
  for g in members {
    let c = match g.closure {
      Some(x) => x
      None => "seed"
    }
    let prev = match by_closure.get(c) {
      Some(n) => n
      None => 0
    }
    by_closure[c] = prev + 1
    let goal_idx = match closure_index(cfg, c) {
      Some(i) => i
      None => -1
    }
    if goal_idx < public_idx {
      blocked.push(g.id)
    }
  }
  {
    release,
    total_goals: members.length(),
    by_closure,
    blocked,
    ready_to_close: blocked.length() == 0,
  }
}

///|
fn array_has(arr : Array[String], needle : String) -> Bool {
  for s in arr {
    if s == needle {
      return true
    }
  }
  false
}

///|
/// `"goal"` if `id` names a goal, `"task"` if a task, `None` otherwise.
pub fn Dag::kind_of(self : Dag, id : String) -> String? {
  if self.has_goal(id) {
    return Some("goal")
  }
  if self.has_task(id) {
    return Some("task")
  }
  None
}

///|
/// Replace `deps` on a goal or task. Validates each dep id exists at the
/// correct layer (goal→goal, task→task), refuses self-deps, and re-runs
/// the cycle check.
pub fn Dag::set_deps(
  self : Dag,
  id : String,
  deps : Array[String],
) -> Unit raise DagError {
  for d in deps {
    if d == id {
      raise InvalidMetadata("\{id} cannot depend on itself")
    }
  }
  match self.find_goal(id) {
    Some((idx, g)) => {
      for d in deps {
        if !self.has_goal(d) {
          raise UnknownId("goal dep \{d}")
        }
      }
      self.goals[idx] = { ..g, deps, }
      self.assert_acyclic()
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      for d in deps {
        if !self.has_task(d) {
          raise UnknownId("task dep \{d}")
        }
      }
      self.tasks[idx] = { ..t, deps, }
      self.assert_acyclic()
    }
    None => raise UnknownId(id)
  }
}

///|
/// Add a single dep. No-op if already present. Validates layer and cycles.
pub fn Dag::add_dep(
  self : Dag,
  id : String,
  dep : String,
) -> Unit raise DagError {
  if dep == id {
    raise InvalidMetadata("\{id} cannot depend on itself")
  }
  match self.find_goal(id) {
    Some((idx, g)) => {
      if !self.has_goal(dep) {
        raise UnknownId("goal dep \{dep}")
      }
      if array_has(g.deps, dep) {
        return
      }
      let next = g.deps.copy()
      next.push(dep)
      self.goals[idx] = { ..g, deps: next }
      self.assert_acyclic()
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      if !self.has_task(dep) {
        raise UnknownId("task dep \{dep}")
      }
      if array_has(t.deps, dep) {
        return
      }
      let next = t.deps.copy()
      next.push(dep)
      self.tasks[idx] = { ..t, deps: next }
      self.assert_acyclic()
    }
    None => raise UnknownId(id)
  }
}

///|
/// Remove a single dep. No-op if not present.
pub fn Dag::remove_dep(
  self : Dag,
  id : String,
  dep : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => {
      let next = g.deps.copy()
      next.retain(d => d != dep)
      self.goals[idx] = { ..g, deps: next }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      let next = t.deps.copy()
      next.retain(d => d != dep)
      self.tasks[idx] = { ..t, deps: next }
    }
    None => raise UnknownId(id)
  }
}

///|
/// Move a task under a different goal. Validates the destination goal
/// exists. Task→task deps are unaffected.
pub fn Dag::set_task_goal(
  self : Dag,
  task_id : String,
  new_goal : String,
) -> Unit raise DagError {
  if !self.has_goal(new_goal) {
    raise UnknownGoal(new_goal)
  }
  match self.find_task(task_id) {
    Some((idx, t)) => self.tasks[idx] = { ..t, goal: new_goal }
    None => raise UnknownId("task \{task_id}")
  }
}

///|
/// Replace a task's free-form `notes`. Goals don't have `notes` — use
/// `set_description` for goals.
pub fn Dag::set_task_notes(
  self : Dag,
  id : String,
  notes : String,
) -> Unit raise DagError {
  match self.find_task(id) {
    Some((idx, t)) => self.tasks[idx] = { ..t, notes, }
    None => raise UnknownId("task \{id}")
  }
}

///|
/// Replace a goal's `description`. Tasks don't have `description` — use
/// `set_task_notes` for tasks.
pub fn Dag::set_description(
  self : Dag,
  id : String,
  description : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => self.goals[idx] = { ..g, description, }
    None => raise UnknownId("goal \{id}")
  }
}

///|
/// Add a single test path to a goal or task. No-op if already present.
pub fn Dag::add_test(
  self : Dag,
  id : String,
  path : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => {
      if array_has(g.tests, path) {
        return
      }
      let next = g.tests.copy()
      next.push(path)
      self.goals[idx] = { ..g, tests: next }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      if array_has(t.tests, path) {
        return
      }
      let next = t.tests.copy()
      next.push(path)
      self.tasks[idx] = { ..t, tests: next }
    }
    None => raise UnknownId(id)
  }
}

///|
/// Remove a single test path. No-op if not present.
pub fn Dag::remove_test(
  self : Dag,
  id : String,
  path : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => {
      let next = g.tests.copy()
      next.retain(p => p != path)
      self.goals[idx] = { ..g, tests: next }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      let next = t.tests.copy()
      next.retain(p => p != path)
      self.tasks[idx] = { ..t, tests: next }
    }
    None => raise UnknownId(id)
  }
}

///|
/// Add a single doc path. No-op if already present.
pub fn Dag::add_doc(
  self : Dag,
  id : String,
  path : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => {
      if array_has(g.docs, path) {
        return
      }
      let next = g.docs.copy()
      next.push(path)
      self.goals[idx] = { ..g, docs: next }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      if array_has(t.docs, path) {
        return
      }
      let next = t.docs.copy()
      next.push(path)
      self.tasks[idx] = { ..t, docs: next }
    }
    None => raise UnknownId(id)
  }
}

///|
/// Remove a single doc path. No-op if not present.
pub fn Dag::remove_doc(
  self : Dag,
  id : String,
  path : String,
) -> Unit raise DagError {
  match self.find_goal(id) {
    Some((idx, g)) => {
      let next = g.docs.copy()
      next.retain(p => p != path)
      self.goals[idx] = { ..g, docs: next }
      return
    }
    None => ()
  }
  match self.find_task(id) {
    Some((idx, t)) => {
      let next = t.docs.copy()
      next.retain(p => p != path)
      self.tasks[idx] = { ..t, docs: next }
    }
    None => raise UnknownId(id)
  }
}

///|
/// Rename a goal or task id and rewrite every reference: cross-goal deps,
/// task→goal pointer, task→task deps. `release.milestone` references the
/// release key, not a goal id, so it's untouched here.
pub fn Dag::rename(
  self : Dag,
  old_id : String,
  new_id : String,
) -> Unit raise DagError {
  if old_id == new_id {
    return
  }
  if new_id == "" {
    raise InvalidMetadata("new id must not be empty")
  }
  if self.has_id(new_id) {
    raise DuplicateId(new_id)
  }
  if self.has_goal(old_id) {
    match self.find_goal(old_id) {
      Some((idx, g)) => self.goals[idx] = { ..g, id: new_id }
      None => raise UnknownId(old_id)
    }
    for idx, g in self.goals {
      if array_has(g.deps, old_id) {
        let next = g.deps.copy()
        for i, d in next {
          if d == old_id {
            next[i] = new_id
          }
        }
        self.goals[idx] = { ..g, deps: next }
      }
    }
    for idx, t in self.tasks {
      if t.goal == old_id {
        self.tasks[idx] = { ..t, goal: new_id }
      }
    }
  } else if self.has_task(old_id) {
    match self.find_task(old_id) {
      Some((idx, t)) => self.tasks[idx] = { ..t, id: new_id }
      None => raise UnknownId(old_id)
    }
    for idx, t in self.tasks {
      if array_has(t.deps, old_id) {
        let next = t.deps.copy()
        for i, d in next {
          if d == old_id {
            next[i] = new_id
          }
        }
        self.tasks[idx] = { ..t, deps: next }
      }
    }
  } else {
    raise UnknownId(old_id)
  }
}

///|
/// Clear `milestone` on goals pointing at `release_key`. When `only` is
/// non-empty, restrict to just those goal ids. Raises if the release
/// itself is not registered.
pub fn Dag::unassign_release(
  self : Dag,
  release_key : String,
  only : Array[String],
) -> Unit raise DagError {
  if !self.has_release(release_key) {
    raise UnknownRelease(release_key)
  }
  let only_set : Map[String, Bool] = {}
  for g in only {
    only_set[g] = true
  }
  let limit_to_subset = only.length() > 0
  for idx, g in self.goals {
    match g.milestone {
      Some(m) =>
        if m == release_key && (!limit_to_subset || only_set.contains(g.id)) {
          self.goals[idx] = { ..g, milestone: None }
        }
      None => ()
    }
  }
}

///|
/// Transitive upstream — all ids that `id` depends on (directly or
/// indirectly), in pre-order discovery order. Crosses layer: starting from a
/// goal walks goal→goal edges; starting from a task walks task→task edges.
pub fn Dag::upstream(self : Dag, id : String) -> Array[String] {
  let visited : Map[String, Bool] = {}
  let order : Array[String] = []
  fn deps_of(node : String) -> Array[String] {
    match self.find_goal(node) {
      Some((_, g)) => return g.deps
      None => ()
    }
    match self.find_task(node) {
      Some((_, t)) => t.deps
      None => []
    }
  }

  fn visit(node : String) -> Unit {
    for d in deps_of(node) {
      if !visited.contains(d) {
        visited[d] = true
        order.push(d)
        visit(d)
      }
    }
  }

  visit(id)
  order
}

///|
/// Transitive downstream — all ids that depend on `id` (directly or
/// indirectly). Uses a reverse-edge index built once per call.
pub fn Dag::downstream(self : Dag, id : String) -> Array[String] {
  let reverse : Map[String, Array[String]] = {}
  for g in self.goals {
    for d in g.deps {
      let arr = match reverse.get(d) {
        Some(a) => a
        None => []
      }
      arr.push(g.id)
      reverse[d] = arr
    }
  }
  for t in self.tasks {
    for d in t.deps {
      let arr = match reverse.get(d) {
        Some(a) => a
        None => []
      }
      arr.push(t.id)
      reverse[d] = arr
    }
  }
  let visited : Map[String, Bool] = {}
  let order : Array[String] = []
  fn visit(node : String) -> Unit {
    match reverse.get(node) {
      Some(arr) =>
        for x in arr {
          if !visited.contains(x) {
            visited[x] = true
            order.push(x)
            visit(x)
          }
        }
      None => ()
    }
  }

  visit(id)
  order
}

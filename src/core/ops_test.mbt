///|
test "add goal and task, progress tracks done count" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="用户能登录")
  dag.add_task(id="i1", goal="m1", title="写 auth middleware")
  dag.add_task(id="i2", goal="m1", title="加 session cookie")
  assert_eq(dag.progress("m1"), (0, 2))
  dag.update_status("i1", @core.Done)
  assert_eq(dag.progress("m1"), (1, 2))
}

///|
test "duplicate id is rejected" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  let err : Result[Unit, @core.DagError] = try? dag.add_goal(id="m1", title="B")
  guard err is Err(DuplicateId("m1")) else {
    fail("expected DuplicateId, got: \{err}")
  }
}

///|
test "task under unknown goal is rejected" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_task(
    id="i1",
    goal="nope",
    title="x",
  )
  guard err is Err(UnknownGoal("nope")) else {
    fail("expected UnknownGoal, got: \{err}")
  }
}

///|
test "cycle in task deps is detected" {
  // Build a valid graph first, then mutate deps to create a cycle and re-check.
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  dag.add_task(id="i1", goal="m1", title="one")
  dag.add_task(id="i2", goal="m1", title="two", deps=["i1"])
  // Sneak a back-edge in: i1 now depends on i2.
  let (idx, i1) = dag.find_task("i1").unwrap()
  dag.tasks[idx] = { ..i1, deps: ["i2"] }
  let err : Result[Unit, @core.DagError] = try? dag.assert_acyclic()
  guard err is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{err}")
  }
}

///|
test "remove goal drops its tasks and scrubs deps" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  dag.add_goal(id="m2", title="B", deps=["m1"])
  dag.add_task(id="i1", goal="m1", title="x")
  dag.add_task(id="i2", goal="m2", title="y")
  dag.remove("m1")
  assert_eq(dag.goals.length(), 1)
  assert_eq(dag.tasks.length(), 1)
  // m2's deps no longer reference the removed goal.
  let (_, m2) = dag.find_goal("m2").unwrap()
  assert_eq(m2.deps.length(), 0)
}

///|
test "goal closure can only move forward" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A", closure="obligation")
  dag.set_goal_closure("m1", "scoped")
  let err : Result[Unit, @core.DagError] = try? dag.set_goal_closure(
    "m1", "seed",
  )
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

///|
test "goal metadata validates against config enums" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_goal(
    id="m1",
    title="A",
    closure="ghost",
  )
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

///|
test "config metadata is validated" {
  let dag = @core.Dag::empty("demo")
  let cfg = dag.effective_config()
  let bad : @core.Dag = { ..dag, config: Some({ ..cfg, products: [] }) }
  let err : Result[Unit, @core.DagError] = try? bad.validate()
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

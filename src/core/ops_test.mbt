///|
test "add milestone and issue, progress tracks done count" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="用户能登录")
  dag.add_issue(id="i1", milestone="m1", title="写 auth middleware")
  dag.add_issue(id="i2", milestone="m1", title="加 session cookie")
  assert_eq(dag.progress("m1"), (0, 2))
  dag.update_status("i1", @core.Done)
  assert_eq(dag.progress("m1"), (1, 2))
}

///|
test "duplicate id is rejected" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A")
  let err : Result[Unit, @core.DagError] = try? dag.add_milestone(
    id="m1",
    title="B",
  )
  guard err is Err(DuplicateId("m1")) else {
    fail("expected DuplicateId, got: \{err}")
  }
}

///|
test "issue under unknown milestone is rejected" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_issue(
    id="i1",
    milestone="nope",
    title="x",
  )
  guard err is Err(UnknownMilestone("nope")) else {
    fail("expected UnknownMilestone, got: \{err}")
  }
}

///|
test "cycle in issue deps is detected" {
  // Build a valid graph first, then mutate deps to create a cycle and re-check.
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A")
  dag.add_issue(id="i1", milestone="m1", title="one")
  dag.add_issue(id="i2", milestone="m1", title="two", deps=["i1"])
  // Sneak a back-edge in: i1 now depends on i2.
  let (idx, i1) = dag.find_issue("i1").unwrap()
  dag.issues[idx] = { ..i1, deps: ["i2"] }
  let err : Result[Unit, @core.DagError] = try? dag.assert_acyclic()
  guard err is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{err}")
  }
}

///|
test "remove milestone drops its issues and scrubs deps" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A")
  dag.add_milestone(id="m2", title="B", deps=["m1"])
  dag.add_issue(id="i1", milestone="m1", title="x")
  dag.add_issue(id="i2", milestone="m2", title="y")
  dag.remove("m1")
  assert_eq(dag.milestones.length(), 1)
  assert_eq(dag.issues.length(), 1)
  // m2's deps no longer reference the removed milestone.
  let (_, m2) = dag.find_milestone("m2").unwrap()
  assert_eq(m2.deps.length(), 0)
}

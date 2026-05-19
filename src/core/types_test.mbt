///|
test "Status round-trip via JSON" {
  for s in [@core.Todo, @core.InProgress, @core.Blocked, @core.Done] {
    let j = s.to_json()
    let back : @core.Status = @json.from_json(j)
    assert_eq(s, back)
  }
}

///|
test "Dag::empty serializes to a stable shape" {
  let dag = @core.Dag::empty("demo")
  assert_true(dag.config is Some(_))
  assert_eq(dag.project.name, "demo")
  assert_eq(dag.goals.length(), 0)
  assert_eq(dag.tasks.length(), 0)
  assert_true(dag.to_json().stringify().contains("\"closure_tiers\""))
}

///|
test "Dag round-trip with one goal and one task" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(
    id="m1",
    title="用户能登录",
    owner="eanzhao",
    gh_query="repo:x/y auth",
  )
  dag.add_task(
    id="i1",
    goal="m1",
    title="写 auth middleware",
    regression_testable=true,
    tests=["src/auth/middleware_test.mbt"],
    docs=["docs/auth.md"],
  )
  dag.update_status("i1", @core.Done)
  let encoded = dag.to_json()
  let decoded : @core.Dag = @json.from_json(encoded)
  assert_eq(dag, decoded)
}

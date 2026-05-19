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
  json_inspect(dag, content={
    "project": { "name": "demo", "description": "" },
    "goals": [],
    "tasks": [],
  })
}

///|
test "Dag round-trip with one goal and one task" {
  let dag : @core.Dag = {
    project: { name: "demo", description: "vibe coding DAG" },
    goals: [
      {
        id: "m1",
        title: "用户能登录",
        description: "",
        deps: [],
        regression_testable: false,
        tests: [],
        docs: [],
      },
    ],
    tasks: [
      {
        id: "i1",
        goal: "m1",
        title: "写 auth middleware",
        status: @core.Done,
        deps: [],
        notes: "",
        regression_testable: true,
        tests: ["src/auth/middleware_test.mbt"],
        docs: ["docs/auth.md"],
      },
    ],
  }
  let encoded = dag.to_json()
  let decoded : @core.Dag = @json.from_json(encoded)
  assert_eq(dag, decoded)
}

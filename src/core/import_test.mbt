///|
test "import: valid DAG round-trips" {
  let src = "/tmp/vmap-import-valid.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "goals": [
    #|    { "id": "m1", "title": "A", "description": "", "deps": [],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "tasks": [
    #|    { "id": "i1", "goal": "m1", "title": "x", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let dag = @core.import_dag(src)
  assert_eq(dag.goals.length(), 1)
  assert_eq(dag.tasks.length(), 1)
  assert_eq(dag.goals[0].id, "m1")
}

///|
test "import: duplicate id is rejected" {
  let src = "/tmp/vmap-import-dup.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "goals": [
    #|    { "id": "x", "title": "A", "description": "", "deps": [],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "tasks": [
    #|    { "id": "x", "goal": "x", "title": "y", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(DuplicateId("x")) else {
    fail("expected DuplicateId, got: \{@debug.to_repr(r)}")
  }
}

///|
test "import: unknown goal on task is rejected" {
  let src = "/tmp/vmap-import-orphan.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "goals": [],
    #|  "tasks": [
    #|    { "id": "i1", "goal": "nope", "title": "x", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(UnknownGoal(_)) else {
    fail("expected UnknownGoal, got: \{@debug.to_repr(r)}")
  }
}

///|
test "import: cycle in deps is rejected" {
  let src = "/tmp/vmap-import-cycle.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "goals": [
    #|    { "id": "a", "title": "A", "description": "", "deps": ["b"],
    #|      "regression_testable": false, "tests": [], "docs": [] },
    #|    { "id": "b", "title": "B", "description": "", "deps": ["a"],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "tasks": []
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{@debug.to_repr(r)}")
  }
}

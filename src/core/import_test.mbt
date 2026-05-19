///|
test "import: valid DAG round-trips" {
  let src = "/tmp/vmap-import-valid.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "milestones": [
    #|    { "id": "m1", "title": "A", "description": "", "deps": [],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "issues": [
    #|    { "id": "i1", "milestone": "m1", "title": "x", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let dag = @core.import_dag(src)
  assert_eq(dag.milestones.length(), 1)
  assert_eq(dag.issues.length(), 1)
  assert_eq(dag.milestones[0].id, "m1")
}

///|
test "import: duplicate id is rejected" {
  let src = "/tmp/vmap-import-dup.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "milestones": [
    #|    { "id": "x", "title": "A", "description": "", "deps": [],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "issues": [
    #|    { "id": "x", "milestone": "x", "title": "y", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(DuplicateId("x")) else {
    fail("expected DuplicateId, got: \{r}")
  }
}

///|
test "import: unknown milestone on issue is rejected" {
  let src = "/tmp/vmap-import-orphan.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "milestones": [],
    #|  "issues": [
    #|    { "id": "i1", "milestone": "nope", "title": "x", "status": "todo",
    #|      "deps": [], "notes": "", "regression_testable": false,
    #|      "tests": [], "docs": [] }
    #|  ]
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(UnknownMilestone(_)) else {
    fail("expected UnknownMilestone, got: \{r}")
  }
}

///|
test "import: cycle in deps is rejected" {
  let src = "/tmp/vmap-import-cycle.json"
  let body =
    #|{
    #|  "project": { "name": "demo", "description": "" },
    #|  "milestones": [
    #|    { "id": "a", "title": "A", "description": "", "deps": ["b"],
    #|      "regression_testable": false, "tests": [], "docs": [] },
    #|    { "id": "b", "title": "B", "description": "", "deps": ["a"],
    #|      "regression_testable": false, "tests": [], "docs": [] }
    #|  ],
    #|  "issues": []
    #|}
  @fs.write_string_to_file(src, body)
  let r : Result[@core.Dag, @core.DagError] = try? @core.import_dag(src)
  guard r is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{r}")
  }
}

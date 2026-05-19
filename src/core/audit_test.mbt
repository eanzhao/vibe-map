///|
fn add_audited_goal(
  dag : @core.Dag,
  id : String,
  docs? : Array[String] = ["m1.md"],
) -> Unit raise {
  dag.add_goal(
    id~,
    title="A",
    docs~,
    owner="eanzhao",
    gh_query="is:issue is:open repo:owner/repo",
  )
}

///|
test "audit: clean DAG produces no violations" {
  let dag = @core.Dag::empty("demo")
  add_audited_goal(dag, "m1", docs=["docs/m1.md"])
  let report = dag.audit()
  assert_eq(report.ok, true)
  assert_eq(report.violations.length(), 0)
}

///|
test "audit: regression_testable without tests is flagged" {
  let dag = @core.Dag::empty("demo")
  add_audited_goal(dag, "m1")
  dag.add_task(id="i1", goal="m1", title="x", regression_testable=true, docs=[
    "x.mbt",
  ])
  dag.update_status("i1", @core.Done)
  let report = dag.audit()
  assert_eq(report.ok, false)
  assert_eq(report.violations.length(), 1)
  assert_eq(report.violations[0].kind, "missing_tests")
  assert_eq(report.violations[0].node_id, "i1")
}

///|
test "audit: non-todo task without docs is flagged" {
  let dag = @core.Dag::empty("demo")
  add_audited_goal(dag, "m1")
  dag.add_task(id="i1", goal="m1", title="x")
  dag.update_status("i1", @core.InProgress)
  let report = dag.audit()
  assert_eq(report.ok, false)
  // Only docs flag — task isn't regression_testable so no tests flag.
  assert_eq(report.violations.length(), 1)
  assert_eq(report.violations[0].kind, "missing_docs")
}

///|
test "audit: pure todo node without docs is NOT flagged" {
  let dag = @core.Dag::empty("demo")
  add_audited_goal(dag, "m1")
  dag.add_task(id="i1", goal="m1", title="future work")
  // i1 stays at status=todo
  let report = dag.audit()
  assert_eq(report.ok, true)
}

///|
test "audit: goal without GitHub query is flagged as missing region metadata" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A", docs=["m1.md"], owner="eanzhao")
  let report = dag.audit()
  assert_eq(report.ok, false)
  assert_true(report.violations.any(v => v.kind == "missing_region_metadata"))
}

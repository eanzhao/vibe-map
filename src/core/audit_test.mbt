///|
test "audit: clean DAG produces no violations" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(
    id="m1",
    title="A",
    docs=["docs/m1.md"],
    regression_testable=false,
  )
  let report = dag.audit()
  assert_eq(report.ok, true)
  assert_eq(report.violations.length(), 0)
}

///|
test "audit: regression_testable without tests is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A", docs=["m1.md"])
  dag.add_issue(id="i1", milestone="m1", title="x", regression_testable=true, docs=[
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
test "audit: non-todo issue without docs is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A", docs=["m1.md"])
  dag.add_issue(id="i1", milestone="m1", title="x")
  dag.update_status("i1", @core.InProgress)
  let report = dag.audit()
  assert_eq(report.ok, false)
  // Only docs flag — issue isn't regression_testable so no tests flag.
  assert_eq(report.violations.length(), 1)
  assert_eq(report.violations[0].kind, "missing_docs")
}

///|
test "audit: pure todo node without docs is NOT flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_milestone(id="m1", title="A", docs=["m1.md"])
  dag.add_issue(id="i1", milestone="m1", title="future work")
  // i1 stays at status=todo
  let report = dag.audit()
  assert_eq(report.ok, true)
}

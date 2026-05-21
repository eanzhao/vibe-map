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

///|
test "audit: goal referencing unknown release is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(
    id="m1",
    title="A",
    docs=["m1.md"],
    owner="eanzhao",
    gh_query="q",
    milestone="0.2.0",
  )
  dag.add_release(key="0.1.0", label_en="r1", label_zh="r1")
  let report = dag.audit()
  assert_eq(report.ok, false)
  assert_true(
    report.violations.any(v => v.kind == "release_unknown" && v.node_id == "m1"),
  )
}

///|
test "audit: goal chronology dependency violation is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.1.0", label_en="r1", label_zh="r1")
  dag.add_release(key="0.2.0", label_en="r2", label_zh="r2")
  dag.add_goal(
    id="m2",
    title="B",
    docs=["m2.md"],
    owner="eanzhao",
    gh_query="q",
  )
  dag.add_goal(
    id="m3",
    title="C",
    docs=["m3.md"],
    owner="eanzhao",
    gh_query="q",
    milestone="0.2.0",
  )
  dag.add_goal(
    id="m1",
    title="A",
    docs=["m1.md"],
    owner="eanzhao",
    gh_query="q",
    milestone="0.1.0",
    deps=["m2", "m3"],
  )
  let report = dag.audit()
  assert_eq(report.ok, false)
  let blocked_v = report.violations.filter(v => {
    v.kind == "release_blocked" && v.node_id == "m1"
  })
  assert_eq(blocked_v.length(), 2)
}

///|
test "audit: closed release with goals below public is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.1.0", label_en="r1", label_zh="r1", status="closed")
  dag.add_goal(
    id="m1",
    title="A",
    docs=["m1.md"],
    owner="eanzhao",
    gh_query="q",
    milestone="0.1.0",
    closure="seed",
  )
  let report = dag.audit()
  assert_eq(report.ok, false)
  assert_true(
    report.violations.any(v => {
      v.kind == "release_blocked" &&
      v.node_id == "m1" &&
      v.message.contains("below 'public'")
    }),
  )
}

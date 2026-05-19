///|
test "backfill against the vibe-map project's own src/ produces expected packages" {
  // Dogfood: run backfill against this very repo. Stable because the package
  // layout is committed.
  let dag = @core.Dag::empty("self-host")
  let report = dag.backfill_moonbit("src")
  // backfill sorts packages by lexical_compare so the ids come out
  // in stable, human-expected order.
  json_inspect(report.added_goals, content=[
    "pkg-cmd-vmap", "pkg-core", "pkg-render",
  ])
  // Tasks should at least include known source files.
  assert_true(report.added_tasks.length() >= 5)
  // Re-running backfill on the same DAG should add nothing new.
  let report2 = dag.backfill_moonbit("src")
  assert_eq(report2.added_goals.length(), 0)
  assert_eq(report2.added_tasks.length(), 0)
  assert_eq(report2.skipped_goals.length(), 3)
}

///|
test "backfill binds tests and docs by filename convention" {
  let dag = @core.Dag::empty("self-host")
  let _ = dag.backfill_moonbit("src")
  // core/types.mbt has a sibling types_test.mbt, so the task should have it
  // bound.
  let task = dag.find_task("core-types").unwrap().1
  assert_true(task.tests.length() >= 1)
  assert_eq(task.tests[0], "types_test.mbt")
  assert_eq(task.status, @core.Done)
  assert_eq(task.regression_testable, true)
}

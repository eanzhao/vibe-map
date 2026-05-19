///|
test "plan: synthesizes milestone + todo issues from a markdown file" {
  // Lay down a fixture in /tmp so we don't depend on this repo's own docs.
  let dir = "/tmp/vmap-plan-test"
  let _ = try? @fs.remove_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file(
    "\{dir}/auth.md",
    "# Auth\n\n- [ ] write middleware\n- [ ] add session cookie\n- [x] already done\n",
  )
  let dag = @core.Dag::empty("demo")
  let report = dag.plan_from_docs([dir])
  assert_eq(report.added_milestones.length(), 1)
  assert_eq(report.added_milestones[0], "plan-auth")
  assert_eq(report.added_issues.length(), 2)
  let issue = dag.find_issue(report.added_issues[0]).unwrap().1
  assert_eq(issue.status, @core.Todo)
  assert_eq(issue.docs[0], "\{dir}/auth.md")
}

///|
test "plan: skips checklist items inside fenced code blocks" {
  let dir = "/tmp/vmap-plan-fence-test"
  let _ = try? @fs.remove_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file(
    "\{dir}/spec.md",
    "# Spec\n\n```\n- [ ] should be skipped (inside code)\n```\n\n- [ ] real item\n",
  )
  let dag = @core.Dag::empty("demo")
  let report = dag.plan_from_docs([dir])
  assert_eq(report.added_issues.length(), 1)
}

///|
test "plan: re-running on the same DAG is idempotent" {
  let dir = "/tmp/vmap-plan-idem"
  let _ = try? @fs.remove_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file("\{dir}/x.md", "- [ ] alpha\n- [ ] beta\n")
  let dag = @core.Dag::empty("demo")
  let _ = dag.plan_from_docs([dir])
  let report2 = dag.plan_from_docs([dir])
  assert_eq(report2.added_milestones.length(), 0)
  assert_eq(report2.added_issues.length(), 0)
  assert_eq(report2.skipped_issues.length(), 2)
}

///|
test "plan tlist: parses chengsheng-style T-headers and Status lines" {
  let dir = "/tmp/vmap-plan-tlist"
  let _ = try? @fs.remove_dir(dir)
  @fs.create_dir(dir)
  let body =
    #|# Plan
    #|
    #|## T1 — Spike: pick a library
    #|
    #|**What:** investigate
    #|
    #|**Status:** ✅ resolved 2026-05-13 → went with foo
    #|
    #|## T2 — ~~Abandoned idea~~
    #|
    #|**Status:** open
    #|
    #|## T3 — Cross-tz handling
    #|
    #|**Status:** partially resolved
    #|
    #|## T4 — Compliance baseline
    #|
    #|**Status:** open
  @fs.write_string_to_file("\{dir}/todos.md", body)
  let dag = @core.Dag::empty("demo")
  let report = dag.plan_from_docs([dir], format="tlist")
  // T2 is struck through and skipped.
  assert_eq(report.added_milestones.length(), 1)
  assert_eq(report.added_issues.length(), 3)
  let t1 = dag.find_issue("plan-todos-t1").unwrap().1
  assert_eq(t1.status, @core.Done)
  let t3 = dag.find_issue("plan-todos-t3").unwrap().1
  assert_eq(t3.status, @core.InProgress)
  let t4 = dag.find_issue("plan-todos-t4").unwrap().1
  assert_eq(t4.status, @core.Todo)
  // T2 must not have been emitted.
  assert_true(dag.find_issue("plan-todos-t2") is None)
}

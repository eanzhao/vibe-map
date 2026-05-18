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

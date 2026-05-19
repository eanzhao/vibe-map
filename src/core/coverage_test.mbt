///|
/// Synthetic fixture: a small dir tree with markdown + source subdirs that
/// the coverage tests share. Lives under /tmp so we don't pollute the repo.
fn build_fixture(root : String) -> Unit raise {
  @core.ensure_dir(root)
  @core.ensure_dir("\{root}/docs")
  @core.ensure_dir("\{root}/docs/setting")
  @core.ensure_dir("\{root}/src/lib/mastery")
  @core.ensure_dir("\{root}/src/lib/factions")
  @core.ensure_dir("\{root}/src/lib/quests")
  @fs.write_string_to_file("\{root}/README.md", "# demo\n")
  @fs.write_string_to_file("\{root}/docs/setting/mastery.md", "# mastery\n")
  @fs.write_string_to_file("\{root}/docs/setting/factions.md", "# factions\n")
  @fs.write_string_to_file("\{root}/docs/setting/lone.md", "# lonely doc\n")
}

///|
test "coverage: docs dimension counts referenced + unreferenced files" {
  let root = "/tmp/vmap-cov-docs"
  // Clean any stale state from prior test runs.
  if @fs.path_exists(root) {
    cleanup_dir(root)
  }
  build_fixture(root)
  let dag = @core.Dag::empty("demo")
  // Reference 2 of the 4 markdown files.
  dag.add_goal(id="goal-mastery", title="player can practice mastery", docs=[
    "\{root}/docs/setting/mastery.md",
  ])
  dag.add_goal(id="goal-factions", title="player can join factions", docs=[
    "\{root}/docs/setting/factions.md",
  ])
  let report = dag.coverage([root], "", "", true, false, false)
  guard report.docs is Some(d) else { fail("expected docs report") }
  assert_eq(d.total, 4)
  assert_eq(d.referenced, 2)
  assert_eq(d.unreferenced_total, 2)
  // Sorted alphabetically: lone.md before README.md (lowercase 'l' < 'R').
  assert_true(d.unreferenced_examples.length() == 2)
}

///|
test "coverage: code dimension flags unmatched src dirs" {
  let root = "/tmp/vmap-cov-code"
  if @fs.path_exists(root) {
    cleanup_dir(root)
  }
  build_fixture(root)
  let dag = @core.Dag::empty("demo")
  // Only mastery is in the DAG; factions and quests are codebase-only.
  dag.add_goal(id="goal-mastery", title="A", docs=["x.md"])
  let report = dag.coverage([], "\{root}/src/lib", "", false, true, false)
  guard report.code is Some(c) else { fail("expected code report") }
  assert_eq(c.total, 3)
  assert_eq(c.matched, 1)
  assert_eq(c.unmatched.length(), 2)
}

///|
test "coverage: issues dimension parses gh JSON + counts direct refs" {
  let root = "/tmp/vmap-cov-issues"
  if @fs.path_exists(root) {
    cleanup_dir(root)
  }
  @core.ensure_dir(root)
  let issues_body =
    #|[
    #|  {"number": 71, "title": "mastery system", "state": "CLOSED", "url": "https://github.com/owner/repo/issues/71"},
    #|  {"number": 72, "title": "facilities", "state": "OPEN", "url": "https://github.com/owner/repo/issues/72"},
    #|  {"number": 73, "title": "factions", "state": "OPEN", "url": "https://github.com/owner/repo/issues/73"}
    #|]
  @fs.write_string_to_file("\{root}/issues.json", issues_body)
  let dag = @core.Dag::empty("demo")
  // Reference issue 71 directly in docs, and add a gh_query field.
  dag.add_goal(
    id="goal-mastery",
    title="mastery",
    docs=["https://github.com/owner/repo/issues/71"],
    gh_query="is:issue label:mastery",
  )
  // Reference issue 73 via #N in description.
  dag.add_goal(
    id="goal-factions",
    title="factions",
    description="implements #73",
    docs=["docs/factions.md"],
  )
  let report = dag.coverage([], "", "\{root}/issues.json", false, false, true)
  guard report.issues is Some(i) else { fail("expected issues report") }
  assert_eq(i.total, 3)
  assert_eq(i.open, 2)
  assert_eq(i.closed, 1)
  assert_eq(i.referenced_direct, 2) // 71 + 73
  assert_eq(i.unreferenced_total, 1) // 72
  assert_eq(i.goals_with_gh_query, 1)
}

///|
test "coverage: issue references require numeric boundaries" {
  let root = "/tmp/vmap-cov-issue-boundary"
  if @fs.path_exists(root) {
    cleanup_dir(root)
  }
  @core.ensure_dir(root)
  let issues_body =
    #|[
    #|  {"number": 7, "title": "small", "state": "OPEN", "url": "https://github.com/owner/repo/issues/7"},
    #|  {"number": 71, "title": "large", "state": "OPEN", "url": "https://github.com/owner/repo/issues/71"},
    #|  {"number": 72, "title": "hash ref", "state": "OPEN", "url": "https://github.com/owner/repo/issues/72"}
    #|]
  @fs.write_string_to_file("\{root}/issues.json", issues_body)
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="goal-large", title="large", description="implements #72", docs=[
    "https://github.com/owner/repo/issues/71",
  ])
  let report = dag.coverage([], "", "\{root}/issues.json", false, false, true)
  guard report.issues is Some(i) else { fail("expected issues report") }
  assert_eq(i.referenced_direct, 2)
  assert_eq(i.unreferenced_total, 1)
  assert_true(i.unreferenced_examples[0].contains("#7 "))
}

///|
test "coverage: weakest dimension picked correctly" {
  let root = "/tmp/vmap-cov-weakest"
  if @fs.path_exists(root) {
    cleanup_dir(root)
  }
  build_fixture(root)
  let dag = @core.Dag::empty("demo")
  // Cover all docs but no code.
  dag.add_goal(id="g1", title="t", docs=[
    "\{root}/README.md",
    "\{root}/docs/setting/mastery.md",
    "\{root}/docs/setting/factions.md",
    "\{root}/docs/setting/lone.md",
  ])
  let report = dag.coverage([root], "\{root}/src/lib", "", true, true, false)
  // docs at 100%, code at 0% — so weakest is code.
  assert_eq(report.weakest, "code")
}

///|
/// Recursively delete `path` so tests can re-run idempotently.
fn cleanup_dir(path : String) -> Unit raise {
  let is_dir = @fs.is_dir(path) catch { _ => false }
  if not(is_dir) {
    if @fs.path_exists(path) {
      @fs.remove_file(path)
    }
    return
  }
  let entries = @fs.read_dir(path)
  for e in entries {
    cleanup_dir("\{path}/\{e}")
  }
  @fs.remove_dir(path)
}

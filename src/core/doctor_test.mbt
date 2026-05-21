///|
test "doctor: clean small DAG produces no warnings" {
  let dag = @core.Dag::empty("demo")
  // g1 ← g2 chain inside a closed release — neither is orphan (g1 has g2 as
  // downstream; g2 is in a closed release).
  dag.add_release(
    key="0.1",
    label_en="ship",
    label_zh="发布",
    status="closed",
  )
  dag.add_goal(id="g1", title="t1", docs=["g1.md"], milestone="0.1")
  dag.add_goal(
    id="g2",
    title="t2",
    docs=["g2.md"],
    deps=["g1"],
    milestone="0.1",
  )
  // Use a missing scan_root + src_root so we don't pick up the surrounding repo.
  let report = dag.doctor("/tmp/vmap-doctor-empty", "/tmp/vmap-doctor-empty")
  assert_eq(report.ok, true)
  assert_eq(report.warnings.length(), 0)
}

///|
test "doctor: orphan goal in non-closed release is flagged" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(
    key="0.1",
    label_en="next",
    label_zh="下一版",
    status="open",
  )
  dag.add_goal(id="goal-leaf", title="leaf", docs=["x.md"], milestone="0.1")
  let report = dag.doctor("/tmp/vmap-doctor-orphan", "/tmp/vmap-doctor-orphan")
  let any_orphan = report.warnings.any(w => w.kind == "orphan_goal")
  assert_true(any_orphan)
}

///|
test "doctor: closed-release members are NOT flagged as orphans" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(
    key="0.1",
    label_en="ship",
    label_zh="发布",
    status="closed",
  )
  dag.add_goal(id="goal-shipped", title="A", docs=["x.md"], milestone="0.1")
  let report = dag.doctor("/tmp/vmap-doctor-closed", "/tmp/vmap-doctor-closed")
  let any_orphan = report.warnings.any(w => w.kind == "orphan_goal")
  assert_eq(any_orphan, false)
}

///|
test "doctor: lane imbalance fires when one open lane dwarfs the others" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.1", label_en="a", label_zh="a", status="open")
  dag.add_release(key="0.2", label_en="b", label_zh="b", status="open")
  dag.add_release(key="0.3", label_en="c", label_zh="c", status="open")
  let docs_arr = ["x.md"]
  for i in 0..<11 {
    dag.add_goal(id="goal-a\{i}", title="a\{i}", docs=docs_arr, milestone="0.1")
  }
  dag.add_goal(id="goal-b", title="b", docs=docs_arr, milestone="0.2")
  dag.add_goal(id="goal-c", title="c", docs=docs_arr, milestone="0.3")
  let report = dag.doctor("/tmp/vmap-doctor-lane", "/tmp/vmap-doctor-lane")
  let any_imbalance = report.warnings.any(w => w.kind == "lane_imbalance")
  assert_true(any_imbalance)
}

///|
test "doctor: lane imbalance works with two active lanes" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.1", label_en="a", label_zh="a", status="open")
  dag.add_release(key="0.2", label_en="b", label_zh="b", status="open")
  let docs_arr = ["x.md"]
  for i in 0..<4 {
    dag.add_goal(id="goal-a\{i}", title="a\{i}", docs=docs_arr, milestone="0.1")
  }
  dag.add_goal(id="goal-b", title="b", docs=docs_arr, milestone="0.2")
  let report = dag.doctor(
    "/tmp/vmap-doctor-two-lane", "/tmp/vmap-doctor-two-lane",
  )
  let any_imbalance = report.warnings.any(w => w.kind == "lane_imbalance")
  assert_true(any_imbalance)
}

///|
test "doctor: codebase mismatch fires for src dirs with no matching goal" {
  let root = "/tmp/vmap-doctor-mismatch"
  // Build a fixture src dir with mastery / factions subdirs.
  if @fs.path_exists(root) {
    cleanup_dir2(root)
  }
  @core.ensure_dir("\{root}/src/lib/mastery")
  @core.ensure_dir("\{root}/src/lib/factions")
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="goal-other", title="unrelated", docs=["x.md"])
  let report = dag.doctor("/tmp/vmap-doctor-mismatch-empty", "\{root}/src/lib")
  let mismatches = report.warnings.filter(w => w.kind == "codebase_mismatch")
  // Both "mastery" and "factions" dirs should be flagged.
  assert_eq(mismatches.length(), 2)
}

///|
test "doctor: matching id substring suppresses codebase mismatch" {
  let root = "/tmp/vmap-doctor-match"
  if @fs.path_exists(root) {
    cleanup_dir2(root)
  }
  @core.ensure_dir("\{root}/src/lib/mastery")
  let dag = @core.Dag::empty("demo")
  // goal-mastery contains 'mastery' substring, so the mastery dir matches.
  dag.add_goal(id="goal-mastery", title="player can practice", docs=["x.md"])
  let report = dag.doctor("/tmp/vmap-doctor-match-empty", "\{root}/src/lib")
  let mismatches = report.warnings.filter(w => w.kind == "codebase_mismatch")
  assert_eq(mismatches.length(), 0)
}

///|
fn cleanup_dir2(path : String) -> Unit raise {
  let is_dir = @fs.is_dir(path) catch { _ => false }
  if !is_dir {
    if @fs.path_exists(path) {
      @fs.remove_file(path)
    }
    return
  }
  let entries = @fs.read_dir(path)
  for e in entries {
    cleanup_dir2("\{path}/\{e}")
  }
  @fs.remove_dir(path)
}

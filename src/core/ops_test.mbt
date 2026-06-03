///|
test "add goal and task, progress tracks done count" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="用户能登录")
  dag.add_task(id="i1", goal="m1", title="写 auth middleware")
  dag.add_task(id="i2", goal="m1", title="加 session cookie")
  @debug.assert_eq(dag.progress("m1"), (0, 2))
  dag.update_status("i1", @core.Done)
  @debug.assert_eq(dag.progress("m1"), (1, 2))
}

///|
test "duplicate id is rejected" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  let err : Result[Unit, @core.DagError] = try? dag.add_goal(id="m1", title="B")
  guard err is Err(DuplicateId("m1")) else {
    fail("expected DuplicateId, got: \{@debug.to_repr(err)}")
  }
}

///|
test "task under unknown goal is rejected" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_task(
    id="i1",
    goal="nope",
    title="x",
  )
  guard err is Err(UnknownGoal("nope")) else {
    fail("expected UnknownGoal, got: \{@debug.to_repr(err)}")
  }
}

///|
test "cycle in task deps is detected" {
  // Build a valid graph first, then mutate deps to create a cycle and re-check.
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  dag.add_task(id="i1", goal="m1", title="one")
  dag.add_task(id="i2", goal="m1", title="two", deps=["i1"])
  // Sneak a back-edge in: i1 now depends on i2.
  let (idx, i1) = dag.find_task("i1").unwrap()
  dag.tasks[idx] = { ..i1, deps: ["i2"] }
  let err : Result[Unit, @core.DagError] = try? dag.assert_acyclic()
  guard err is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{@debug.to_repr(err)}")
  }
}

///|
test "remove goal drops its tasks and scrubs deps" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A")
  dag.add_goal(id="m2", title="B", deps=["m1"])
  dag.add_task(id="i1", goal="m1", title="x")
  dag.add_task(id="i2", goal="m2", title="y")
  dag.remove("m1")
  assert_eq(dag.goals.length(), 1)
  assert_eq(dag.tasks.length(), 1)
  // m2's deps no longer reference the removed goal.
  let (_, m2) = dag.find_goal("m2").unwrap()
  assert_eq(m2.deps.length(), 0)
}

///|
test "goal closure can only move forward" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="A", closure="obligation")
  dag.set_goal_closure("m1", "scoped")
  let err : Result[Unit, @core.DagError] = try? dag.set_goal_closure(
    "m1", "seed",
  )
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

///|
test "goal metadata validates against config enums" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_goal(
    id="m1",
    title="A",
    closure="ghost",
  )
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

///|
test "config metadata is validated" {
  let dag = @core.Dag::empty("demo")
  let cfg = dag.effective_config()
  let bad : @core.Dag = { ..dag, config: Some({ ..cfg, products: [] }) }
  let err : Result[Unit, @core.DagError] = try? bad.validate()
  guard err is Err(InvalidMetadata(_)) else { fail("expected InvalidMetadata") }
}

///|
test "add_release appends to releases, duplicates rejected" {
  let dag = @core.Dag::empty("demo")
  assert_eq(dag.has_any_release(), false)
  dag.add_release(key="0.4.0", label_en="serve", label_zh="实时")
  assert_eq(dag.has_release("0.4.0"), true)
  assert_eq(dag.has_any_release(), true)
  let err : Result[Unit, @core.DagError] = try? dag.add_release(
    key="0.4.0",
    label_en="x",
    label_zh="y",
  )
  guard err is Err(DuplicateRelease("0.4.0")) else {
    fail("expected DuplicateRelease, got: \{@debug.to_repr(err)}")
  }
}

///|
test "add_release rejects unknown status" {
  let dag = @core.Dag::empty("demo")
  let err : Result[Unit, @core.DagError] = try? dag.add_release(
    key="0.4.0",
    label_en="x",
    label_zh="y",
    status="shipped",
  )
  guard err is Err(InvalidMetadata(_)) else {
    fail("expected InvalidMetadata, got: \{@debug.to_repr(err)}")
  }
}

///|
test "assign_release fails if release does not exist" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g1", title="A")
  let err : Result[Unit, @core.DagError] = try? dag.assign_release(
    "g1", "ghost",
  )
  guard err is Err(UnknownRelease("ghost")) else {
    fail("expected UnknownRelease, got: \{@debug.to_repr(err)}")
  }
}

///|
test "assign_release fails if goal does not exist" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  let err : Result[Unit, @core.DagError] = try? dag.assign_release(
    "ghost", "0.4.0",
  )
  guard err is Err(UnknownGoal("ghost")) else {
    fail("expected UnknownGoal, got: \{@debug.to_repr(err)}")
  }
}

///|
test "assign_release sets goal.milestone" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  dag.add_goal(id="g1", title="A")
  dag.assign_release("g1", "0.4.0")
  let (_, g) = dag.find_goal("g1").unwrap()
  @debug.assert_eq(g.milestone, Some("0.4.0"))
  let members = dag.release_member_ids("0.4.0")
  assert_eq(members.length(), 1)
  assert_eq(members[0], "g1")
}

///|
test "goal milestone is validated once releases are configured" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  let err : Result[Unit, @core.DagError] = try? dag.add_goal(
    id="g1",
    title="A",
    milestone="ghost",
  )
  guard err is Err(UnknownRelease("ghost")) else {
    fail("expected UnknownRelease, got: \{@debug.to_repr(err)}")
  }
}

///|
test "validate rejects duplicate release keys from hand-edited JSON" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  match dag.releases {
    Some(arr) =>
      arr.push({
        key: "0.4.0",
        label: { en: "again", zh: "重复" },
        target: None,
        status: "open",
        notes: None,
        closed_at: None,
      })
    None => fail("expected releases")
  }
  let err : Result[Unit, @core.DagError] = try? dag.validate()
  guard err is Err(DuplicateRelease("0.4.0")) else {
    fail("expected DuplicateRelease, got: \{@debug.to_repr(err)}")
  }
}

///|
test "remove_release refuses if goals still point at it" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  dag.add_goal(id="g1", title="A")
  dag.assign_release("g1", "0.4.0")
  let err : Result[Unit, @core.DagError] = try? dag.remove_release("0.4.0")
  guard err is Err(ReleaseHasMembers("0.4.0", members)) else {
    fail("expected ReleaseHasMembers, got: \{@debug.to_repr(err)}")
  }
  assert_eq(members.length(), 1)
}

///|
test "remove_release with force clears member milestones" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  dag.add_goal(id="g1", title="A")
  dag.assign_release("g1", "0.4.0")
  dag.remove_release("0.4.0", force=true)
  assert_eq(dag.has_release("0.4.0"), false)
  let (_, g) = dag.find_goal("g1").unwrap()
  @debug.assert_eq(g.milestone, None)
}

///|
test "update_release cannot regress closed -> open" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y", status="closed")
  let err : Result[Unit, @core.DagError] = try? dag.update_release(
    "0.4.0",
    status="open",
  )
  guard err is Err(ReleaseStatusRegression("0.4.0", "closed", "open")) else {
    fail("expected ReleaseStatusRegression, got: \{@debug.to_repr(err)}")
  }
}

///|
test "release_progress reports blocked goals and ready_to_close" {
  let dag = @core.Dag::empty("demo")
  dag.add_release(key="0.4.0", label_en="x", label_zh="y")
  dag.add_goal(id="g1", title="A", closure="seed")
  dag.add_goal(id="g2", title="B", closure="public")
  dag.assign_release("g1", "0.4.0")
  dag.assign_release("g2", "0.4.0")
  let p1 = dag.release_progress("0.4.0")
  assert_eq(p1.total_goals, 2)
  assert_eq(p1.blocked.length(), 1)
  assert_eq(p1.blocked[0], "g1")
  assert_eq(p1.ready_to_close, false)
  // promote g1 past public
  dag.set_goal_closure("g1", "obligation")
  dag.set_goal_closure("g1", "scoped")
  dag.set_goal_closure("g1", "public")
  let p2 = dag.release_progress("0.4.0")
  assert_eq(p2.blocked.length(), 0)
  assert_eq(p2.ready_to_close, true)
}

///|
test "release_progress raises UnknownRelease for missing key" {
  let dag = @core.Dag::empty("demo")
  let err : Result[@core.ReleaseProgress, @core.DagError] = try? dag.release_progress(
    "nope",
  )
  guard err is Err(UnknownRelease("nope")) else {
    fail("expected UnknownRelease, got: \{@debug.to_repr(err)}")
  }
}

///|
test "set_deps refuses self-dep and catches cycles" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="a", title="A")
  dag.add_goal(id="b", title="B")
  // self-dep
  let err1 : Result[Unit, @core.DagError] = try? dag.set_deps("a", ["a"])
  guard err1 is Err(InvalidMetadata(_)) else {
    fail("expected InvalidMetadata for self-dep, got: \{@debug.to_repr(err1)}")
  }
  // cycle via two set_deps calls: a→b, b→a
  dag.set_deps("a", ["b"])
  let err2 : Result[Unit, @core.DagError] = try? dag.set_deps("b", ["a"])
  guard err2 is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{@debug.to_repr(err2)}")
  }
}

///|
test "set_deps validates layer (goal→goal, task→task)" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g1", title="A")
  dag.add_task(id="t1", goal="g1", title="x")
  // goal can't depend on task
  let err1 : Result[Unit, @core.DagError] = try? dag.set_deps("g1", ["t1"])
  guard err1 is Err(UnknownId(_)) else {
    fail("expected UnknownId (task as goal dep), got: \{@debug.to_repr(err1)}")
  }
  // task can't depend on goal
  let err2 : Result[Unit, @core.DagError] = try? dag.set_deps("t1", ["g1"])
  guard err2 is Err(UnknownId(_)) else {
    fail("expected UnknownId (goal as task dep), got: \{@debug.to_repr(err2)}")
  }
}

///|
test "add_dep is idempotent and respects cycles" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="a", title="A")
  dag.add_goal(id="b", title="B")
  dag.add_dep("a", "b")
  dag.add_dep("a", "b") // idempotent
  let (_, ga) = dag.find_goal("a").unwrap()
  assert_eq(ga.deps.length(), 1)
  // adding reverse edge cycles
  let err : Result[Unit, @core.DagError] = try? dag.add_dep("b", "a")
  guard err is Err(CycleDetected(_)) else {
    fail("expected CycleDetected, got: \{@debug.to_repr(err)}")
  }
}

///|
test "rename rewrites all references" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="a", title="A")
  dag.add_goal(id="b", title="B", deps=["a"])
  dag.add_task(id="t1", goal="a", title="x")
  dag.rename("a", "alpha")
  // goal renamed
  assert_eq(dag.has_goal("a"), false)
  assert_eq(dag.has_goal("alpha"), true)
  // goal deps rewritten
  let (_, gb) = dag.find_goal("b").unwrap()
  assert_eq(gb.deps[0], "alpha")
  // task.goal rewritten
  let (_, t1) = dag.find_task("t1").unwrap()
  assert_eq(t1.goal, "alpha")
}

///|
test "rename rejects duplicate new id" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="a", title="A")
  dag.add_goal(id="b", title="B")
  let err : Result[Unit, @core.DagError] = try? dag.rename("a", "b")
  guard err is Err(DuplicateId("b")) else {
    fail("expected DuplicateId, got: \{@debug.to_repr(err)}")
  }
}

///|
test "upstream and downstream return transitive closure" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="a", title="A")
  dag.add_goal(id="b", title="B", deps=["a"])
  dag.add_goal(id="c", title="C", deps=["b"])
  dag.add_goal(id="d", title="D", deps=["c", "a"])
  // c upstream = b, a (b first, then a via b)
  let up = dag.upstream("c")
  assert_eq(up.length(), 2)
  // a downstream = b, c, d
  let down = dag.downstream("a")
  assert_eq(down.length(), 3)
}

///|
test "context for goal returns deterministic ancestor goals and owned files" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g-base", title="Base", tests=["tests/base.mbt"], docs=[
    "docs/base.md",
  ])
  dag.add_task(
    id="t-base",
    goal="g-base",
    title="base impl",
    tests=["tests/base-task.mbt"],
    docs=["src/base.mbt"],
  )
  dag.add_goal(
    id="g-mid",
    title="Mid",
    deps=["g-base"],
    tests=["tests/shared.mbt"],
    docs=["docs/mid.md"],
  )
  dag.add_task(
    id="t-mid",
    goal="g-mid",
    title="mid impl",
    tests=["tests/shared.mbt"],
    docs=["src/mid.mbt"],
  )
  dag.add_goal(
    id="g-leaf",
    title="Leaf",
    deps=["g-mid", "g-base"],
    tests=["tests/leaf.mbt"],
    docs=["docs/leaf.md"],
  )
  let slice = dag.context("g-leaf")
  @debug.assert_eq(slice.ancestor_goals, ["g-base", "g-mid"])
  @debug.assert_eq(slice.files, [
    "docs/base.md", "docs/leaf.md", "docs/mid.md", "src/base.mbt", "src/mid.mbt",
    "tests/base-task.mbt", "tests/base.mbt", "tests/leaf.mbt", "tests/shared.mbt",
  ])
}

///|
test "context for task follows task deps without unrelated sibling tasks" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g-core", title="Core", docs=["docs/core.md"])
  dag.add_task(
    id="t-core",
    goal="g-core",
    title="core impl",
    tests=["tests/core.mbt"],
    docs=["src/core.mbt"],
  )
  dag.add_goal(id="g-feature", title="Feature", deps=["g-core"], docs=[
    "docs/feature.md",
  ])
  dag.add_task(
    id="t-feature-a",
    goal="g-feature",
    title="feature helper",
    tests=["tests/a.mbt"],
    docs=["src/a.mbt"],
  )
  dag.add_task(
    id="t-feature-b",
    goal="g-feature",
    title="feature finish",
    deps=["t-feature-a"],
    tests=["tests/b.mbt"],
    docs=["src/b.mbt"],
  )
  dag.add_task(
    id="t-sibling",
    goal="g-feature",
    title="unrelated sibling",
    tests=["tests/sibling.mbt"],
    docs=["src/sibling.mbt"],
  )
  let slice = dag.context("t-feature-b")
  @debug.assert_eq(slice.ancestor_goals, ["g-core"])
  @debug.assert_eq(slice.files, [
    "docs/core.md", "docs/feature.md", "src/a.mbt", "src/b.mbt", "src/core.mbt",
    "tests/a.mbt", "tests/b.mbt", "tests/core.mbt",
  ])
}

///|
test "set_task_goal validates destination goal" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g1", title="A")
  dag.add_task(id="t1", goal="g1", title="x")
  let err : Result[Unit, @core.DagError] = try? dag.set_task_goal("t1", "ghost")
  guard err is Err(UnknownGoal("ghost")) else {
    fail("expected UnknownGoal, got: \{@debug.to_repr(err)}")
  }
}

///|
test "set_description rejects task ids; set_task_notes rejects goal ids" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="g1", title="A")
  dag.add_task(id="t1", goal="g1", title="x")
  let e1 : Result[Unit, @core.DagError] = try? dag.set_description("t1", "...")
  guard e1 is Err(UnknownId(_)) else {
    fail("set_description on task should fail, got: \{@debug.to_repr(e1)}")
  }
  let e2 : Result[Unit, @core.DagError] = try? dag.set_task_notes("g1", "...")
  guard e2 is Err(UnknownId(_)) else {
    fail("set_task_notes on goal should fail, got: \{@debug.to_repr(e2)}")
  }
}

///|
test "regression_prompt: formats goal, tasks, docs, tests, and error messages" {
  let dag = @core.Dag::empty("demo")

  // Create temp docs and test files
  let temp_doc_path = "/tmp/vmap-test-doc.md"
  let temp_test_path = "/tmp/vmap-test-test.mbt"

  // Write temp files
  @core.write_text(temp_doc_path, "This is doc content\n")
  @core.write_text(temp_test_path, "This is test content\n")

  dag.add_goal(
    id="goal-reg",
    title="Goal Regression Test",
    description="A goal under test",
    docs=[temp_doc_path, "/tmp/non-existent-doc.md"],
    tests=[temp_test_path, "/tmp/non-existent-test.mbt"],
  )

  dag.add_task(id="task-reg-1", goal="goal-reg", title="Task 1")

  let prompt = dag.regression_prompt(
    "goal-reg",
    error_content="Compiler error at line 42\n",
  )

  // Verify contents in prompt
  assert_true(prompt.contains("## Goal: [goal-reg] (Goal Regression Test)"))
  assert_true(prompt.contains("- **Description**: A goal under test"))
  assert_true(prompt.contains("### Associated Tasks:"))
  assert_true(prompt.contains("- [ ] task-reg-1: Task 1 (Status: todo)"))
  assert_true(prompt.contains("### Requirements & Documentation:"))
  assert_true(prompt.contains("#### File: `\{temp_doc_path}`"))
  assert_true(prompt.contains("This is doc content"))
  assert_true(
    prompt.contains("#### File: `/tmp/non-existent-doc.md` [Not found on disk]"),
  )
  assert_true(prompt.contains("### Associated Tests:"))
  assert_true(prompt.contains("#### File: `\{temp_test_path}`"))
  assert_true(prompt.contains("This is test content"))
  assert_true(
    prompt.contains(
      "#### File: `/tmp/non-existent-test.mbt` [Not found on disk]",
    ),
  )
  assert_true(prompt.contains("### Test Failure / Error Output:"))
  assert_true(prompt.contains("Compiler error at line 42"))
  assert_true(prompt.contains("## Instructions for AI Agent:"))

  // Clean up temp files
  if @fs.path_exists(temp_doc_path) {
    @fs.remove_file(temp_doc_path)
  }
  if @fs.path_exists(temp_test_path) {
    @fs.remove_file(temp_test_path)
  }
}

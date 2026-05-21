///|
pub fn Dag::regression_prompt(
  self : Dag,
  id : String,
  error_content? : String = "",
) -> String raise DagError {
  let (_, goal) = match self.find_goal(id) {
    Some(res) => res
    None => raise UnknownId(id)
  }
  let sb = StringBuilder::new()
  sb.write_string("# Vibe-Map Regression Diagnosis & Auto-Fix Request\n\n")
  sb.write_string(
    "We have detected a regression or test failure for the following Goal:\n\n",
  )

  sb.write_string("## Goal: [")
  sb.write_string(goal.id)
  sb.write_string("] (")
  sb.write_string(goal.title)
  sb.write_string(")\n")
  if goal.description != "" {
    sb.write_string("- **Description**: ")
    sb.write_string(goal.description)
    sb.write_string("\n")
  }
  match goal.milestone {
    Some(m) => if m != "" { sb.write_string("- **Milestone/Release**: \{m}\n") }
    None => ()
  }
  match goal.owner {
    Some(o) => if o != "" { sb.write_string("- **Owner**: @\{o}\n") }
    None => ()
  }
  let closure = match goal.closure {
    Some(c) => if c == "" { "seed" } else { c }
    None => "seed"
  }
  sb.write_string("- **Closure State**: \{closure}\n\n")

  // Tasks
  let tasks = self.tasks_of(id)
  if tasks.length() > 0 {
    sb.write_string("### Associated Tasks:\n")
    for t in tasks {
      let status_str = match t.status {
        Todo => "todo"
        InProgress => "in-progress"
        Blocked => "blocked"
        Done => "done"
      }
      sb.write_string("- [")
      if t.status is Done {
        sb.write_char('x')
      } else {
        sb.write_char(' ')
      }
      sb.write_string("] \{t.id}: \{t.title} (Status: \{status_str})\n")
    }
    sb.write_string("\n")
  }

  // Docs
  if goal.docs.length() > 0 {
    sb.write_string("### Requirements & Documentation:\n")
    for doc in goal.docs {
      if @fs.path_exists(doc) {
        sb.write_string("#### File: `\{doc}`\n")
        sb.write_string("```\n")
        let content = @fs.read_file_to_string(doc) catch {
          err => raise IoError("read \{doc}: \{@debug.to_repr(err)}")
        }
        sb.write_string(content)
        if !content.has_suffix("\n") {
          sb.write_char('\n')
        }
        sb.write_string("```\n\n")
      } else {
        sb.write_string("#### File: `\{doc}` [Not found on disk]\n\n")
      }
    }
  }

  // Tests
  if goal.tests.length() > 0 {
    sb.write_string("### Associated Tests:\n")
    for test_path in goal.tests {
      if @fs.path_exists(test_path) {
        sb.write_string("#### File: `\{test_path}`\n")
        sb.write_string("```\n")
        let content = @fs.read_file_to_string(test_path) catch {
          err => raise IoError("read \{test_path}: \{@debug.to_repr(err)}")
        }
        sb.write_string(content)
        if !content.has_suffix("\n") {
          sb.write_char('\n')
        }
        sb.write_string("```\n\n")
      } else {
        sb.write_string("#### File: `\{test_path}` [Not found on disk]\n\n")
      }
    }
  }

  // Error Content
  if error_content != "" {
    sb.write_string("### Test Failure / Error Output:\n")
    sb.write_string("```\n")
    sb.write_string(error_content)
    if !error_content.has_suffix("\n") {
      sb.write_char('\n')
    }
    sb.write_string("```\n\n")
  }

  sb.write_string("## Instructions for AI Agent:\n")
  sb.write_string(
    "1. Review the requirements and design outlined in the documentation.\n",
  )
  sb.write_string(
    "2. Analyze the associated tests and the provided failure trace to understand what broke.\n",
  )
  sb.write_string("3. Identify the files containing the implementation.\n")
  sb.write_string(
    "4. Modify the source code to resolve the failure. Ensure that the test suite compiles and all tests pass.\n",
  )

  sb.to_string()
}

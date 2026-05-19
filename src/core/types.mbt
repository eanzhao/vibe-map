///|
/// Status of a task. Goal status is derived from its tasks.
pub(all) enum Status {
  Todo
  InProgress
  Blocked
  Done
} derive(Eq, Show)

///|
pub impl ToJson for Status with to_json(self) {
  match self {
    Todo => "todo"
    InProgress => "in-progress"
    Blocked => "blocked"
    Done => "done"
  }
}

///|
pub impl @json.FromJson for Status with from_json(j, path) {
  match j {
    String("todo") => Todo
    String("in-progress") => InProgress
    String("blocked") => Blocked
    String("done") => Done
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected one of \"todo\" | \"in-progress\" | \"blocked\" | \"done\"",
        ),
      )
  }
}

///|
pub(all) struct Project {
  name : String
  description : String
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Goal {
  id : String
  title : String
  description : String
  deps : Array[String]
  /// True if this goal maps to shippable code that should be guarded by
  /// a regression test (set by `vmap backfill`; manually overridable).
  regression_testable : Bool
  /// Test files / globs covering this goal (typically integration tests).
  tests : Array[String]
  /// Documentation paths describing this goal.
  docs : Array[String]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Task {
  id : String
  goal : String
  title : String
  status : Status
  deps : Array[String]
  notes : String
  /// True if this task corresponds to code that should have unit tests.
  regression_testable : Bool
  /// Test files / globs covering this task.
  tests : Array[String]
  /// Documentation paths describing this task.
  docs : Array[String]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Dag {
  project : Project
  goals : Array[Goal]
  tasks : Array[Task]
} derive(Eq, Show, ToJson, FromJson)

///|
/// Empty DAG with the given project name.
pub fn Dag::empty(name : String) -> Dag {
  { project: { name, description: "" }, goals: [], tasks: [] }
}

///|
pub(all) suberror DagError {
  DuplicateId(String)
  UnknownId(String)
  UnknownGoal(String)
  CycleDetected(String)
  IoError(String)
  ParseError(String)
} derive(Show)

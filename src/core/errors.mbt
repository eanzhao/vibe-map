///|
pub(all) suberror DagError {
  DuplicateId(String)
  UnknownId(String)
  UnknownGoal(String)
  CycleDetected(String)
  InvalidMetadata(String)
  IoError(String)
  ParseError(String)
} derive(Show)

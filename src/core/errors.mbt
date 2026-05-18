///|
pub(all) suberror DagError {
  DuplicateId(String)
  UnknownId(String)
  UnknownMilestone(String)
  CycleDetected(String)
  IoError(String)
  ParseError(String)
} derive(Show)

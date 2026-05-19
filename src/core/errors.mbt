///|
pub(all) suberror DagError {
  DuplicateId(String)
  UnknownId(String)
  UnknownGoal(String)
  UnknownRelease(String)
  DuplicateRelease(String)
  ReleaseHasMembers(String, Array[String])
  ReleaseStatusRegression(String, String, String)
  CycleDetected(String)
  InvalidMetadata(String)
  IoError(String)
  ParseError(String)
} derive(Show)

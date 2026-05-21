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
} derive(Debug)

///|
pub impl Show for DagError with output(self, logger) {
  logger.write_string(@debug.to_repr(self).to_string())
}

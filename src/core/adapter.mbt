///|
/// One source-level node discovered by an adapter. The adapter has already
/// classified files into source / test / doc — the generic backfill loop just
/// turns this into an `Issue`.
pub(all) struct DiscoveredIssue {
  /// Stable identifier component, e.g. file stem. Used for issue id slugging.
  stem : String
  /// Human-readable title (often the bare file name).
  title : String
  /// Test files (paths relative to the project root) covering this node.
  tests : Array[String]
  /// Doc paths describing this node.
  docs : Array[String]
} derive(Show)

///|
/// One "package" (build/source unit) discovered by an adapter. Maps 1:1 to a
/// vmap milestone.
pub(all) struct DiscoveredPackage {
  /// Path relative to the scan root. Used for milestone id slugging.
  rel_path : String
  /// Human-readable title (commonly equal to `rel_path`).
  title : String
  /// Package-level docs (README, design notes).
  docs : Array[String]
  /// Source-level nodes under this package.
  issues : Array[DiscoveredIssue]
} derive(Show)

// (Backfill behaviour is template-driven — see `template.mbt`.)

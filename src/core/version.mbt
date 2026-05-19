///|
/// Built-in version string for the vmap binary.
///
/// Default value `"dev"` for local builds. The release CI workflow
/// (`.github/workflows/release.yml`) regenerates this file before
/// `moon build --release`, baking in the git tag name (e.g. `v0.5.0-alpha.3`).
pub let version : String = "dev"

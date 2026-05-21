///|
/// JSON-driven backfill template. Adding a language = writing one of these,
/// not adding MoonBit code.
pub(all) struct Template {
  name : String
  detect : DetectRules
  package_discovery : PackageDiscovery
  files : FileRules
} derive(Debug, ToJson, FromJson)

///|
/// Auto-detection rules. The template applies to `root` if any listed file
/// exists at `root` OR any glob matches a top-level entry in `root`.
pub(all) struct DetectRules {
  files : Array[String]
  globs : Array[String]
} derive(Debug, ToJson, FromJson)

///|
/// What makes a directory a "package":
///   - it contains any of `marker_files` (e.g. `moon.pkg`, `package.json`)
///   - OR it directly contains a file with one of `marker_extensions`
///     (e.g. `.csproj` for .NET, `.ts` for TypeScript)
/// `min_source_files` is a sanity gate to skip directories with one
/// throwaway file.
pub(all) struct PackageDiscovery {
  marker_files : Array[String]
  marker_extensions : Array[String]
  skip_dirs : Array[String]
  strip_path_prefix : String
  min_source_files : Int
  /// If true, once a directory qualifies as a package the walker does not
  /// descend into it looking for further sub-packages. Use this for ecosystems
  /// where the conceptual unit is a directory of related code (TypeScript,
  /// generic). Leave false for ecosystems where every sub-package is its own
  /// compilation unit (MoonBit's moon.pkg, .NET's csproj).
  stop_at_package : Bool
  /// Post-walk grouping strategy. Currently supported:
  ///   - `"none"`: leave discovered packages as-is.
  ///   - `"namespace"`: collapse packages whose basename shares the first
  ///     `group_depth` dot-separated segments into one goal. Used for
  ///     .NET where `Aevatar.Foundation.X` + `Aevatar.Foundation.Y` should
  ///     fold into one "Aevatar.Foundation" goal.
  group_by : String
  group_depth : Int
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct FileRules {
  source : SourceRule
  test_colocated : PatternList
  task_doc : PatternList
  package_doc : NameList
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct SourceRule {
  globs : Array[String]
  excludes : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct PatternList {
  patterns : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct NameList {
  names : Array[String]
} derive(Debug, ToJson, FromJson)

///|
/// True if any of the template's detection rules fires at `root`.
pub fn Template::detect_at(
  self : Template,
  root : String,
) -> Bool raise DagError {
  for f in self.detect.files {
    if @fs.path_exists("\{root}/\{f}") {
      return true
    }
  }
  if self.detect.globs.length() > 0 {
    let entries = @fs.read_dir(root) catch {
      err => raise IoError("read_dir \{root}: \{@debug.to_repr(err)}")
    }
    for entry in entries {
      for pat in self.detect.globs {
        if matches_pattern(entry, pat) {
          return true
        }
      }
    }
  }
  false
}

///|
/// Walk the tree and produce one `DiscoveredPackage` per qualifying directory.
pub fn Template::discover(
  self : Template,
  root : String,
) -> Array[DiscoveredPackage] raise DagError {
  if !@fs.path_exists(root) {
    raise IoError("source root not found: \{root}")
  }
  let normalized_root = strip_trailing_slash(root)
  let packages = []
  self.walk(normalized_root, normalized_root, packages)
  let leaf_filtered = if self.package_discovery.stop_at_package {
    keep_leaf_packages(packages)
  } else {
    packages
  }
  let grouped = if self.package_discovery.group_by == "namespace" {
    group_by_namespace(leaf_filtered, self.package_discovery.group_depth)
  } else {
    leaf_filtered
  }
  grouped.sort_by((a, b) => a.rel_path.lexical_compare(b.rel_path))
  grouped
}

///|
/// Fold packages whose basename shares the first `depth` dot-segments into
/// one DiscoveredPackage. Used by .NET to collapse `Aevatar.Foundation.X`
/// projects into a single "Aevatar.Foundation" goal.
fn group_by_namespace(
  packages : Array[DiscoveredPackage],
  depth : Int,
) -> Array[DiscoveredPackage] {
  let groups : Map[String, DiscoveredPackage] = {}
  let order : Array[String] = []
  for pkg in packages {
    let basename = basename_of(pkg.rel_path)
    let key = take_dot_prefix(basename, depth)
    let prefixed_tasks : Array[DiscoveredTask] = []
    for task in pkg.tasks {
      // Disambiguate task stems with the source package basename so two
      // projects in the same group can both have e.g. `Class1.cs` without
      // colliding on task id.
      let new_stem = slug_dots(basename) + "-" + task.stem
      prefixed_tasks.push({ ..task, stem: new_stem })
    }
    match groups.get(key) {
      Some(existing) => {
        for d in pkg.docs {
          existing.docs.push(d)
        }
        for task in prefixed_tasks {
          existing.tasks.push(task)
        }
      }
      None => {
        order.push(key)
        groups[key] = {
          rel_path: key,
          title: key,
          docs: pkg.docs.copy(),
          tasks: prefixed_tasks,
        }
      }
    }
  }
  let out : Array[DiscoveredPackage] = []
  for k in order {
    match groups.get(k) {
      Some(v) => out.push(v)
      None => ()
    }
  }
  out
}

///|
/// Last `/`-separated segment of a relative path. `lib/ganzhi` -> `ganzhi`.
fn basename_of(rel : String) -> String {
  match last_index_of_char(rel, '/') {
    Some(idx) => rel[idx + 1:rel.length()].to_owned()
    None => rel
  }
}

///|
/// First `depth` dot-separated segments of `name`, re-joined with dots. If
/// `name` has fewer segments than `depth`, return the whole thing.
fn take_dot_prefix(name : String, depth : Int) -> String {
  if depth <= 0 {
    return name
  }
  let sb = StringBuilder::new()
  let mut seen = 0
  let mut i = 0
  for ch in name {
    if ch == '.' {
      seen = seen + 1
      if seen >= depth {
        break
      }
    }
    sb.write_char(ch)
    i = i + 1
  }
  ignore(i)
  sb.to_string()
}

///|
/// Replace `.` and other id-unsafe chars with `-`, for task stem prefixes.
fn slug_dots(s : String) -> String {
  let sb = StringBuilder::new()
  for ch in s {
    if ch == '.' || ch == ' ' || ch == '/' {
      sb.write_char('-')
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
/// Keep only "leaf" packages — those with no other package candidate nested
/// under them. Used when `stop_at_package` is true (e.g. TypeScript), to
/// collapse intermediate `src/lib` style containers into their meaningful
/// sub-directory packages.
fn keep_leaf_packages(
  packages : Array[DiscoveredPackage],
) -> Array[DiscoveredPackage] {
  let out = []
  for pkg in packages {
    let mut is_leaf = true
    for other in packages {
      if other.rel_path == pkg.rel_path {
        continue
      }
      if is_descendant_rel(pkg.rel_path, other.rel_path) {
        is_leaf = false
        break
      }
    }
    if is_leaf {
      out.push(pkg)
    }
  }
  out
}

///|
fn is_descendant_rel(parent : String, child : String) -> Bool {
  if parent == "." {
    child != "."
  } else {
    child.has_prefix(parent + "/")
  }
}

///|
fn Template::walk(
  self : Template,
  root : String,
  current : String,
  out : Array[DiscoveredPackage],
) -> Unit raise DagError {
  let is_dir = @fs.is_dir(current) catch {
    err => raise IoError("stat \{current}: \{@debug.to_repr(err)}")
  }
  if !is_dir {
    return
  }
  let entries = @fs.read_dir(current) catch {
    err => raise IoError("read_dir \{current}: \{@debug.to_repr(err)}")
  }
  entries.sort_by((a, b) => a.lexical_compare(b))
  if self.is_package_dir(current, entries) {
    let pkg = self.build_package(root, current, entries)
    if pkg.tasks.length() >= self.package_discovery.min_source_files {
      out.push(pkg)
    }
  }
  // We always recurse: leaf-only collapse happens in a post-pass when
  // `stop_at_package` is true.
  for entry in entries {
    if self.should_skip(entry) {
      continue
    }
    let full = "\{current}/\{entry}"
    let entry_is_dir = @fs.is_dir(full) catch { _ => false }
    if entry_is_dir {
      self.walk(root, full, out)
    }
  }
}

///|
fn Template::should_skip(self : Template, name : String) -> Bool {
  if name.has_prefix(".") {
    return true
  }
  for skip in self.package_discovery.skip_dirs {
    if name == skip {
      return true
    }
  }
  false
}

///|
fn Template::is_package_dir(
  self : Template,
  dir : String,
  entries : Array[String],
) -> Bool {
  for marker in self.package_discovery.marker_files {
    if contains_str(entries, marker) {
      return true
    }
  }
  if self.package_discovery.marker_extensions.length() > 0 {
    for entry in entries {
      for ext in self.package_discovery.marker_extensions {
        if entry.has_suffix(ext) {
          let is_file = @fs.is_file("\{dir}/\{entry}") catch { _ => false }
          if is_file {
            return true
          }
        }
      }
    }
  }
  false
}

///|
fn Template::build_package(
  self : Template,
  root : String,
  abs_path : String,
  entries : Array[String],
) -> DiscoveredPackage {
  let rel = relative_path(root, abs_path)
  let trimmed_rel = strip_prefix_dir(
    rel,
    self.package_discovery.strip_path_prefix,
  )
  let package_docs = []
  for name in self.files.package_doc.names {
    if contains_str(entries, name) {
      package_docs.push(name)
    }
  }
  let tasks = []
  for entry in entries {
    if !self.matches_source(entry) {
      continue
    }
    let stem = strip_source_extension(entry, self.files.source.globs)
    let tests = []
    for pat in self.files.test_colocated.patterns {
      let candidate = substitute_stem(pat, stem)
      if contains_str(entries, candidate) {
        tests.push(candidate)
      }
    }
    let task_docs = []
    for pat in self.files.task_doc.patterns {
      let candidate = substitute_stem(pat, stem)
      if contains_str(entries, candidate) {
        task_docs.push(candidate)
      }
    }
    tasks.push({ stem, title: entry, tests, docs: task_docs })
  }
  { rel_path: trimmed_rel, title: trimmed_rel, docs: package_docs, tasks }
}

///|
fn Template::matches_source(self : Template, name : String) -> Bool {
  let mut included = false
  for pat in self.files.source.globs {
    if matches_pattern(name, pat) {
      included = true
      break
    }
  }
  if !included {
    return false
  }
  for pat in self.files.source.excludes {
    if matches_pattern(name, pat) {
      return false
    }
  }
  true
}

///|
/// Very small glob: `*xyz` matches a suffix `xyz`; anything else is exact match.
fn matches_pattern(name : String, pattern : String) -> Bool {
  if pattern.has_prefix("*") {
    let suffix = pattern[1:pattern.length()].to_owned()
    name.has_suffix(suffix)
  } else {
    name == pattern
  }
}

///|
fn substitute_stem(pattern : String, stem : String) -> String {
  pattern.replace(old="{stem}", new=stem)
}

///|
/// Strip the longest matching extension from `name` based on the template's
/// `source.include` patterns. Falls back to dropping the last `.xyz` segment.
fn strip_source_extension(
  name : String,
  include_patterns : Array[String],
) -> String {
  let mut best = ""
  for pat in include_patterns {
    if pat.has_prefix("*") {
      let suffix = pat[1:pat.length()].to_owned()
      if name.has_suffix(suffix) && suffix.length() > best.length() {
        best = suffix
      }
    }
  }
  if best != "" {
    name[0:name.length() - best.length()].to_owned()
  } else {
    // Fallback: last dot.
    match last_index_of_char(name, '.') {
      Some(idx) => name[0:idx].to_owned()
      None => name
    }
  }
}

///|
fn last_index_of_char(s : String, ch : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for c in s {
    if c == ch {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    None
  } else {
    Some(found)
  }
}

///|
fn contains_str(arr : Array[String], needle : String) -> Bool {
  for item in arr {
    if item == needle {
      return true
    }
  }
  false
}

///|
/// Drop `prefix` (treated as a directory prefix) from `path` if present.
/// `prefix` of "" returns `path` unchanged. `prefix` should NOT have a leading
/// or trailing slash — they're handled here.
fn strip_prefix_dir(path : String, prefix : String) -> String {
  if prefix == "" {
    return path
  }
  let with_slash = prefix + "/"
  if path.has_prefix(with_slash) {
    path[with_slash.length():path.length()].to_owned()
  } else if path == prefix {
    "."
  } else {
    path
  }
}

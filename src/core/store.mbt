///|
/// Default file name at the project root.
pub let default_path : String = "vibe-map.json"

///|
/// Load a DAG from a JSON file. Returns a fresh empty DAG with the given
/// project name if the file does not exist.
pub fn load(
  path : String,
  default_name? : String = "untitled",
) -> Dag raise DagError {
  if not(@fs.path_exists(path)) {
    return Dag::empty(default_name)
  }
  let raw = @fs.read_file_to_string(path) catch {
    err => raise IoError("read \{path}: \{err}")
  }
  let parsed = @json.parse(raw) catch {
    err => raise ParseError("parse \{path}: \{err}")
  }
  @json.from_json(parsed) catch {
    err => raise ParseError("decode \{path}: \{err}")
  }
}

///|
/// Persist a DAG to disk as pretty-printed JSON.
pub fn save(dag : Dag, path : String) -> Unit raise DagError {
  let body = dag.to_json().stringify(indent=2)
  write_text(path, body)
}

///|
/// Write arbitrary text to disk, wrapping IO errors as `DagError`.
pub fn write_text(path : String, body : String) -> Unit raise DagError {
  @fs.write_string_to_file(path, body) catch {
    err => raise IoError("write \{path}: \{err}")
  }
}

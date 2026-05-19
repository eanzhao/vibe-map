///|
/// Default data file. Lives under `.vmap/` so the directory is one obvious
/// thing to add to `.gitignore`.
pub let default_path : String = ".vmap/vibe-map.json"

///|
/// Default visualization output. Sits alongside `default_path`; commands
/// that mutate the DAG auto-render here unless `--no-render` is passed.
pub let default_render_path : String = ".vmap/vibe-map.html"

///|
/// Default directory holding vmap state (json + rendered html).
pub let default_dir : String = ".vmap"

///|
/// Create the parent directory of `path` if missing. Single-level mkdir
/// only — `moonbitlang/x/fs.create_dir` does not do mkdir -p on native, so
/// we walk path segments ourselves.
pub fn ensure_parent_dir(path : String) -> Unit raise DagError {
  // Strip the final segment after the last '/' to get the parent.
  let mut last_slash = -1
  let mut i = 0
  for ch in path {
    if ch == '/' {
      last_slash = i
    }
    i = i + 1
  }
  if last_slash <= 0 {
    return
  }
  let parent = path[0:last_slash].to_string()
  ensure_dir(parent)
}

///|
/// Idempotently create `dir`, walking segments so nested paths work despite
/// the native fs limitation. Existing entries are left alone.
pub fn ensure_dir(dir : String) -> Unit raise DagError {
  if dir == "" || dir == "." {
    return
  }
  if @fs.path_exists(dir) {
    return
  }
  // Walk segments. Build cumulative path; create each missing level.
  let segments : Array[String] = []
  let sb = StringBuilder::new()
  for ch in dir {
    if ch == '/' {
      segments.push(sb.to_string())
      sb.reset()
    } else {
      sb.write_char(ch)
    }
  }
  segments.push(sb.to_string())
  let cum = StringBuilder::new()
  for idx, seg in segments {
    if idx > 0 {
      cum.write_char('/')
    }
    cum.write_string(seg)
    let so_far = cum.to_string()
    if so_far == "" || so_far == "." {
      continue
    }
    if not(@fs.path_exists(so_far)) {
      @fs.create_dir(so_far) catch {
        err => raise IoError("create_dir \{so_far}: \{err}")
      }
    }
  }
}

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
/// Persist a DAG to disk as pretty-printed JSON. Auto-creates the parent
/// directory so `.vmap/vibe-map.json` works out of the box on a clean repo.
pub fn save(dag : Dag, path : String) -> Unit raise DagError {
  ensure_parent_dir(path)
  let body = dag.to_json().stringify(indent=2)
  write_text(path, body)
}

///|
/// Read a vibe-map.json from disk and validate it before returning. Used by
/// `vmap import` to bulk-load a hand-crafted DAG. Errors include the source
/// file path so AI agents can correlate violations.
pub fn import_dag(in_path : String) -> Dag raise DagError {
  let raw = @fs.read_file_to_string(in_path) catch {
    err => raise IoError("read \{in_path}: \{err}")
  }
  let parsed = @json.parse(raw) catch {
    err => raise ParseError("parse \{in_path}: \{err}")
  }
  let dag : Dag = @json.from_json(parsed) catch {
    err => raise ParseError("decode \{in_path}: \{err}")
  }
  dag.validate()
  dag
}

///|
/// Write arbitrary text to disk, wrapping IO errors as `DagError`.
/// Auto-creates the parent directory.
pub fn write_text(path : String, body : String) -> Unit raise DagError {
  ensure_parent_dir(path)
  @fs.write_string_to_file(path, body) catch {
    err => raise IoError("write \{path}: \{err}")
  }
}

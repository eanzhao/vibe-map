///|
/// Built-in template for MoonBit projects.
let moonbit_template_json : String =
  #|{
  #|  "name": "moonbit",
  #|  "detect": {
  #|    "files": ["moon.mod.json"],
  #|    "globs": []
  #|  },
  #|  "package_discovery": {
  #|    "marker_files": ["moon.pkg", "moon.pkg.json"],
  #|    "marker_extensions": [],
  #|    "skip_dirs": [".git", ".mooncakes", "_build", "node_modules"],
  #|    "strip_path_prefix": "src",
  #|    "min_source_files": 0,
  #|    "stop_at_package": false,
  #|    "group_by": "none",
  #|    "group_depth": 0
  #|  },
  #|  "files": {
  #|    "source": {
  #|      "globs": ["*.mbt"],
  #|      "excludes": ["*_test.mbt", "*_wbtest.mbt", "*_blackbox_test.mbt"]
  #|    },
  #|    "test_colocated": {
  #|      "patterns": ["{stem}_test.mbt", "{stem}_wbtest.mbt", "{stem}_blackbox_test.mbt"]
  #|    },
  #|    "task_doc": {
  #|      "patterns": ["{stem}.mbt.md"]
  #|    },
  #|    "package_doc": {
  #|      "names": ["README.md", "README.mbt.md"]
  #|    }
  #|  }
  #|}

///|
/// Built-in template for TypeScript / JavaScript projects.
let typescript_template_json : String =
  #|{
  #|  "name": "typescript",
  #|  "detect": {
  #|    "files": ["package.json"],
  #|    "globs": []
  #|  },
  #|  "package_discovery": {
  #|    "marker_files": [],
  #|    "marker_extensions": [".ts", ".tsx", ".js", ".jsx"],
  #|    "skip_dirs": [".git", "node_modules", ".astro", ".wrangler", ".next", "dist", "build", "out", "_build", ".turbo", ".cache", "coverage", ".coverage", "playwright-report", ".vercel", ".nuxt"],
  #|    "strip_path_prefix": "src",
  #|    "min_source_files": 1,
  #|    "stop_at_package": true,
  #|    "group_by": "none",
  #|    "group_depth": 0
  #|  },
  #|  "files": {
  #|    "source": {
  #|      "globs": ["*.ts", "*.tsx", "*.js", "*.jsx"],
  #|      "excludes": ["*.test.ts", "*.test.tsx", "*.test.js", "*.spec.ts", "*.spec.tsx", "*.d.ts"]
  #|    },
  #|    "test_colocated": {
  #|      "patterns": ["{stem}.test.ts", "{stem}.test.tsx", "{stem}.test.js", "{stem}.spec.ts"]
  #|    },
  #|    "task_doc": {
  #|      "patterns": ["{stem}.md"]
  #|    },
  #|    "package_doc": {
  #|      "names": ["README.md"]
  #|    }
  #|  }
  #|}

///|
/// Built-in template for .NET / C# projects. Cousin-project tests
/// (`*.Tests.csproj`) need a v2 template feature, so v1 leaves tests unbound.
let dotnet_template_json : String =
  #|{
  #|  "name": "dotnet",
  #|  "detect": {
  #|    "files": ["Directory.Build.props"],
  #|    "globs": ["*.sln", "*.slnf", "*.csproj"]
  #|  },
  #|  "package_discovery": {
  #|    "marker_files": [],
  #|    "marker_extensions": [".csproj"],
  #|    "skip_dirs": [".git", "bin", "obj", "packages", "TestResults", "artifacts", "node_modules"],
  #|    "strip_path_prefix": "",
  #|    "min_source_files": 0,
  #|    "stop_at_package": false,
  #|    "group_by": "namespace",
  #|    "group_depth": 2
  #|  },
  #|  "files": {
  #|    "source": {
  #|      "globs": ["*.cs"],
  #|      "excludes": ["*.Designer.cs", "*.g.cs", "*.Generated.cs"]
  #|    },
  #|    "test_colocated": {
  #|      "patterns": []
  #|    },
  #|    "task_doc": {
  #|      "patterns": []
  #|    },
  #|    "package_doc": {
  #|      "names": ["README.md"]
  #|    }
  #|  }
  #|}

///|
fn parse_template(raw : String) -> Template raise DagError {
  let j = @json.parse(raw) catch {
    err => raise ParseError("template JSON: \{@debug.to_repr(err)}")
  }
  @json.from_json(j) catch {
    err => raise ParseError("template decode: \{@debug.to_repr(err)}")
  }
}

///|
pub fn builtin_templates() -> Array[Template] raise DagError {
  [
    parse_template(moonbit_template_json),
    parse_template(typescript_template_json),
    parse_template(dotnet_template_json),
  ]
}

///|
/// Look up a built-in template by name. Returns `None` if unknown.
pub fn find_template_by_name(name : String) -> Template? raise DagError {
  for t in builtin_templates() {
    if t.name == name {
      return Some(t)
    }
  }
  None
}

///|
/// Try each built-in template's `detect` rule; return the first match.
pub fn auto_detect_template(root : String) -> Template? raise DagError {
  for t in builtin_templates() {
    if t.detect_at(root) {
      return Some(t)
    }
  }
  None
}

///|
/// Load a template from disk (JSON file).
pub fn load_template_file(path : String) -> Template raise DagError {
  let raw = @fs.read_file_to_string(path) catch {
    err => raise IoError("read template \{path}: \{@debug.to_repr(err)}")
  }
  parse_template(raw)
}

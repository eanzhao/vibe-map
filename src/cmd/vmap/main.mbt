///|
fn main {
  let argv = @sys.get_cli_args()
  let cmd = build_cli()
  // argv[0] is the program path; argparse wants only the trailing args.
  let args = if argv.length() > 0 { argv[1:] } else { argv[:] }
  let parsed : Result[@argparse.Matches, Error] = try? cmd.parse(argv=args)
  match parsed {
    Err(e) => {
      println("\{e}")
      @sys.exit(2)
    }
    Ok(matches) => {
      let dispatched : Result[Unit, Error] = try? dispatch(matches)
      match dispatched {
        Ok(_) => ()
        Err(e) => {
          println("error: \{e}")
          @sys.exit(1)
        }
      }
    }
  }
}

///|
fn no_render_flag() -> @argparse.FlagArg {
  @argparse.FlagArg::new(
    "no-render",
    long="no-render",
    about="Skip automatic refresh of .vmap/vibe-map.html.",
  )
}

///|
/// Build the `vmap` argparse command tree.
fn build_cli() -> @argparse.Command {
  @argparse.Command::new(
    "vmap",
    about="DAG-based progress visualization for vibe coding.",
    version="0.1.0",
    arg_required_else_help=true,
    subcommand_required=true,
    subcommands=[
      @argparse.Command::new(
        "init",
        about="Create a new vibe-map.json in the current directory.",
        flags=[no_render_flag()],
        options=[
          @argparse.OptionArg::new("name", long="name", about="Project name"),
          @argparse.OptionArg::new(
            "file",
            long="file",
            default_values=[@core.default_path],
            about="Path to the DAG file",
          ),
        ],
      ),
      @argparse.Command::new(
        "add",
        about="Add a goal or task.",
        subcommand_required=true,
        subcommands=[
          @argparse.Command::new(
            "goal",
            about="Add a goal (a user-visible capability).",
            flags=[
              @argparse.FlagArg::new(
                "regression-testable",
                long="regression-testable",
                negatable=true,
                about="Mark as backed by regression tests (or use --no-regression-testable).",
              ),
              @argparse.FlagArg::new(
                "focus",
                long="focus",
                negatable=true,
                about="Mark this goal as a current focus region.",
              ),
              @argparse.FlagArg::new(
                "archived",
                long="archived",
                negatable=true,
                about="Mark this goal as archived.",
              ),
              no_render_flag(),
            ],
            options=[
              @argparse.OptionArg::new("id", long="id", required=true),
              @argparse.OptionArg::new("title", long="title", required=true),
              @argparse.OptionArg::new("description", long="description"),
              @argparse.OptionArg::new(
                "deps",
                long="deps",
                about="Comma-separated goal ids this depends on",
              ),
              @argparse.OptionArg::new(
                "tests",
                long="tests",
                about="Comma-separated test file paths/globs",
              ),
              @argparse.OptionArg::new(
                "docs",
                long="docs",
                about="Comma-separated documentation paths",
              ),
              @argparse.OptionArg::new(
                "closure",
                long="closure",
                about="Region closure stage (default: seed).",
              ),
              @argparse.OptionArg::new(
                "formal",
                long="formal",
                about="Automation/evidence level (default: none or checked).",
              ),
              @argparse.OptionArg::new(
                "product",
                long="product",
                about="Product key from config.products (default: default).",
              ),
              @argparse.OptionArg::new("milestone", long="milestone"),
              @argparse.OptionArg::new("owner", long="owner"),
              @argparse.OptionArg::new(
                "issue-count",
                long="issue-count",
                about="Issue/task count used for node size.",
              ),
              @argparse.OptionArg::new(
                "promoted-at",
                long="promoted-at",
                about="Comma-separated promotion timeline, e.g. scoped=2026-05-01,public=2026-05-10.",
              ),
              @argparse.OptionArg::new(
                "gh-query",
                long="gh-query",
                about="GitHub search query used by drift tooling.",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "task",
            about="Add a task (an implementation task under a goal).",
            flags=[
              @argparse.FlagArg::new(
                "regression-testable",
                long="regression-testable",
                negatable=true,
                about="Mark as backed by regression tests (or use --no-regression-testable).",
              ),
              no_render_flag(),
            ],
            options=[
              @argparse.OptionArg::new("id", long="id", required=true),
              @argparse.OptionArg::new("goal", long="goal", required=true),
              @argparse.OptionArg::new("title", long="title", required=true),
              @argparse.OptionArg::new(
                "deps",
                long="deps",
                about="Comma-separated task ids this depends on",
              ),
              @argparse.OptionArg::new("notes", long="notes"),
              @argparse.OptionArg::new(
                "tests",
                long="tests",
                about="Comma-separated test file paths/globs",
              ),
              @argparse.OptionArg::new(
                "docs",
                long="docs",
                about="Comma-separated documentation paths",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
        ],
      ),
      @argparse.Command::new(
        "update",
        about="Update fields on a goal or task. Flags that are not passed leave the existing value alone.",
        positionals=[@argparse.PositionArg::new("id")],
        flags=[
          @argparse.FlagArg::new(
            "regression-testable",
            long="regression-testable",
            negatable=true,
            about="Mark/unmark as backed by regression tests.",
          ),
          @argparse.FlagArg::new(
            "focus",
            long="focus",
            negatable=true,
            about="Mark/unmark a goal as current focus.",
          ),
          @argparse.FlagArg::new(
            "archived",
            long="archived",
            negatable=true,
            about="Mark/unmark a goal as archived.",
          ),
          no_render_flag(),
        ],
        options=[
          @argparse.OptionArg::new(
            "status",
            long="status",
            about="todo | in-progress | blocked | done",
          ),
          @argparse.OptionArg::new("title", long="title"),
          @argparse.OptionArg::new(
            "description",
            long="description",
            about="Goal description (empty string clears). Goals only.",
          ),
          @argparse.OptionArg::new(
            "notes",
            long="notes",
            about="Task notes (empty string clears). Tasks only.",
          ),
          @argparse.OptionArg::new(
            "tests",
            long="tests",
            about="Replace the test list (comma-separated; empty string clears).",
          ),
          @argparse.OptionArg::new(
            "add-test",
            long="add-test",
            about="Append one or more test paths (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "remove-test",
            long="remove-test",
            about="Remove one or more test paths (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "docs",
            long="docs",
            about="Replace the docs list (comma-separated; empty string clears).",
          ),
          @argparse.OptionArg::new(
            "add-doc",
            long="add-doc",
            about="Append one or more doc paths (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "remove-doc",
            long="remove-doc",
            about="Remove one or more doc paths (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "deps",
            long="deps",
            about="Replace the deps list (comma-separated; empty string clears).",
          ),
          @argparse.OptionArg::new(
            "add-dep",
            long="add-dep",
            about="Append one or more deps (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "remove-dep",
            long="remove-dep",
            about="Remove one or more deps (comma-separated).",
          ),
          @argparse.OptionArg::new(
            "goal",
            long="goal",
            about="Move a task to another goal (task only).",
          ),
          @argparse.OptionArg::new("closure", long="closure"),
          @argparse.OptionArg::new("formal", long="formal"),
          @argparse.OptionArg::new("product", long="product"),
          @argparse.OptionArg::new("milestone", long="milestone"),
          @argparse.OptionArg::new("owner", long="owner"),
          @argparse.OptionArg::new("issue-count", long="issue-count"),
          @argparse.OptionArg::new("promoted-at", long="promoted-at"),
          @argparse.OptionArg::new("gh-query", long="gh-query"),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "rm",
        about="Remove a goal or task.",
        positionals=[@argparse.PositionArg::new("id")],
        flags=[no_render_flag()],
        options=[
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "render",
        about="Render the DAG to a self-contained HTML page.",
        options=[
          @argparse.OptionArg::new(
            "out",
            long="out",
            default_values=["dag.html"],
            about="Output path",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "status",
        about="Show a summary of the DAG. With --json, emit machine-readable output. With --release <key>, restrict to one release lane.",
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit a single JSON document instead of a text summary.",
          ),
        ],
        options=[
          @argparse.OptionArg::new(
            "release",
            long="release",
            about="Filter to goals assigned to this release key.",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "audit",
        about="Check the DAG for missing tests / docs. Exit code 3 on violations.",
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit a single JSON document (`{ ok, violations: [...] }`).",
          ),
        ],
        options=[
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "backfill",
        about="Synthesize goals (per package) and tasks (per source file) from an existing source tree. Merges into the DAG; existing ids are left alone. Auto-detects the template when --template / --template-file is omitted.",
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit the BackfillReport as JSON.",
          ),
          no_render_flag(),
        ],
        options=[
          @argparse.OptionArg::new(
            "src",
            long="src",
            default_values=["."],
            about="Source tree root to scan (default: current dir).",
          ),
          @argparse.OptionArg::new(
            "template",
            long="template",
            about="Built-in template name: moonbit | typescript | dotnet.",
          ),
          @argparse.OptionArg::new(
            "template-file",
            long="template-file",
            about="Path to a JSON template file (overrides --template).",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "import",
        about="Validate a hand-crafted vibe-map.json (ids unique, deps resolve, no cycles) and write it to the target file. Useful for AI bulk-loading.",
        flags=[no_render_flag()],
        options=[
          @argparse.OptionArg::new(
            "in",
            long="in",
            required=true,
            about="Path to the source JSON file.",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "plan",
        about="Scan markdown files and synthesize nodes. --format selects the parser: `checklist` (default) for `- [ ]` items, `tlist` for `## T<N> — title` + `**Status:**` lines.",
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit the PlanReport as JSON.",
          ),
          no_render_flag(),
        ],
        options=[
          @argparse.OptionArg::new(
            "docs",
            long="docs",
            required=true,
            about="Comma-separated list of files or directories to scan.",
          ),
          @argparse.OptionArg::new(
            "format",
            long="format",
            default_values=["checklist"],
            about="Parser to use: checklist | tlist.",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "release",
        about="Manage release lanes (versioned goal groupings).",
        subcommand_required=true,
        subcommands=[
          @argparse.Command::new(
            "add",
            about="Register a new release lane.",
            positionals=[@argparse.PositionArg::new("key")],
            flags=[no_render_flag()],
            options=[
              @argparse.OptionArg::new(
                "label-en",
                long="label-en",
                about="English label.",
              ),
              @argparse.OptionArg::new(
                "label-zh",
                long="label-zh",
                about="Chinese label.",
              ),
              @argparse.OptionArg::new(
                "target",
                long="target",
                about="ISO target date, e.g. 2026-06-15.",
              ),
              @argparse.OptionArg::new(
                "status",
                long="status",
                default_values=["planned"],
                about="planned | open | closed (default: planned).",
              ),
              @argparse.OptionArg::new(
                "notes",
                long="notes",
                about="Free-form notes.",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "list",
            about="List all registered releases with member counts.",
            flags=[
              @argparse.FlagArg::new(
                "json",
                long="json",
                about="Emit a JSON array.",
              ),
            ],
            options=[
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "assign",
            about="Assign one or more goals to a release lane.",
            positionals=[@argparse.PositionArg::new("key")],
            flags=[no_render_flag()],
            options=[
              @argparse.OptionArg::new(
                "goals",
                long="goals",
                required=true,
                about="Comma-separated goal ids to assign.",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "rm",
            about="Remove a release lane. Refuses if goals still point at it unless --force.",
            positionals=[@argparse.PositionArg::new("key")],
            flags=[
              @argparse.FlagArg::new(
                "force",
                long="force",
                about="Clear milestone on member goals before removing.",
              ),
              no_render_flag(),
            ],
            options=[
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "update",
            about="Modify release fields. Status transitions only move forward (planned → open → closed).",
            positionals=[@argparse.PositionArg::new("key")],
            flags=[no_render_flag()],
            options=[
              @argparse.OptionArg::new("label-en", long="label-en"),
              @argparse.OptionArg::new("label-zh", long="label-zh"),
              @argparse.OptionArg::new("target", long="target"),
              @argparse.OptionArg::new(
                "status",
                long="status",
                about="planned | open | closed",
              ),
              @argparse.OptionArg::new("notes", long="notes"),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "unassign",
            about="Clear `milestone` on goals currently pointing at this release. Without --goals, clears all members.",
            positionals=[@argparse.PositionArg::new("key")],
            flags=[no_render_flag()],
            options=[
              @argparse.OptionArg::new(
                "goals",
                long="goals",
                about="Comma-separated goal ids to unassign (default: all members).",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
        ],
      ),
      @argparse.Command::new(
        "show",
        about="Show full details of one goal or task. With --json, emit machine-readable output.",
        positionals=[@argparse.PositionArg::new("id")],
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit the node as a JSON document.",
          ),
        ],
        options=[
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "list",
        about="List goals or tasks with filter flags.",
        subcommand_required=true,
        subcommands=[
          @argparse.Command::new(
            "goals",
            about="List goals. Filter flags compose.",
            flags=[
              @argparse.FlagArg::new(
                "json",
                long="json",
                about="Emit a JSON array.",
              ),
              @argparse.FlagArg::new(
                "focus",
                long="focus",
                about="Only goals with focus=true.",
              ),
              @argparse.FlagArg::new(
                "archived",
                long="archived",
                about="Only goals with archived=true.",
              ),
              @argparse.FlagArg::new(
                "no-tests",
                long="no-tests",
                about="Only goals with empty tests list.",
              ),
              @argparse.FlagArg::new(
                "no-docs",
                long="no-docs",
                about="Only goals with empty docs list.",
              ),
            ],
            options=[
              @argparse.OptionArg::new(
                "release",
                long="release",
                about="Filter to one release key.",
              ),
              @argparse.OptionArg::new(
                "closure",
                long="closure",
                about="Filter to one closure tier.",
              ),
              @argparse.OptionArg::new(
                "owner",
                long="owner",
                about="Filter to one owner.",
              ),
              @argparse.OptionArg::new(
                "product",
                long="product",
                about="Filter to one product key.",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
          @argparse.Command::new(
            "tasks",
            about="List tasks. Filter flags compose.",
            flags=[
              @argparse.FlagArg::new(
                "json",
                long="json",
                about="Emit a JSON array.",
              ),
            ],
            options=[
              @argparse.OptionArg::new(
                "goal",
                long="goal",
                about="Filter to tasks under one goal.",
              ),
              @argparse.OptionArg::new(
                "status",
                long="status",
                about="Filter to one status: todo | in-progress | blocked | done.",
              ),
              @argparse.OptionArg::new("file", long="file", default_values=[
                @core.default_path,
              ]),
            ],
          ),
        ],
      ),
      @argparse.Command::new(
        "deps",
        about="Show dependency graph for a node: --upstream (what it depends on), --downstream (what depends on it), or both (default).",
        positionals=[@argparse.PositionArg::new("id")],
        flags=[
          @argparse.FlagArg::new(
            "upstream",
            long="upstream",
            about="Show transitive upstream only.",
          ),
          @argparse.FlagArg::new(
            "downstream",
            long="downstream",
            about="Show transitive downstream only.",
          ),
          @argparse.FlagArg::new("json", long="json", about="Emit JSON."),
        ],
        options=[
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "rename",
        about="Rename a goal or task id; rewrites all references (deps + task.goal).",
        positionals=[
          @argparse.PositionArg::new("old"),
          @argparse.PositionArg::new("new"),
        ],
        flags=[no_render_flag()],
        options=[
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
    ],
  )
}

///|
fn dispatch(matches : @argparse.Matches) -> Unit raise {
  let (name, sub) = matches.subcommand.unwrap()
  match name {
    "init" => cmd_init(sub)
    "add" => {
      let (sub_name, sub_sub) = sub.subcommand.unwrap()
      match sub_name {
        "goal" => cmd_add_goal(sub_sub)
        "task" => cmd_add_task(sub_sub)
        _ => fail("unknown add subcommand: \{sub_name}")
      }
    }
    "update" => cmd_update(sub)
    "rm" => cmd_rm(sub)
    "render" => cmd_render(sub)
    "status" => cmd_status(sub)
    "audit" => cmd_audit(sub)
    "backfill" => cmd_backfill(sub)
    "import" => cmd_import(sub)
    "plan" => cmd_plan(sub)
    "release" => {
      let (sub_name, sub_sub) = sub.subcommand.unwrap()
      match sub_name {
        "add" => cmd_release_add(sub_sub)
        "list" => cmd_release_list(sub_sub)
        "assign" => cmd_release_assign(sub_sub)
        "rm" => cmd_release_rm(sub_sub)
        "update" => cmd_release_update(sub_sub)
        "unassign" => cmd_release_unassign(sub_sub)
        _ => fail("unknown release subcommand: \{sub_name}")
      }
    }
    "show" => cmd_show(sub)
    "list" => {
      let (sub_name, sub_sub) = sub.subcommand.unwrap()
      match sub_name {
        "goals" => cmd_list_goals(sub_sub)
        "tasks" => cmd_list_tasks(sub_sub)
        _ => fail("unknown list subcommand: \{sub_name}")
      }
    }
    "deps" => cmd_deps(sub)
    "rename" => cmd_rename(sub)
    _ => fail("unknown subcommand: \{name}")
  }
}

///|
/// Read the first value bound to `key`, or `default` if it was omitted.
fn opt(m : @argparse.Matches, key : String, default? : String = "") -> String {
  match m.values.get(key) {
    Some(arr) => if arr.length() > 0 { arr[0] } else { default }
    None => default
  }
}

///|
/// True if the user explicitly passed `--key` on argv (not a default).
fn provided(m : @argparse.Matches, key : String) -> Bool {
  m.sources.get(key) is Some(@argparse.Argv)
}

///|
/// Parse `--deps a,b,c` (or empty string) into an array, dropping blanks.
fn parse_csv(raw : String) -> Array[String] {
  if raw == "" {
    return []
  }
  let out = []
  for part in raw.split(",") {
    let trimmed = part.trim().to_string()
    if trimmed != "" {
      out.push(trimmed)
    }
  }
  out
}

///|
fn parse_int_arg(raw : String, name : String) -> Int raise {
  @strconv.parse_int(raw) catch {
    _ => fail("invalid \{name}: \{raw} (want integer)")
  }
}

///|
fn parse_optional_int_arg(
  raw : String,
  name : String,
  default? : Int = 0,
) -> Int raise {
  if raw == "" {
    default
  } else {
    parse_int_arg(raw, name)
  }
}

///|
fn parse_kv_csv(raw : String, name : String) -> Map[String, String] raise {
  let out : Map[String, String] = {}
  if raw == "" {
    return out
  }
  for part in raw.split(",") {
    let trimmed = part.trim().to_string()
    if trimmed == "" {
      continue
    }
    let pieces = trimmed.split("=").to_array()
    if pieces.length() != 2 {
      fail("invalid \{name} item: \{trimmed} (want key=value)")
    }
    let key = pieces[0].trim().to_string()
    let value = pieces[1].trim().to_string()
    if key == "" || value == "" {
      fail("invalid \{name} item: \{trimmed} (key and value are required)")
    }
    out[key] = value
  }
  out
}

///|
fn parse_status(raw : String) -> @core.Status raise {
  match raw {
    "todo" => @core.Todo
    "in-progress" => @core.InProgress
    "blocked" => @core.Blocked
    "done" => @core.Done
    _ => fail("invalid status: \{raw} (want todo|in-progress|blocked|done)")
  }
}

///|
/// After a mutating command saves the DAG, refresh the rendered HTML at
/// `.vmap/vibe-map.html` so the human-facing view tracks every CLI edit.
/// Honors `--no-render` on commands that declare the flag.
fn maybe_render(dag : @core.Dag, m : @argparse.Matches) -> Unit raise {
  if m.flags.get("no-render").unwrap_or(false) {
    return
  }
  let html = @render.render(dag)
  @core.write_text(@core.default_render_path, html)
}

///|
fn cmd_init(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let name = opt(m, "name", default="untitled")
  let dag = @core.Dag::empty(name)
  @core.save(dag, path)
  maybe_render(dag, m)
  println("created \{path} (project: \{name})")
  if m.flags.get("no-render").unwrap_or(false) {
    println("render skipped (--no-render)")
  } else {
    println("rendered -> \{@core.default_render_path}")
  }
  println("")
  println(
    "tip: add `.vmap/` to .gitignore — the json + rendered html are local working state, not source.",
  )
}

///|
fn cmd_add_goal(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  let title = opt(m, "title")
  let dag = @core.load(path, default_name="untitled")
  dag.add_goal(
    id~,
    title~,
    description=opt(m, "description"),
    deps=parse_csv(opt(m, "deps")),
    closure=opt(m, "closure"),
    formal=opt(m, "formal"),
    product=opt(m, "product"),
    milestone=opt(m, "milestone"),
    owner=opt(m, "owner"),
    issue_count=parse_optional_int_arg(opt(m, "issue-count"), "issue-count"),
    focus=m.flags.get("focus").unwrap_or(false),
    archived=m.flags.get("archived").unwrap_or(false),
    promoted_at=parse_kv_csv(opt(m, "promoted-at"), "promoted-at"),
    gh_query=opt(m, "gh-query"),
    regression_testable=m.flags.get("regression-testable").unwrap_or(false),
    tests=parse_csv(opt(m, "tests")),
    docs=parse_csv(opt(m, "docs")),
  )
  @core.save(dag, path)
  maybe_render(dag, m)
  println("+ goal \{id}: \{title}")
}

///|
fn cmd_add_task(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  let goal = opt(m, "goal")
  let title = opt(m, "title")
  let dag = @core.load(path, default_name="untitled")
  dag.add_task(
    id~,
    goal~,
    title~,
    deps=parse_csv(opt(m, "deps")),
    notes=opt(m, "notes"),
    regression_testable=m.flags.get("regression-testable").unwrap_or(false),
    tests=parse_csv(opt(m, "tests")),
    docs=parse_csv(opt(m, "docs")),
  )
  @core.save(dag, path)
  maybe_render(dag, m)
  println("+ task \{id} under \{goal}: \{title}")
}

///|
fn cmd_update(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  let dag = @core.load(path, default_name="untitled")
  let mut touched = false
  if provided(m, "status") {
    let s = opt(m, "status")
    dag.update_status(id, parse_status(s))
    println("~ \{id} status -> \{s}")
    touched = true
  }
  if provided(m, "title") {
    let t = opt(m, "title")
    dag.update_title(id, t)
    println("~ \{id} title -> \{t}")
    touched = true
  }
  if provided(m, "regression-testable") {
    let v = m.flags.get("regression-testable").unwrap_or(false)
    dag.set_regression_testable(id, v)
    println("~ \{id} regression_testable -> \{v}")
    touched = true
  }
  if provided(m, "tests") {
    let ts = parse_csv(opt(m, "tests"))
    dag.set_tests(id, ts)
    println("~ \{id} tests -> [\{ts.length()}]")
    touched = true
  }
  if provided(m, "docs") {
    let ds = parse_csv(opt(m, "docs"))
    dag.set_docs(id, ds)
    println("~ \{id} docs -> [\{ds.length()}]")
    touched = true
  }
  if provided(m, "closure") {
    let value = opt(m, "closure")
    dag.set_goal_closure(id, value)
    println("~ \{id} closure -> \{value}")
    touched = true
  }
  if provided(m, "formal") {
    let value = opt(m, "formal")
    dag.set_goal_formal(id, value)
    println("~ \{id} formal -> \{value}")
    touched = true
  }
  if provided(m, "product") {
    let value = opt(m, "product")
    dag.set_goal_product(id, value)
    println("~ \{id} product -> \{value}")
    touched = true
  }
  if provided(m, "milestone") {
    let value = opt(m, "milestone")
    dag.set_goal_milestone(id, value)
    println("~ \{id} milestone -> \{value}")
    touched = true
  }
  if provided(m, "owner") {
    let value = opt(m, "owner")
    dag.set_goal_owner(id, value)
    println("~ \{id} owner -> \{value}")
    touched = true
  }
  if provided(m, "issue-count") {
    let value = parse_int_arg(opt(m, "issue-count"), "issue-count")
    dag.set_goal_issue_count(id, value)
    println("~ \{id} issue_count -> \{value}")
    touched = true
  }
  if provided(m, "focus") {
    let value = m.flags.get("focus").unwrap_or(false)
    dag.set_goal_focus(id, value)
    println("~ \{id} focus -> \{value}")
    touched = true
  }
  if provided(m, "archived") {
    let value = m.flags.get("archived").unwrap_or(false)
    dag.set_goal_archived(id, value)
    println("~ \{id} archived -> \{value}")
    touched = true
  }
  if provided(m, "promoted-at") {
    let value = parse_kv_csv(opt(m, "promoted-at"), "promoted-at")
    dag.set_goal_promoted_at(id, value)
    println("~ \{id} promoted_at -> [\{value.length()}]")
    touched = true
  }
  if provided(m, "gh-query") {
    let value = opt(m, "gh-query")
    dag.set_goal_gh_query(id, value)
    println("~ \{id} gh_query -> \{value}")
    touched = true
  }
  if provided(m, "deps") {
    let ds = parse_csv(opt(m, "deps"))
    dag.set_deps(id, ds)
    println("~ \{id} deps -> [\{ds.length()}]")
    touched = true
  }
  if provided(m, "add-dep") {
    for d in parse_csv(opt(m, "add-dep")) {
      dag.add_dep(id, d)
      println("~ \{id} +dep \{d}")
    }
    touched = true
  }
  if provided(m, "remove-dep") {
    for d in parse_csv(opt(m, "remove-dep")) {
      dag.remove_dep(id, d)
      println("~ \{id} -dep \{d}")
    }
    touched = true
  }
  if provided(m, "goal") {
    let value = opt(m, "goal")
    dag.set_task_goal(id, value)
    println("~ \{id} goal -> \{value}")
    touched = true
  }
  if provided(m, "notes") {
    let value = opt(m, "notes")
    dag.set_task_notes(id, value)
    println("~ \{id} notes -> \{value}")
    touched = true
  }
  if provided(m, "description") {
    let value = opt(m, "description")
    dag.set_description(id, value)
    println("~ \{id} description -> \{value}")
    touched = true
  }
  if provided(m, "add-test") {
    for p in parse_csv(opt(m, "add-test")) {
      dag.add_test(id, p)
      println("~ \{id} +test \{p}")
    }
    touched = true
  }
  if provided(m, "remove-test") {
    for p in parse_csv(opt(m, "remove-test")) {
      dag.remove_test(id, p)
      println("~ \{id} -test \{p}")
    }
    touched = true
  }
  if provided(m, "add-doc") {
    for p in parse_csv(opt(m, "add-doc")) {
      dag.add_doc(id, p)
      println("~ \{id} +doc \{p}")
    }
    touched = true
  }
  if provided(m, "remove-doc") {
    for p in parse_csv(opt(m, "remove-doc")) {
      dag.remove_doc(id, p)
      println("~ \{id} -doc \{p}")
    }
    touched = true
  }
  if not(touched) {
    fail("update needs at least one changed field (see `vmap update --help`)")
  }
  @core.save(dag, path)
  maybe_render(dag, m)
}

///|
fn cmd_rm(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  let dag = @core.load(path, default_name="untitled")
  dag.remove(id)
  @core.save(dag, path)
  maybe_render(dag, m)
  println("- \{id}")
}

///|
fn cmd_render(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let out = opt(m, "out", default="dag.html")
  let dag = @core.load(path, default_name="untitled")
  let html = @render.render(dag)
  @core.write_text(out, html)
  println("rendered -> \{out}")
}

///|
fn cmd_status(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let dag = @core.load(path, default_name="untitled")
  let release_filter = opt(m, "release")
  if release_filter != "" && not(dag.has_release(release_filter)) {
    fail("unknown release: \{release_filter}")
  }
  if m.flags.get("json").unwrap_or(false) {
    println(status_json(dag, release=release_filter).stringify(indent=2))
    return
  }
  println("project: \{dag.project.name}")
  if dag.project.description != "" {
    println("  \{dag.project.description}")
  }
  if release_filter != "" {
    println("filter: release \{release_filter}")
  }
  let filtered_goals = if release_filter == "" {
    dag.goals
  } else {
    dag.release_members(release_filter)
  }
  if filtered_goals.length() == 0 {
    if release_filter == "" {
      println("(no goals yet — try `vmap add goal --id m1 --title …`)")
    } else {
      println("(no goals assigned to release \{release_filter} yet)")
    }
    return
  }
  for goal in filtered_goals {
    let (done, total) = dag.progress(goal.id)
    let pct = if total > 0 { done * 100 / total } else { 0 }
    println("• [\{goal.id}] \{goal.title}  (\{done}/\{total} · \{pct}%)")
    for task in dag.tasks_of(goal.id) {
      let mark = match task.status {
        @core.Done => "✓"
        @core.InProgress => "…"
        @core.Blocked => "!"
        @core.Todo => "·"
      }
      println("    \{mark} [\{task.id}] \{task.title}")
    }
  }
}

///|
/// Build the JSON shape returned by `vmap status --json`: the raw DAG plus a
/// `progress` field derived per goal, so AI agents don't have to recompute.
/// When `release` is non-empty, the `dag.goals` (and their `tasks`) are
/// filtered to that lane's members. The DAG is serialized via its derived
/// ToJson so Option field encoding matches the on-disk format exactly.
fn status_json(dag : @core.Dag, release? : String = "") -> Json {
  let view = if release == "" {
    dag
  } else {
    let goals = dag.release_members(release)
    let goal_ids : Map[String, Bool] = {}
    for g in goals {
      goal_ids[g.id] = true
    }
    let tasks = []
    for t in dag.tasks {
      if goal_ids.contains(t.goal) {
        tasks.push(t)
      }
    }
    { ..dag, goals, tasks }
  }
  let progress : Map[String, Json] = {}
  for m in view.goals {
    let (done, total) = dag.progress(m.id)
    progress[m.id] = { "done": done.to_json(), "total": total.to_json() }
  }
  let payload : Map[String, Json] = {
    "dag": view.to_json(),
    "progress": progress.to_json(),
  }
  if release != "" {
    payload["release"] = release.to_json()
  }
  payload.to_json()
}

///|
fn cmd_audit(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let dag = @core.load(path, default_name="untitled")
  let report = dag.audit()
  if m.flags.get("json").unwrap_or(false) {
    println(report.to_json().stringify(indent=2))
  } else if report.ok {
    println("audit: clean (0 violations)")
  } else {
    println("audit: \{report.violations.length()} violation(s)")
    for v in report.violations {
      println("  ! [\{v.node_kind} \{v.node_id}] \{v.kind}: \{v.message}")
    }
  }
  if not(report.ok) {
    @sys.exit(3)
  }
}

///|
fn cmd_import(m : @argparse.Matches) -> Unit raise {
  let in_path = opt(m, "in")
  let target = opt(m, "file", default=@core.default_path)
  let dag = @core.import_dag(in_path)
  @core.save(dag, target)
  maybe_render(dag, m)
  println(
    "imported \{dag.goals.length()} goal(s), \{dag.tasks.length()} task(s) -> \{target}",
  )
}

///|
fn cmd_backfill(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let src = opt(m, "src", default="src")
  let template_name = opt(m, "template")
  let template_file = opt(m, "template-file")
  let template = if template_file != "" {
    @core.load_template_file(template_file)
  } else if template_name != "" {
    match @core.find_template_by_name(template_name) {
      Some(t) => t
      None =>
        fail(
          "unknown template: \{template_name} (built-in names: moonbit | typescript | dotnet)",
        )
    }
  } else {
    match @core.auto_detect_template(src) {
      Some(t) => t
      None =>
        fail(
          "could not auto-detect a template at \{src}; pass --template <name> or --template-file <path>",
        )
    }
  }
  let dag = @core.load(path, default_name="untitled")
  let report = dag.backfill(src, template)
  @core.save(dag, path)
  maybe_render(dag, m)
  if m.flags.get("json").unwrap_or(false) {
    println(report.to_json().stringify(indent=2))
  } else {
    println(
      "backfill[\{report.template}] from \{src}: +\{report.added_goals.length()} goal(s), +\{report.added_tasks.length()} task(s)",
    )
    if report.skipped_goals.length() > 0 || report.skipped_tasks.length() > 0 {
      println(
        "  (skipped \{report.skipped_goals.length()} goal(s) and \{report.skipped_tasks.length()} task(s) that already existed)",
      )
    }
  }
}

///|
fn cmd_plan(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let docs = parse_csv(opt(m, "docs"))
  let format = opt(m, "format", default="checklist")
  if docs.length() == 0 {
    fail("plan needs --docs <path1,path2,...>")
  }
  let dag = @core.load(path, default_name="untitled")
  let report = dag.plan_from_docs(docs, format~)
  @core.save(dag, path)
  maybe_render(dag, m)
  if m.flags.get("json").unwrap_or(false) {
    println(report.to_json().stringify(indent=2))
  } else {
    println(
      "plan from \{docs.length()} path(s): +\{report.added_goals.length()} goal(s), +\{report.added_tasks.length()} task(s)",
    )
    if report.skipped_goals.length() > 0 || report.skipped_tasks.length() > 0 {
      println(
        "  (skipped \{report.skipped_goals.length()} goal(s) and \{report.skipped_tasks.length()} task(s) that already existed)",
      )
    }
  }
}

///|
fn cmd_release_add(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let key = opt(m, "key")
  if key == "" {
    fail(
      "release add needs a positional release key, e.g. `vmap release add 0.4.0`",
    )
  }
  let label_en = opt(m, "label-en")
  let label_zh = opt(m, "label-zh")
  let target = opt(m, "target")
  let status = opt(m, "status", default="planned")
  let notes = opt(m, "notes")
  let dag = @core.load(path, default_name="untitled")
  dag.add_release(key~, label_en~, label_zh~, target~, status~, notes~)
  @core.save(dag, path)
  maybe_render(dag, m)
  let label_suffix = if label_en != "" { " — " + label_en } else { "" }
  println("+ release \{key} [\{status}]\{label_suffix}")
}

///|
fn cmd_release_list(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let dag = @core.load(path, default_name="untitled")
  let releases = match dag.releases {
    Some(arr) => arr
    None => []
  }
  if m.flags.get("json").unwrap_or(false) {
    let out = []
    for r in releases {
      let members = dag.release_member_ids(r.key)
      let entry : Map[String, Json] = {
        "key": r.key.to_json(),
        "label": r.label.to_json(),
        "status": r.status.to_json(),
        "members": members.to_json(),
      }
      match r.target {
        Some(t) => entry["target"] = t.to_json()
        None => ()
      }
      match r.notes {
        Some(n) => entry["notes"] = n.to_json()
        None => ()
      }
      match r.closed_at {
        Some(c) => entry["closed_at"] = c.to_json()
        None => ()
      }
      out.push(entry)
    }
    println(out.to_json().stringify(indent=2))
    return
  }
  if releases.length() == 0 {
    println(
      "(no releases yet — try `vmap release add <key> --label-en … --label-zh …`)",
    )
    return
  }
  for r in releases {
    let members = dag.release_member_ids(r.key)
    let target_str = match r.target {
      Some(t) => " · target \{t}"
      None => ""
    }
    println(
      "• \{r.key} [\{r.status}]\{target_str}  (\{members.length()} goal(s))",
    )
    if r.label.en != "" || r.label.zh != "" {
      println("    \{r.label.en} / \{r.label.zh}")
    }
  }
}

///|
fn cmd_release_assign(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let key = opt(m, "key")
  if key == "" {
    fail(
      "release assign needs a positional release key, e.g. `vmap release assign 0.4.0 --goals g1,g2`",
    )
  }
  let goal_ids = parse_csv(opt(m, "goals"))
  if goal_ids.length() == 0 {
    fail("release assign needs --goals <id1,id2,...>")
  }
  let dag = @core.load(path, default_name="untitled")
  for gid in goal_ids {
    dag.assign_release(gid, key)
    println("~ \{gid} -> release \{key}")
  }
  @core.save(dag, path)
  maybe_render(dag, m)
}

///|
fn cmd_release_rm(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let key = opt(m, "key")
  if key == "" {
    fail("release rm needs a positional release key")
  }
  let force = m.flags.get("force").unwrap_or(false)
  let dag = @core.load(path, default_name="untitled")
  dag.remove_release(key, force~)
  @core.save(dag, path)
  maybe_render(dag, m)
  println("- release \{key}")
}

///|
fn cmd_release_update(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let key = opt(m, "key")
  if key == "" {
    fail("release update needs a positional release key")
  }
  let dag = @core.load(path, default_name="untitled")
  let mut touched = false
  let label_en = if provided(m, "label-en") {
    touched = true
    opt(m, "label-en")
  } else {
    ""
  }
  let label_zh = if provided(m, "label-zh") {
    touched = true
    opt(m, "label-zh")
  } else {
    ""
  }
  let target = if provided(m, "target") {
    touched = true
    opt(m, "target")
  } else {
    ""
  }
  let status = if provided(m, "status") {
    touched = true
    opt(m, "status")
  } else {
    ""
  }
  let notes = if provided(m, "notes") {
    touched = true
    opt(m, "notes")
  } else {
    ""
  }
  if not(touched) {
    fail(
      "release update needs at least one field (--label-en/--label-zh/--target/--status/--notes)",
    )
  }
  dag.update_release(key, label_en~, label_zh~, target~, status~, notes~)
  @core.save(dag, path)
  maybe_render(dag, m)
  println("~ release \{key} updated")
}

///|
fn cmd_release_unassign(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let key = opt(m, "key")
  if key == "" {
    fail("release unassign needs a positional release key")
  }
  let only = parse_csv(opt(m, "goals"))
  let dag = @core.load(path, default_name="untitled")
  let affected = if only.length() == 0 {
    dag.release_member_ids(key)
  } else {
    only
  }
  dag.unassign_release(key, only)
  @core.save(dag, path)
  maybe_render(dag, m)
  for gid in affected {
    println("~ \{gid} -release \{key}")
  }
}

///|
fn goal_to_json(g : @core.Goal) -> Json {
  g.to_json()
}

///|
fn task_to_json(t : @core.Task) -> Json {
  t.to_json()
}

///|
fn cmd_show(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  if id == "" {
    fail("show needs a positional id")
  }
  let dag = @core.load(path, default_name="untitled")
  let json_mode = m.flags.get("json").unwrap_or(false)
  match dag.find_goal(id) {
    Some((_, g)) => {
      if json_mode {
        let payload : Map[String, Json] = {
          "kind": "goal".to_json(),
          "goal": goal_to_json(g),
          "tasks": dag.tasks_of(id).to_json(),
          "upstream": dag.upstream(id).to_json(),
          "downstream": dag.downstream(id).to_json(),
        }
        let (done, total) = dag.progress(id)
        payload["progress"] = {
          "done": done.to_json(),
          "total": total.to_json(),
        }
        println(payload.to_json().stringify(indent=2))
        return
      }
      let (done, total) = dag.progress(id)
      println("goal \{id}: \{g.title}  (\{done}/\{total} tasks done)")
      if g.description != "" {
        println("  \{g.description}")
      }
      let closure_s = g.closure.unwrap_or("?")
      let formal_s = g.formal.unwrap_or("?")
      let product_s = g.product.unwrap_or("?")
      println("  closure=\{closure_s} formal=\{formal_s} product=\{product_s}")
      let milestone_s = g.milestone.unwrap_or("(none)")
      let owner_s = g.owner.unwrap_or("(none)")
      let issue_count = g.issue_count.unwrap_or(0)
      println(
        "  milestone=\{milestone_s}  owner=\{owner_s}  issue_count=\{issue_count}",
      )
      let focus_v = g.focus.unwrap_or(false)
      let archived_v = g.archived.unwrap_or(false)
      println(
        "  focus=\{focus_v}  archived=\{archived_v}  regression_testable=\{g.regression_testable}",
      )
      if g.deps.length() > 0 {
        println("  deps: \{g.deps}")
      }
      if g.tests.length() > 0 {
        println("  tests: \{g.tests}")
      }
      if g.docs.length() > 0 {
        println("  docs: \{g.docs}")
      }
      let up = dag.upstream(id)
      if up.length() > 0 {
        println("  upstream (transitive): \{up}")
      }
      let down = dag.downstream(id)
      if down.length() > 0 {
        println("  downstream (transitive): \{down}")
      }
      let tasks = dag.tasks_of(id)
      if tasks.length() > 0 {
        println("  tasks:")
        for t in tasks {
          let mark = match t.status {
            @core.Done => "✓"
            @core.InProgress => "…"
            @core.Blocked => "!"
            @core.Todo => "·"
          }
          println("    \{mark} [\{t.id}] \{t.title}")
        }
      }
      return
    }
    None => ()
  }
  match dag.find_task(id) {
    Some((_, t)) => {
      if json_mode {
        let payload : Map[String, Json] = {
          "kind": "task".to_json(),
          "task": task_to_json(t),
          "upstream": dag.upstream(id).to_json(),
          "downstream": dag.downstream(id).to_json(),
        }
        println(payload.to_json().stringify(indent=2))
        return
      }
      let mark = match t.status {
        @core.Done => "✓"
        @core.InProgress => "…"
        @core.Blocked => "!"
        @core.Todo => "·"
      }
      println("task \{id}: \{mark} \{t.title}  (under \{t.goal})")
      if t.notes != "" {
        println("  notes: \{t.notes}")
      }
      println("  regression_testable=\{t.regression_testable}")
      if t.deps.length() > 0 {
        println("  deps: \{t.deps}")
      }
      if t.tests.length() > 0 {
        println("  tests: \{t.tests}")
      }
      if t.docs.length() > 0 {
        println("  docs: \{t.docs}")
      }
      let up = dag.upstream(id)
      if up.length() > 0 {
        println("  upstream (transitive): \{up}")
      }
      let down = dag.downstream(id)
      if down.length() > 0 {
        println("  downstream (transitive): \{down}")
      }
    }
    None => fail("unknown id: \{id}")
  }
}

///|
fn cmd_list_goals(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let dag = @core.load(path, default_name="untitled")
  let release_f = opt(m, "release")
  let closure_f = opt(m, "closure")
  let owner_f = opt(m, "owner")
  let product_f = opt(m, "product")
  let only_focus = m.flags.get("focus").unwrap_or(false)
  let only_archived = m.flags.get("archived").unwrap_or(false)
  let only_no_tests = m.flags.get("no-tests").unwrap_or(false)
  let only_no_docs = m.flags.get("no-docs").unwrap_or(false)
  if release_f != "" && not(dag.has_release(release_f)) {
    fail("unknown release: \{release_f}")
  }
  let filtered : Array[@core.Goal] = []
  for g in dag.goals {
    if release_f != "" {
      match g.milestone {
        Some(m2) => if m2 != release_f { continue }
        None => continue
      }
    }
    if closure_f != "" {
      match g.closure {
        Some(c) => if c != closure_f { continue }
        None => continue
      }
    }
    if owner_f != "" {
      match g.owner {
        Some(o) => if o != owner_f { continue }
        None => continue
      }
    }
    if product_f != "" {
      match g.product {
        Some(p) => if p != product_f { continue }
        None => continue
      }
    }
    if only_focus && not(g.focus.unwrap_or(false)) {
      continue
    }
    if only_archived && not(g.archived.unwrap_or(false)) {
      continue
    }
    if only_no_tests && g.tests.length() > 0 {
      continue
    }
    if only_no_docs && g.docs.length() > 0 {
      continue
    }
    filtered.push(g)
  }
  if m.flags.get("json").unwrap_or(false) {
    let out = []
    for g in filtered {
      out.push(goal_to_json(g))
    }
    println(out.to_json().stringify(indent=2))
    return
  }
  if filtered.length() == 0 {
    println("(0 goals matched)")
    return
  }
  for g in filtered {
    let (done, total) = dag.progress(g.id)
    let pct = if total > 0 { done * 100 / total } else { 0 }
    let closure_s = g.closure.unwrap_or("?")
    let milestone_s = g.milestone.unwrap_or("-")
    let owner_s = g.owner.unwrap_or("-")
    println(
      "• [\{g.id}] \{g.title}  closure=\{closure_s} milestone=\{milestone_s} owner=\{owner_s}  (\{done}/\{total} · \{pct}%)",
    )
  }
}

///|
fn cmd_list_tasks(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let dag = @core.load(path, default_name="untitled")
  let goal_f = opt(m, "goal")
  let status_f = opt(m, "status")
  if goal_f != "" && not(dag.has_goal(goal_f)) {
    fail("unknown goal: \{goal_f}")
  }
  let status_filter : @core.Status? = if status_f == "" {
    None
  } else {
    Some(parse_status(status_f))
  }
  let filtered : Array[@core.Task] = []
  for t in dag.tasks {
    if goal_f != "" && t.goal != goal_f {
      continue
    }
    match status_filter {
      Some(s) => if t.status != s { continue }
      None => ()
    }
    filtered.push(t)
  }
  if m.flags.get("json").unwrap_or(false) {
    let out = []
    for t in filtered {
      out.push(task_to_json(t))
    }
    println(out.to_json().stringify(indent=2))
    return
  }
  if filtered.length() == 0 {
    println("(0 tasks matched)")
    return
  }
  for t in filtered {
    let mark = match t.status {
      @core.Done => "✓"
      @core.InProgress => "…"
      @core.Blocked => "!"
      @core.Todo => "·"
    }
    println("\{mark} [\{t.id}] \{t.title}  (under \{t.goal})")
  }
}

///|
fn cmd_deps(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  if id == "" {
    fail("deps needs a positional id")
  }
  let dag = @core.load(path, default_name="untitled")
  if dag.kind_of(id) is None {
    fail("unknown id: \{id}")
  }
  let want_up = m.flags.get("upstream").unwrap_or(false)
  let want_down = m.flags.get("downstream").unwrap_or(false)
  let show_both = not(want_up) && not(want_down)
  let up = if want_up || show_both { dag.upstream(id) } else { [] }
  let down = if want_down || show_both { dag.downstream(id) } else { [] }
  if m.flags.get("json").unwrap_or(false) {
    let payload : Map[String, Json] = {
      "id": id.to_json(),
      "upstream": up.to_json(),
      "downstream": down.to_json(),
    }
    println(payload.to_json().stringify(indent=2))
    return
  }
  println("id: \{id}")
  if want_up || show_both {
    println("upstream (transitive, \{up.length()}):")
    for x in up {
      println("  ← \{x}")
    }
  }
  if want_down || show_both {
    println("downstream (transitive, \{down.length()}):")
    for x in down {
      println("  → \{x}")
    }
  }
}

///|
fn cmd_rename(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let old_id = opt(m, "old")
  let new_id = opt(m, "new")
  if old_id == "" || new_id == "" {
    fail("rename needs two positionals: <old> <new>")
  }
  let dag = @core.load(path, default_name="untitled")
  dag.rename(old_id, new_id)
  @core.save(dag, path)
  maybe_render(dag, m)
  println("~ \{old_id} -> \{new_id}")
}

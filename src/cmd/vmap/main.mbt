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
        ],
        options=[
          @argparse.OptionArg::new(
            "status",
            long="status",
            about="todo | in-progress | blocked | done",
          ),
          @argparse.OptionArg::new("title", long="title"),
          @argparse.OptionArg::new(
            "tests",
            long="tests",
            about="Replace the test list (comma-separated; empty string clears).",
          ),
          @argparse.OptionArg::new(
            "docs",
            long="docs",
            about="Replace the docs list (comma-separated; empty string clears).",
          ),
          @argparse.OptionArg::new("file", long="file", default_values=[
            @core.default_path,
          ]),
        ],
      ),
      @argparse.Command::new(
        "rm",
        about="Remove a goal or task.",
        positionals=[@argparse.PositionArg::new("id")],
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
        about="Show a summary of the DAG. With --json, emit machine-readable output.",
        flags=[
          @argparse.FlagArg::new(
            "json",
            long="json",
            about="Emit a single JSON document instead of a text summary.",
          ),
        ],
        options=[
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
fn cmd_init(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let name = opt(m, "name", default="untitled")
  let dag = @core.Dag::empty(name)
  @core.save(dag, path)
  println("created \{path} (project: \{name})")
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
    regression_testable=m.flags.get("regression-testable").unwrap_or(false),
    tests=parse_csv(opt(m, "tests")),
    docs=parse_csv(opt(m, "docs")),
  )
  @core.save(dag, path)
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
  if not(touched) {
    fail(
      "update needs at least one of --status / --title / --regression-testable / --tests / --docs",
    )
  }
  @core.save(dag, path)
}

///|
fn cmd_rm(m : @argparse.Matches) -> Unit raise {
  let path = opt(m, "file", default=@core.default_path)
  let id = opt(m, "id")
  let dag = @core.load(path, default_name="untitled")
  dag.remove(id)
  @core.save(dag, path)
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
  if m.flags.get("json").unwrap_or(false) {
    println(status_json(dag).stringify(indent=2))
    return
  }
  println("project: \{dag.project.name}")
  if dag.project.description != "" {
    println("  \{dag.project.description}")
  }
  if dag.goals.length() == 0 {
    println("(no goals yet — try `vmap add goal --id m1 --title …`)")
    return
  }
  for goal in dag.goals {
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
fn status_json(dag : @core.Dag) -> Json {
  let progress : Map[String, Json] = {}
  for m in dag.goals {
    let (done, total) = dag.progress(m.id)
    progress[m.id] = { "done": done.to_json(), "total": total.to_json() }
  }
  { "dag": dag.to_json(), "progress": progress.to_json() }
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

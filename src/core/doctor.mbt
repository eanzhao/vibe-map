///|
/// `vmap doctor` — aggregate health warnings for the DAG. Designed to be
/// noisy when the DAG looks suspicious (sparse, imbalanced, orphaned) and
/// silent when it doesn't. The CLI exits with status 0 either way; this is
/// advice, not enforcement.
pub(all) struct DoctorReport {
  ok : Bool
  warnings : Array[DoctorWarning]
  /// Counts the doctor used to make its decisions, so users can see the
  /// inputs without re-running the scan.
  stats : DoctorStats
} derive(Show, ToJson)

///|
pub(all) struct DoctorWarning {
  /// One of `density` | `lane_imbalance` | `orphan_goal`
  /// | `codebase_mismatch`.
  kind : String
  /// `info` (FYI) | `warn` (probably wrong).
  severity : String
  message : String
  /// Goal id this warning attaches to, when applicable.
  goal_id : String?
  /// Extra structured fields keyed by name. Always strings so the JSON
  /// stays simple — numeric values get stringified.
  details : Map[String, String]
} derive(Show, ToJson)

///|
pub(all) struct DoctorStats {
  goals : Int
  tasks : Int
  releases : Int
  /// Goals that have any downstream dependent (used by the orphan check).
  goals_with_downstream : Int
  /// Markdown files counted under the scan root.
  markdown_files : Int
  /// Top-level dirs counted under the source root.
  code_dirs : Int
  /// goals / max(1, markdown_files / 5 + code_dirs). Hand-tuned so a DAG
  /// with 30 goals against 200 docs and 12 code dirs lands near 0.6.
  density_ratio : Double
} derive(Show, ToJson)

///|
/// Run all doctor checks. Empty `scan_root` falls back to `.`, empty
/// `src_root` to auto-detect. Pass an explicit missing/empty directory when
/// a caller wants filesystem-based checks to see no docs or source dirs.
pub fn Dag::doctor(
  self : Dag,
  scan_root : String,
  src_root : String,
) -> DoctorReport raise DagError {
  let effective_scan = if scan_root == "" { "." } else { scan_root }
  let effective_src = if src_root != "" {
    src_root
  } else {
    detect_default_src()
  }
  let md_files : Array[String] = []
  collect_md_files(effective_scan, md_files)
  let code_dirs = if effective_src != "" && @fs.path_exists(effective_src) {
    scan_top_dirs(effective_src)
  } else {
    []
  }
  let warnings : Array[DoctorWarning] = []
  let goals_count = self.goals.length()
  let tasks_count = self.tasks.length()
  let releases_count = match self.releases {
    Some(arr) => arr.length()
    None => 0
  }
  let downstream_index = build_downstream_count(self)
  let mut goals_with_down = 0
  for g in self.goals {
    if downstream_index.get(g.id).unwrap_or(0) > 0 {
      goals_with_down = goals_with_down + 1
    }
  }
  let docs_weighted = md_files.length() / 5
  let denom = if docs_weighted + code_dirs.length() <= 0 {
    1
  } else {
    docs_weighted + code_dirs.length()
  }
  let ratio = if goals_count == 0 {
    0.0
  } else {
    goals_count.to_double() / denom.to_double()
  }

  // density: too sparse — likely missed swathes of capabilities.
  if goals_count > 0 && ratio < 0.3 && denom > 5 {
    let details : Map[String, String] = {
      "goals": goals_count.to_string(),
      "markdown_files": md_files.length().to_string(),
      "code_dirs": code_dirs.length().to_string(),
      "ratio": format_pct(ratio),
    }
    warnings.push({
      kind: "density",
      severity: "warn",
      message: "DAG is sparse for project size: \{goals_count} goal(s) against \{md_files.length()} markdown file(s) + \{code_dirs.length()} top-level code dir(s). You may have missed major capabilities — try `vmap coverage` to see which docs / src dirs aren't referenced anywhere.",
      goal_id: None,
      details,
    })
  } else if goals_count > 0 && ratio > 3.0 && denom > 3 {
    let details : Map[String, String] = {
      "goals": goals_count.to_string(),
      "markdown_files": md_files.length().to_string(),
      "code_dirs": code_dirs.length().to_string(),
      "ratio": format_pct(ratio),
    }
    warnings.push({
      kind: "density",
      severity: "info",
      message: "DAG may be over-decomposed: \{goals_count} goal(s) for a relatively small project. Consider merging adjacent goals — `vmap status` to eyeball them.",
      goal_id: None,
      details,
    })
  }

  // lane imbalance: one release dwarfs the others.
  detect_lane_imbalance(self, warnings)

  // orphan goals: no downstream + no member of closed release.
  detect_orphan_goals(self, downstream_index, warnings)

  // codebase mismatch: src/<dir> exists but no goal/task id contains it.
  detect_codebase_mismatch(self, code_dirs, warnings)

  let stats : DoctorStats = {
    goals: goals_count,
    tasks: tasks_count,
    releases: releases_count,
    goals_with_downstream: goals_with_down,
    markdown_files: md_files.length(),
    code_dirs: code_dirs.length(),
    density_ratio: ratio,
  }
  { ok: warnings.length() == 0, warnings, stats }
}

///|
/// Map of `id -> count of nodes that depend on it`. Linear once, used by
/// the orphan check.
fn build_downstream_count(dag : Dag) -> Map[String, Int] {
  let m : Map[String, Int] = {}
  for g in dag.goals {
    for d in g.deps {
      let prev = m.get(d).unwrap_or(0)
      m[d] = prev + 1
    }
  }
  for t in dag.tasks {
    for d in t.deps {
      let prev = m.get(d).unwrap_or(0)
      m[d] = prev + 1
    }
  }
  m
}

///|
/// Warn when one release holds more than 2.5x the average of the other
/// active release lanes. Closed releases are excluded — historical lanes are
/// allowed to be big.
fn detect_lane_imbalance(dag : Dag, warnings : Array[DoctorWarning]) -> Unit {
  let releases = match dag.releases {
    Some(arr) => arr
    None => return
  }
  if releases.length() < 2 {
    return
  }
  let counts : Map[String, Int] = {}
  for r in releases {
    counts[r.key] = 0
  }
  for g in dag.goals {
    match g.milestone {
      Some(k) =>
        match counts.get(k) {
          Some(c) => counts[k] = c + 1
          None => ()
        }
      None => ()
    }
  }
  let active : Array[(String, Int)] = []
  let mut total = 0
  for r in releases {
    if r.status == "closed" {
      continue
    }
    let c = counts.get(r.key).unwrap_or(0)
    active.push((r.key, c))
    total = total + c
  }
  if active.length() < 2 || total == 0 {
    return
  }
  for entry in active {
    let (key, c) = entry
    let other_count = active.length() - 1
    let other_total = total - c
    let other_avg = other_total.to_double() / other_count.to_double()
    let threshold = if other_avg < 1.0 { 2.5 } else { other_avg * 2.5 }
    if c.to_double() > threshold {
      let details : Map[String, String] = {
        "release": key,
        "goals": c.to_string(),
        "avg_other_active": format_pct(other_avg),
      }
      warnings.push({
        kind: "lane_imbalance",
        severity: "warn",
        message: "release \{key} carries \{c} goal(s) vs avg \{format_pct(other_avg)} across other open/planned lanes — consider splitting into two releases (e.g. \{key}.a / \{key}.b) so scope stays committable.",
        goal_id: None,
        details,
      })
    }
  }
}

///|
/// Flag goals with no downstream dependent that are also not assigned to a
/// closed release. Open / planned / unassigned goals with no downstream are
/// the typical "you forgot to wire this in" signal.
fn detect_orphan_goals(
  dag : Dag,
  downstream_index : Map[String, Int],
  warnings : Array[DoctorWarning],
) -> Unit {
  let closed_releases : Map[String, Bool] = {}
  match dag.releases {
    Some(arr) =>
      for r in arr {
        if r.status == "closed" {
          closed_releases[r.key] = true
        }
      }
    None => ()
  }
  for g in dag.goals {
    if g.archived.unwrap_or(false) {
      continue
    }
    if downstream_index.get(g.id).unwrap_or(0) > 0 {
      continue
    }
    match g.milestone {
      Some(m) => if closed_releases.contains(m) { continue }
      None => ()
    }
    let details : Map[String, String] = {
      "goal": g.id,
      "milestone": g.milestone.unwrap_or("(none)"),
      "closure": g.closure.unwrap_or("(none)"),
    }
    warnings.push({
      kind: "orphan_goal",
      severity: "info",
      message: "goal \{g.id} has no downstream dependent and isn't in a closed release. If this is a leaf capability, fine; if something else should depend on it, wire `--add-dep \{g.id}`.",
      goal_id: Some(g.id),
      details,
    })
  }
}

///|
/// Compare top-level src/<dir> entries against goal/task identifiers and
/// titles. A directory whose basename never appears as a substring in any
/// id/title is a likely "you have code for X but no goal-X" mismatch.
fn detect_codebase_mismatch(
  dag : Dag,
  code_dirs : Array[String],
  warnings : Array[DoctorWarning],
) -> Unit {
  if code_dirs.length() == 0 {
    return
  }
  let needles : Array[String] = []
  for g in dag.goals {
    needles.push(lower_str(g.id))
    needles.push(lower_str(g.title))
  }
  for t in dag.tasks {
    needles.push(lower_str(t.id))
    needles.push(lower_str(t.title))
  }
  for d in code_dirs {
    let base = lower_str(basename_of_path(d))
    if base == "" {
      continue
    }
    if any_contains(needles, base) {
      continue
    }
    let suggested = "goal-" + base
    let details : Map[String, String] = {
      "dir": d,
      "suggested_goal_id": suggested,
    }
    warnings.push({
      kind: "codebase_mismatch",
      severity: "warn",
      message: "codebase has \{d} but no goal/task id or title references \"\{base}\". Either add `\{suggested}` to the DAG or archive the dir if it's vestigial.",
      goal_id: None,
      details,
    })
  }
}

///|
/// Two-decimal stringification for a Double without pulling in printf.
fn format_pct(value : Double) -> String {
  let scaled = (value * 100.0).to_int()
  let whole = scaled / 100
  let frac = scaled % 100
  let frac_str = if frac < 10 { "0\{frac}" } else { frac.to_string() }
  "\{whole}.\{frac_str}"
}

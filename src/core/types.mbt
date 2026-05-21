///|
/// Status of a task. Goal status is derived from its tasks.
pub(all) enum Status {
  Todo
  InProgress
  Blocked
  Done
} derive(Eq, Debug)

///|
pub impl Show for Status with output(self, logger) {
  logger.write_string(@debug.to_repr(self).to_string())
}

///|
pub impl ToJson for Status with to_json(self) {
  match self {
    Todo => "todo"
    InProgress => "in-progress"
    Blocked => "blocked"
    Done => "done"
  }
}

///|
pub impl @json.FromJson for Status with from_json(j, path) {
  match j {
    String("todo") => Todo
    String("in-progress") => InProgress
    String("blocked") => Blocked
    String("done") => Done
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected one of \"todo\" | \"in-progress\" | \"blocked\" | \"done\"",
        ),
      )
  }
}

///|
pub(all) struct Project {
  name : String
  description : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct LocalizedText {
  en : String
  zh : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct ProductConfig {
  key : String
  label : LocalizedText
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct ClosureTierConfig {
  key : String
  label : LocalizedText
  color : String
  trigger : LocalizedText
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct FormalLevelConfig {
  key : String
  shape : String?
  label : LocalizedText
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct FocusQuarterConfig {
  label : LocalizedText
  border_color : String
  border_width : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct ArchiveRuleConfig {
  after_mature_days : Int
  opacity : Double
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct UiConfig {
  title : LocalizedText
  default_lang : String
} derive(Eq, Debug, ToJson, FromJson)

///|
/// A release lane (e.g. "0.4.0") groups goals around a shipped version.
/// `status` flows planned → open → closed monotonically.
pub(all) struct ReleaseConfig {
  key : String
  label : LocalizedText
  target : String?
  status : String
  notes : String?
  closed_at : String?
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct VmapConfig {
  version : Int
  products : Array[ProductConfig]
  closure_tiers : Array[ClosureTierConfig]
  formal_levels : Array[FormalLevelConfig]
  focus_quarter : FocusQuarterConfig
  archive_rule : ArchiveRuleConfig
  ui : UiConfig
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn default_config() -> VmapConfig {
  {
    version: 1,
    products: [{ key: "default", label: { en: "Default", zh: "默认" } }],
    closure_tiers: [
      {
        key: "seed",
        label: { en: "Proposed", zh: "提出" },
        color: "#94a3b8",
        trigger: {
          en: "issue / discussion created",
          zh: "issue / discussion 已创建",
        },
      },
      {
        key: "obligation",
        label: { en: "Claimed", zh: "接手" },
        color: "#38bdf8",
        trigger: { en: "assignee set", zh: "assignee 字段非空" },
      },
      {
        key: "scoped",
        label: { en: "Designed", zh: "设计完" },
        color: "#a78bfa",
        trigger: {
          en: "RFC / ADR / design doc merged",
          zh: "RFC / ADR / 设计 doc merged",
        },
      },
      {
        key: "public",
        label: { en: "Committed", zh: "已承诺" },
        color: "#fdba74",
        trigger: {
          en: "release notes / changelog / external commitment",
          zh: "release notes / changelog / 对外承诺已发",
        },
      },
      {
        key: "bridged",
        label: { en: "Integrated", zh: "已集成" },
        color: "#2dd4bf",
        trigger: {
          en: "upstream/downstream closed + smoke passed",
          zh: "上下游 issue closed + smoke 通过",
        },
      },
      {
        key: "mature",
        label: { en: "Operating", zh: "运行中" },
        color: "#34d399",
        trigger: { en: "30 days incident-free", zh: "30 天无 incident" },
      },
    ],
    formal_levels: [
      {
        key: "none",
        shape: None,
        label: { en: "No automation", zh: "无自动化" },
      },
      {
        key: "sop",
        shape: None,
        label: { en: "Has SOP / runbook", zh: "有 SOP / runbook" },
      },
      {
        key: "checked",
        shape: None,
        label: { en: "Has CI / tests", zh: "有自动化测试 / CI" },
      },
      {
        key: "audited",
        shape: None,
        label: { en: "Has monitoring + SLO", zh: "有监控 / 告警 / SLO" },
      },
    ],
    focus_quarter: {
      label: { en: "Current focus", zh: "当前焦点" },
      border_color: "#f43f5e",
      border_width: 3,
    },
    archive_rule: { after_mature_days: 30, opacity: 0.35 },
    ui: {
      title: { en: "Vibe Region Map", zh: "Vibe Region Map" },
      default_lang: "zh",
    },
  }
}

///|
pub(all) struct Goal {
  id : String
  title : String
  description : String
  deps : Array[String]
  /// Monotonic closure stage, usually seed → obligation → scoped → public →
  /// bridged → mature.
  closure : String?
  /// Automation / evidence level, shown in node details.
  formal : String?
  /// Product key from config.products.
  product : String?
  /// Company milestone or release lane.
  milestone : String?
  /// GitHub username or owning team.
  owner : String?
  /// Region issue/task count, rendered as node size.
  issue_count : Int?
  /// Current company focus, rendered with a strong border.
  focus : Bool?
  /// Archived mature regions render dimmed.
  archived : Bool?
  /// Promotion timeline keyed by closure stage.
  promoted_at : Map[String, String]?
  /// GitHub search query used by drift tooling.
  gh_query : String?
  /// True if this goal maps to shippable code that should be guarded by
  /// a regression test (set by `vmap backfill`; manually overridable).
  regression_testable : Bool
  /// Test files / globs covering this goal (typically integration tests).
  tests : Array[String]
  /// Documentation paths describing this goal.
  docs : Array[String]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct Task {
  id : String
  goal : String
  title : String
  status : Status
  deps : Array[String]
  notes : String
  /// True if this task corresponds to code that should have unit tests.
  regression_testable : Bool
  /// Test files / globs covering this task.
  tests : Array[String]
  /// Documentation paths describing this task.
  docs : Array[String]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct Dag {
  config : VmapConfig?
  project : Project
  goals : Array[Goal]
  tasks : Array[Task]
  /// Optional release lanes (versioned goal groupings). `mut` because the
  /// array reference itself may be initialized on first `add_release`; the
  /// underlying Array can be mutated in place once present.
  mut releases : Array[ReleaseConfig]?
} derive(Eq, Debug, ToJson, FromJson)

///|
pub impl Show for Dag with output(self, logger) {
  logger.write_string(@debug.to_repr(self).to_string())
}

///|
/// Empty DAG with the given project name.
pub fn Dag::empty(name : String) -> Dag {
  {
    config: Some(default_config()),
    project: { name, description: "" },
    goals: [],
    tasks: [],
    releases: None,
  }
}

///|
pub fn Dag::effective_config(self : Dag) -> VmapConfig {
  match self.config {
    Some(cfg) => cfg
    None => default_config()
  }
}

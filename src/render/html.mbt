///|
/// Render a self-contained HTML page for the given DAG. The generated page is
/// a dark topology workbench inspired by the Sisyphus canvas DAG: glowing
/// nodes, a dotted grid, dependency focus, pan/zoom, status filters, goal
/// progress, and an inline details panel. It intentionally avoids runtime
/// framework/CDN dependencies so `vmap render` still produces a portable file.
pub fn render(dag : @core.Dag) -> String {
  let title = if dag.project.name == "" { "vibe-map" } else { dag.project.name }
  let data = dag.to_json().stringify(indent=2)
  // Escape `</` to prevent premature script termination if a title contains it.
  let safe_data = data.replace(old="</", new="<\\/")
  let sb = StringBuilder::new()
  sb
  ..write_string(page_head(title))
  ..write_string(safe_data)
  .write_string(page_tail)
  sb.to_string()
}

///|
fn page_head(title : String) -> String {
  let head =
    $|<!DOCTYPE html>
    $|<html lang="zh">
    $|<head>
    $|<meta charset="utf-8" />
    $|<meta name="viewport" content="width=device-width, initial-scale=1" />
    $|<title>\{title} — vibe-map</title>
    $|<style>
    $|  :root {
    $|    --bg-base: #090d13;
    $|    --bg-panel: rgba(17, 23, 34, 0.92);
    $|    --bg-elevated: #182132;
    $|    --border-subtle: rgba(148, 163, 184, 0.18);
    $|    --border-default: rgba(148, 163, 184, 0.32);
    $|    --text-primary: #f8fafc;
    $|    --text-secondary: #dbeafe;
    $|    --text-muted: #9fb0c7;
    $|    --text-dimmed: #64748b;
    $|    --cyan: #7dd3fc;
    $|    --green: #86efac;
    $|    --gold: #fcd34d;
    $|    --rose: #fda4af;
    $|    --orange: #fdba74;
    $|    --radius: 8px;
    $|  }
    $|
    $|  * { box-sizing: border-box; }
    $|
    $|  html, body {
    $|    margin: 0;
    $|    min-height: 100%;
    $|    height: 100%;
    $|    overflow: hidden;
    $|    background:
    $|      radial-gradient(circle at 18% 12%, rgba(125, 211, 252, 0.15), transparent 26%),
    $|      radial-gradient(circle at 78% 6%, rgba(134, 239, 172, 0.12), transparent 26%),
    $|      linear-gradient(135deg, #070a0f 0%, #0b111a 52%, #10151f 100%);
    $|    color: var(--text-primary);
    $|    font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    $|    letter-spacing: 0;
    $|  }
    $|
    $|  button, input { font: inherit; }
    $|  button { cursor: pointer; }
    $|
    $|  #app {
    $|    display: grid;
    $|    grid-template-rows: 68px minmax(0, 1fr);
    $|    height: 100%;
    $|  }
    $|
    $|  .topbar {
    $|    display: flex;
    $|    align-items: center;
    $|    justify-content: space-between;
    $|    gap: 16px;
    $|    padding: 12px 16px;
    $|    border-bottom: 1px solid var(--border-subtle);
    $|    background: rgba(9, 13, 19, 0.92);
    $|    backdrop-filter: blur(18px);
    $|  }
    $|
    $|  .brand {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 12px;
    $|    min-width: 0;
    $|  }
    $|
    $|  .brand-mark {
    $|    display: grid;
    $|    place-items: center;
    $|    width: 40px;
    $|    height: 40px;
    $|    border: 1px solid rgba(125, 211, 252, 0.55);
    $|    border-radius: var(--radius);
    $|    background: linear-gradient(135deg, rgba(125, 211, 252, 0.18), rgba(134, 239, 172, 0.08));
    $|    color: var(--cyan);
    $|    font: 700 12px ui-monospace, SFMono-Regular, Menlo, monospace;
    $|    box-shadow: 0 0 26px rgba(125, 211, 252, 0.18);
    $|  }
    $|
    $|  h1 {
    $|    margin: 0;
    $|    max-width: 48vw;
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    font-size: 17px;
    $|    font-weight: 650;
    $|  }
    $|
    $|  .desc {
    $|    margin: 3px 0 0;
    $|    max-width: 52vw;
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    color: var(--text-muted);
    $|    font-size: 12px;
    $|  }
    $|
    $|  .top-stats {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 8px;
    $|    flex-wrap: wrap;
    $|    justify-content: flex-end;
    $|  }
    $|
    $|  .metric {
    $|    min-width: 74px;
    $|    padding: 7px 9px;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: rgba(17, 23, 34, 0.72);
    $|  }
    $|
    $|  .metric b {
    $|    display: block;
    $|    color: var(--text-primary);
    $|    font: 700 14px ui-monospace, SFMono-Regular, Menlo, monospace;
    $|  }
    $|
    $|  .metric span {
    $|    display: block;
    $|    margin-top: 2px;
    $|    color: var(--text-muted);
    $|    font-size: 10px;
    $|  }
    $|
    $|  .workspace {
    $|    min-height: 0;
    $|    display: grid;
    $|    grid-template-columns: 286px minmax(0, 1fr) 330px;
    $|    gap: 12px;
    $|    padding: 12px;
    $|  }
    $|
    $|  .panel, .canvas-shell {
    $|    min-width: 0;
    $|    min-height: 0;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: var(--bg-panel);
    $|    box-shadow: 0 18px 60px rgba(0, 0, 0, 0.28);
    $|  }
    $|
    $|  .panel {
    $|    display: flex;
    $|    flex-direction: column;
    $|    overflow: hidden;
    $|  }
    $|
    $|  .panel-head, .canvas-head {
    $|    flex: 0 0 auto;
    $|    display: flex;
    $|    align-items: center;
    $|    justify-content: space-between;
    $|    gap: 10px;
    $|    padding: 12px;
    $|    border-bottom: 1px solid var(--border-subtle);
    $|  }
    $|
    $|  .panel-title {
    $|    margin: 0;
    $|    color: var(--text-secondary);
    $|    font-size: 12px;
    $|    font-weight: 700;
    $|  }
    $|
    $|  .panel-subtitle {
    $|    margin: 3px 0 0;
    $|    color: var(--text-dimmed);
    $|    font-size: 11px;
    $|  }
    $|
    $|  .panel-body {
    $|    overflow: auto;
    $|    padding: 12px;
    $|  }
    $|
    $|  .progress {
    $|    overflow: hidden;
    $|    height: 8px;
    $|    border-radius: 999px;
    $|    background: rgba(148, 163, 184, 0.14);
    $|  }
    $|
    $|  .progress > span {
    $|    display: block;
    $|    width: 0;
    $|    height: 100%;
    $|    border-radius: inherit;
    $|    background: linear-gradient(90deg, var(--green), var(--cyan));
    $|    box-shadow: 0 0 18px rgba(125, 211, 252, 0.28);
    $|  }
    $|
    $|  .progress-row {
    $|    display: grid;
    $|    gap: 7px;
    $|    margin-bottom: 14px;
    $|  }
    $|
    $|  .progress-row label {
    $|    display: flex;
    $|    justify-content: space-between;
    $|    color: var(--text-muted);
    $|    font-size: 11px;
    $|  }
    $|
    $|  .node-list {
    $|    display: grid;
    $|    gap: 8px;
    $|  }
    $|
    $|  .node-row {
    $|    width: 100%;
    $|    padding: 10px;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: rgba(24, 33, 50, 0.55);
    $|    color: inherit;
    $|    text-align: left;
    $|    transition: border-color 140ms ease, background 140ms ease, transform 140ms ease;
    $|  }
    $|
    $|  .node-row:hover, .node-row.active {
    $|    border-color: rgba(125, 211, 252, 0.55);
    $|    background: rgba(30, 41, 59, 0.86);
    $|  }
    $|
    $|  .node-row.active { box-shadow: 0 0 0 1px rgba(125, 211, 252, 0.18); }
    $|
    $|  .node-row-title {
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    font-size: 12px;
    $|    font-weight: 650;
    $|  }
    $|
    $|  .node-row-meta {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 7px;
    $|    margin-top: 7px;
    $|    color: var(--text-muted);
    $|    font-size: 10px;
    $|  }
    $|
    $|  .status-dot {
    $|    flex: 0 0 auto;
    $|    width: 8px;
    $|    height: 8px;
    $|    border-radius: 999px;
    $|    background: var(--dot, var(--text-muted));
    $|    box-shadow: 0 0 10px var(--dot-glow, transparent);
    $|  }
    $|
    $|  .canvas-shell {
    $|    display: grid;
    $|    grid-template-rows: auto minmax(0, 1fr) auto;
    $|    overflow: hidden;
    $|  }
    $|
    $|  .canvas-title {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 10px;
    $|    min-width: 0;
    $|  }
    $|
    $|  .canvas-title-mark {
    $|    width: 34px;
    $|    height: 34px;
    $|    border: 1px solid rgba(134, 239, 172, 0.5);
    $|    border-radius: var(--radius);
    $|    background: rgba(134, 239, 172, 0.1);
    $|    color: var(--green);
    $|    display: grid;
    $|    place-items: center;
    $|    box-shadow: 0 0 24px rgba(134, 239, 172, 0.13);
    $|  }
    $|
    $|  .filter-bar, .toolbar, .legend {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 7px;
    $|    flex-wrap: wrap;
    $|  }
    $|
    $|  .filter-button, .icon-button {
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: 7px;
    $|    background: rgba(15, 23, 42, 0.72);
    $|    color: var(--text-muted);
    $|    transition: border-color 140ms ease, color 140ms ease, background 140ms ease;
    $|  }
    $|
    $|  .filter-button {
    $|    min-width: 54px;
    $|    padding: 6px 9px;
    $|    font-size: 11px;
    $|  }
    $|
    $|  .filter-button:hover, .filter-button.active,
    $|  .icon-button:hover {
    $|    border-color: rgba(125, 211, 252, 0.5);
    $|    background: rgba(14, 165, 233, 0.12);
    $|    color: var(--cyan);
    $|  }
    $|
    $|  .icon-button {
    $|    display: grid;
    $|    place-items: center;
    $|    width: 32px;
    $|    height: 32px;
    $|    padding: 0;
    $|  }
    $|
    $|  .icon-button svg {
    $|    width: 16px;
    $|    height: 16px;
    $|    stroke: currentColor;
    $|  }
    $|
    $|  .canvas-wrap {
    $|    position: relative;
    $|    min-height: 0;
    $|    background:
    $|      linear-gradient(rgba(125, 211, 252, 0.05) 1px, transparent 1px),
    $|      linear-gradient(90deg, rgba(125, 211, 252, 0.05) 1px, transparent 1px),
    $|      #080c12;
    $|    background-size: 44px 44px;
    $|  }
    $|
    $|  #map-canvas {
    $|    display: block;
    $|    width: 100%;
    $|    height: 100%;
    $|    cursor: grab;
    $|  }
    $|
    $|  #map-canvas.dragging { cursor: grabbing; }
    $|
    $|  .legend {
    $|    justify-content: space-between;
    $|    padding: 9px 12px;
    $|    border-top: 1px solid var(--border-subtle);
    $|    color: var(--text-muted);
    $|    font-size: 11px;
    $|  }
    $|
    $|  .legend-group {
    $|    display: flex;
    $|    align-items: center;
    $|    gap: 10px;
    $|    flex-wrap: wrap;
    $|  }
    $|
    $|  .legend-chip {
    $|    display: inline-flex;
    $|    align-items: center;
    $|    gap: 5px;
    $|    white-space: nowrap;
    $|  }
    $|
    $|  .legend-shape {
    $|    width: 10px;
    $|    height: 10px;
    $|    background: var(--legend-color);
    $|    box-shadow: 0 0 12px var(--legend-glow, transparent);
    $|  }
    $|
    $|  .legend-shape.hex {
    $|    width: 12px;
    $|    clip-path: polygon(25% 0, 75% 0, 100% 50%, 75% 100%, 25% 100%, 0 50%);
    $|  }
    $|
    $|  .legend-shape.circle { border-radius: 999px; }
    $|
    $|  .detail-empty {
    $|    display: grid;
    $|    place-items: center;
    $|    min-height: 180px;
    $|    color: var(--text-dimmed);
    $|    font-size: 12px;
    $|    text-align: center;
    $|  }
    $|
    $|  .detail-stack {
    $|    display: grid;
    $|    gap: 12px;
    $|  }
    $|
    $|  .detail-id {
    $|    overflow-wrap: anywhere;
    $|    color: var(--cyan);
    $|    font: 700 12px ui-monospace, SFMono-Regular, Menlo, monospace;
    $|  }
    $|
    $|  .detail-title {
    $|    margin: 6px 0 0;
    $|    color: var(--text-primary);
    $|    font-size: 15px;
    $|    font-weight: 700;
    $|    line-height: 1.35;
    $|  }
    $|
    $|  .badge-row {
    $|    display: flex;
    $|    flex-wrap: wrap;
    $|    gap: 6px;
    $|  }
    $|
    $|  .badge {
    $|    display: inline-flex;
    $|    align-items: center;
    $|    min-height: 22px;
    $|    padding: 3px 7px;
    $|    border: 1px solid var(--border-default);
    $|    border-radius: 999px;
    $|    color: var(--text-secondary);
    $|    background: rgba(148, 163, 184, 0.09);
    $|    font-size: 10px;
    $|  }
    $|
    $|  .kv {
    $|    display: grid;
    $|    grid-template-columns: 72px minmax(0, 1fr);
    $|    gap: 8px;
    $|    padding: 8px 0;
    $|    border-top: 1px solid var(--border-subtle);
    $|    color: var(--text-muted);
    $|    font-size: 12px;
    $|  }
    $|
    $|  .kv strong {
    $|    color: var(--text-dimmed);
    $|    font-weight: 600;
    $|  }
    $|
    $|  .kv span {
    $|    min-width: 0;
    $|    overflow-wrap: anywhere;
    $|    color: var(--text-secondary);
    $|  }
    $|
    $|  .chip-list {
    $|    display: flex;
    $|    flex-wrap: wrap;
    $|    gap: 6px;
    $|  }
    $|
    $|  .chip {
    $|    max-width: 100%;
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    padding: 4px 7px;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: 6px;
    $|    color: var(--text-secondary);
    $|    background: rgba(15, 23, 42, 0.72);
    $|    font: 10px ui-monospace, SFMono-Regular, Menlo, monospace;
    $|  }
    $|
    $|  .notes {
    $|    padding: 10px;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: rgba(15, 23, 42, 0.52);
    $|    color: var(--text-secondary);
    $|    font-size: 12px;
    $|    line-height: 1.55;
    $|    overflow-wrap: anywhere;
    $|  }
    $|
    $|  @media (max-width: 1060px) {
    $|    html, body { height: auto; overflow: auto; }
    $|    #app { min-height: 100vh; height: auto; grid-template-rows: auto auto; }
    $|    .topbar { align-items: flex-start; flex-direction: column; }
    $|    h1, .desc { max-width: 100%; }
    $|    .top-stats { justify-content: flex-start; }
    $|    .workspace { grid-template-columns: 1fr; }
    $|    .panel { max-height: none; }
    $|    .canvas-shell { min-height: 72vh; }
    $|  }
    $|
    $|  @media (max-width: 640px) {
    $|    .workspace { padding: 8px; gap: 8px; }
    $|    .canvas-head { align-items: stretch; flex-direction: column; }
    $|    .filter-bar, .toolbar { width: 100%; }
    $|    .filter-button { flex: 1 1 0; min-width: 0; }
    $|    .metric { flex: 1 1 calc(50% - 8px); }
    $|    .legend { align-items: flex-start; flex-direction: column; }
    $|  }
    $|</style>
    $|</head>
    $|<body>
    $|<div id="app">
    $|  <header class="topbar">
    $|    <div class="brand">
    $|      <div class="brand-mark">VM</div>
    $|      <div>
    $|        <h1 id="title"></h1>
    $|        <p class="desc" id="desc"></p>
    $|      </div>
    $|    </div>
    $|    <div class="top-stats" aria-label="DAG summary">
    $|      <div class="metric"><b id="metric-progress">0%</b><span>完成度</span></div>
    $|      <div class="metric"><b id="metric-milestones">0</b><span>目标</span></div>
    $|      <div class="metric"><b id="metric-issues">0</b><span>任务</span></div>
    $|      <div class="metric"><b id="metric-deps">0</b><span>依赖</span></div>
    $|    </div>
    $|  </header>
    $|  <main class="workspace">
    $|    <aside class="panel">
    $|      <div class="panel-head">
    $|        <div>
    $|          <h2 class="panel-title">项目进度</h2>
    $|          <p class="panel-subtitle" id="overview-subtitle"></p>
    $|        </div>
    $|      </div>
    $|      <div class="panel-body">
    $|        <div class="progress-row">
    $|          <label><span>整体完成</span><span id="overall-progress-label">0/0</span></label>
    $|          <div class="progress"><span id="overall-progress-bar"></span></div>
    $|        </div>
    $|        <div class="node-list" id="milestone-list"></div>
    $|      </div>
    $|    </aside>
    $|
    $|    <section class="canvas-shell">
    $|      <div class="canvas-head">
    $|        <div class="canvas-title">
    $|          <div class="canvas-title-mark" aria-hidden="true">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
    $|              <path d="M7 7h.01M17 7h.01M12 17h.01" />
    $|              <path d="M8 7h8M7.5 8l4 8M16.5 8l-4 8" />
    $|              <circle cx="7" cy="7" r="3" />
    $|              <circle cx="17" cy="7" r="3" />
    $|              <circle cx="12" cy="17" r="3" />
    $|            </svg>
    $|          </div>
    $|          <div>
    $|            <h2 class="panel-title">拓扑图</h2>
    $|            <p class="panel-subtitle" id="canvas-subtitle"></p>
    $|          </div>
    $|        </div>
    $|        <div class="filter-bar" role="group" aria-label="Node filters">
    $|          <button class="filter-button active" data-filter="all" type="button">全部</button>
    $|          <button class="filter-button" data-filter="active" type="button">进行中</button>
    $|          <button class="filter-button" data-filter="todo" type="button">待办</button>
    $|          <button class="filter-button" data-filter="done" type="button">已完成</button>
    $|        </div>
    $|        <div class="toolbar" aria-label="Map controls">
    $|          <button class="icon-button" id="zoom-in" type="button" title="放大" aria-label="放大">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="zoom-out" type="button" title="缩小" aria-label="缩小">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M5 12h14"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="fit-view" type="button" title="适配视图" aria-label="适配视图">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="clear-focus" type="button" title="清除聚焦" aria-label="清除聚焦">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
    $|          </button>
    $|        </div>
    $|      </div>
    $|      <div class="canvas-wrap">
    $|        <canvas id="map-canvas"></canvas>
    $|      </div>
    $|      <div class="legend">
    $|        <div class="legend-group">
    $|          <span class="legend-chip"><i class="legend-shape hex" style="--legend-color:#38bdf8;--legend-glow:rgba(56,189,248,.5)"></i>目标</span>
    $|          <span class="legend-chip"><i class="legend-shape circle" style="--legend-color:#86efac;--legend-glow:rgba(134,239,172,.5)"></i>任务</span>
    $|        </div>
    $|        <div class="legend-group">
    $|          <span class="legend-chip"><i class="legend-shape circle" style="--legend-color:#94a3b8"></i>待办</span>
    $|          <span class="legend-chip"><i class="legend-shape circle" style="--legend-color:#38bdf8;--legend-glow:rgba(56,189,248,.45)"></i>进行中</span>
    $|          <span class="legend-chip"><i class="legend-shape circle" style="--legend-color:#fb7185;--legend-glow:rgba(251,113,133,.45)"></i>阻塞</span>
    $|          <span class="legend-chip"><i class="legend-shape circle" style="--legend-color:#34d399;--legend-glow:rgba(52,211,153,.45)"></i>完成</span>
    $|        </div>
    $|      </div>
    $|    </section>
    $|
    $|    <aside class="panel">
    $|      <div class="panel-head">
    $|        <div>
    $|          <h2 class="panel-title">节点详情</h2>
    $|          <p class="panel-subtitle" id="detail-subtitle">未选择节点</p>
    $|        </div>
    $|      </div>
    $|      <div class="panel-body" id="details-panel">
    $|        <div class="detail-empty">未选择节点</div>
    $|      </div>
    $|    </aside>
    $|  </main>
    $|</div>
    $|<script type="application/json" id="dag-data">
    $|
  head
}

///|
let page_tail : String =
  #|</script>
  #|<script>
  #|(function () {
  #|  'use strict';
  #|
  #|  const dag = JSON.parse(document.getElementById('dag-data').textContent || '{}');
  #|  const canvas = document.getElementById('map-canvas');
  #|  const ctx = canvas.getContext('2d');
  #|  const dpr = window.devicePixelRatio || 1;
  #|
  #|  const STATUS_RANK = { done: 0, todo: 1, 'in-progress': 2, blocked: 3 };
  #|  const STATUS_META = {
  #|    todo: { label: '待办', color: '#94a3b8', border: '#cbd5e1', glow: 'rgba(148,163,184,0.22)', opacity: 0.48 },
  #|    'in-progress': { label: '进行中', color: '#38bdf8', border: '#7dd3fc', glow: 'rgba(56,189,248,0.62)', opacity: 1 },
  #|    blocked: { label: '阻塞', color: '#fb7185', border: '#fda4af', glow: 'rgba(251,113,133,0.58)', opacity: 1 },
  #|    done: { label: '完成', color: '#34d399', border: '#86efac', glow: 'rgba(52,211,153,0.5)', opacity: 1 },
  #|  };
  #|
  #|  const state = {
  #|    nodes: [],
  #|    edges: [],
  #|    visibleNodes: [],
  #|    visibleEdges: [],
  #|    nodeById: new Map(),
  #|    selectedId: null,
  #|    hoveredId: null,
  #|    filter: 'all',
  #|    focusIds: null,
  #|    transform: { x: 0, y: 0, scale: 1 },
  #|    pointer: { down: false, mode: null, moved: false, lastX: 0, lastY: 0, node: null },
  #|  };
  #|
  #|  function statusMeta(status) {
  #|    return STATUS_META[status] || STATUS_META.todo;
  #|  }
  #|
  #|  function escapeHtml(value) {
  #|    return String(value ?? '').replace(/[&<>"']/g, ch => ({
  #|      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  #|    }[ch]));
  #|  }
  #|
  #|  function truncateText(value, max) {
  #|    const text = String(value || '');
  #|    return text.length > max ? text.slice(0, Math.max(0, max - 1)) + '…' : text;
  #|  }
  #|
  #|  function buildGraph(input) {
  #|    const milestones = input.goals || input.milestones || [];
  #|    const issues = input.tasks || input.issues || [];
  #|    const milestoneState = new Map();
  #|
  #|    for (const m of milestones) {
  #|      milestoneState.set(m.id, { done: 0, total: 0, worst: 'done' });
  #|    }
  #|
  #|    for (const issue of issues) {
  #|      const status = issue.status || 'todo';
  #|      const owner = issue.goal || issue.milestone;
  #|      const bucket = milestoneState.get(owner);
  #|      if (!bucket) continue;
  #|      bucket.total += 1;
  #|      if (status === 'done') bucket.done += 1;
  #|      if ((STATUS_RANK[status] ?? 1) > (STATUS_RANK[bucket.worst] ?? 1)) {
  #|        bucket.worst = status;
  #|      }
  #|    }
  #|
  #|    for (const m of milestones) {
  #|      const bucket = milestoneState.get(m.id);
  #|      if (bucket && bucket.total === 0) bucket.worst = 'todo';
  #|    }
  #|
  #|    const nodes = [];
  #|    const nodeById = new Map();
  #|    const edges = [];
  #|
  #|    for (const m of milestones) {
  #|      const bucket = milestoneState.get(m.id) || { done: 0, total: 0, worst: 'todo' };
  #|      const pct = bucket.total > 0 ? Math.round((bucket.done / bucket.total) * 100) : 0;
  #|      const node = {
  #|        id: m.id,
  #|        title: m.title || m.id,
  #|        description: m.description || '',
  #|        kind: 'milestone',
  #|        status: bucket.worst,
  #|        deps: m.deps || [],
  #|        docs: m.docs || [],
  #|        tests: m.tests || [],
  #|        regressionTestable: !!m.regression_testable,
  #|        progress: { done: bucket.done, total: bucket.total, pct },
  #|        radius: 46,
  #|        x: 0,
  #|        y: 0,
  #|        vx: 0,
  #|        vy: 0,
  #|      };
  #|      nodes.push(node);
  #|      nodeById.set(node.id, node);
  #|    }
  #|
  #|    for (const issue of issues) {
  #|      const node = {
  #|        id: issue.id,
  #|        title: issue.title || issue.id,
  #|        description: issue.notes || '',
  #|        kind: 'issue',
  #|        status: issue.status || 'todo',
  #|        milestone: issue.goal || issue.milestone,
  #|        deps: issue.deps || [],
  #|        docs: issue.docs || [],
  #|        tests: issue.tests || [],
  #|        regressionTestable: !!issue.regression_testable,
  #|        progress: null,
  #|        radius: 31,
  #|        x: 0,
  #|        y: 0,
  #|        vx: 0,
  #|        vy: 0,
  #|      };
  #|      nodes.push(node);
  #|      nodeById.set(node.id, node);
  #|    }
  #|
  #|    for (const m of milestones) {
  #|      for (const dep of (m.deps || [])) {
  #|        if (nodeById.has(dep) && nodeById.has(m.id)) edges.push({ source: dep, target: m.id, kind: 'dep' });
  #|      }
  #|    }
  #|
  #|    for (const issue of issues) {
  #|      for (const dep of (issue.deps || [])) {
  #|        if (nodeById.has(dep) && nodeById.has(issue.id)) edges.push({ source: dep, target: issue.id, kind: 'dep' });
  #|      }
  #|      const owner = issue.goal || issue.milestone;
  #|      if (nodeById.has(owner)) edges.push({ source: owner, target: issue.id, kind: 'member' });
  #|    }
  #|
  #|    return { nodes, edges, nodeById };
  #|  }
  #|
  #|  function seedLayout() {
  #|    const milestones = state.nodes.filter(n => n.kind === 'milestone');
  #|    const centerRadius = Math.max(170, milestones.length * 48);
  #|    milestones.forEach((node, index) => {
  #|      const angle = milestones.length <= 1 ? 0 : (-Math.PI / 2) + (index / milestones.length) * Math.PI * 2;
  #|      node.x = milestones.length <= 1 ? 0 : Math.cos(angle) * centerRadius;
  #|      node.y = milestones.length <= 1 ? 0 : Math.sin(angle) * centerRadius;
  #|      node.seedX = node.x;
  #|      node.seedY = node.y;
  #|    });
  #|
  #|    for (const milestone of milestones) {
  #|      const children = state.nodes.filter(n => n.kind === 'issue' && n.milestone === milestone.id);
  #|      const radius = Math.max(92, 46 + children.length * 8);
  #|      children.forEach((node, index) => {
  #|        const angle = (-Math.PI / 2) + (index / Math.max(1, children.length)) * Math.PI * 2;
  #|        node.x = milestone.x + Math.cos(angle) * radius;
  #|        node.y = milestone.y + Math.sin(angle) * radius;
  #|        node.seedX = node.x;
  #|        node.seedY = node.y;
  #|      });
  #|    }
  #|
  #|    settleLayout(260);
  #|  }
  #|
  #|  function settleLayout(iterations) {
  #|    const nodes = state.nodes;
  #|    const edges = state.edges;
  #|    if (nodes.length === 0) return;
  #|
  #|    for (let step = 0; step < iterations; step += 1) {
  #|      const alpha = 1 - step / iterations;
  #|
  #|      for (let i = 0; i < nodes.length; i += 1) {
  #|        const a = nodes[i];
  #|        for (let j = i + 1; j < nodes.length; j += 1) {
  #|          const b = nodes[j];
  #|          let dx = b.x - a.x;
  #|          let dy = b.y - a.y;
  #|          let dist2 = dx * dx + dy * dy;
  #|          if (dist2 < 0.01) {
  #|            dx = (i + 1) * 0.17;
  #|            dy = (j + 1) * 0.13;
  #|            dist2 = dx * dx + dy * dy;
  #|          }
  #|          const minDist = a.radius + b.radius + 34;
  #|          const dist = Math.sqrt(dist2);
  #|          const force = Math.min(5.5, (minDist * minDist) / dist2) * 0.14 * alpha;
  #|          const fx = (dx / dist) * force;
  #|          const fy = (dy / dist) * force;
  #|          a.vx -= fx;
  #|          a.vy -= fy;
  #|          b.vx += fx;
  #|          b.vy += fy;
  #|        }
  #|      }
  #|
  #|      for (const edge of edges) {
  #|        const source = state.nodeById.get(edge.source);
  #|        const target = state.nodeById.get(edge.target);
  #|        if (!source || !target) continue;
  #|        const desired = edge.kind === 'member' ? 118 : 210;
  #|        const strength = edge.kind === 'member' ? 0.018 : 0.026;
  #|        const dx = target.x - source.x;
  #|        const dy = target.y - source.y;
  #|        const dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
  #|        const force = (dist - desired) * strength * alpha;
  #|        const fx = (dx / dist) * force;
  #|        const fy = (dy / dist) * force;
  #|        source.vx += fx;
  #|        source.vy += fy;
  #|        target.vx -= fx;
  #|        target.vy -= fy;
  #|      }
  #|
  #|      for (const node of nodes) {
  #|        if (node.kind === 'issue') {
  #|          const milestone = state.nodeById.get(node.milestone);
  #|          if (milestone) {
  #|            node.vx += (milestone.x - node.x) * 0.0025 * alpha;
  #|            node.vy += (milestone.y - node.y) * 0.0025 * alpha;
  #|          }
  #|        } else {
  #|          node.vx += ((node.seedX || 0) - node.x) * 0.004 * alpha;
  #|          node.vy += ((node.seedY || 0) - node.y) * 0.004 * alpha;
  #|        }
  #|        node.vx += (0 - node.x) * 0.0008 * alpha;
  #|        node.vy += (0 - node.y) * 0.0008 * alpha;
  #|        node.vx *= 0.78;
  #|        node.vy *= 0.78;
  #|        node.x += node.vx;
  #|        node.y += node.vy;
  #|      }
  #|    }
  #|  }
  #|
  #|  function applyFilter() {
  #|    const activeStatuses = new Set(['in-progress', 'blocked']);
  #|    let visible = state.nodes.filter(node => {
  #|      if (state.filter === 'all') return true;
  #|      if (state.filter === 'active') return activeStatuses.has(node.status);
  #|      return node.status === state.filter;
  #|    });
  #|
  #|    const visibleIds = new Set(visible.map(n => n.id));
  #|    if (state.filter !== 'all') {
  #|      for (const node of [...visible]) {
  #|        if (node.kind === 'issue' && node.milestone && !visibleIds.has(node.milestone)) {
  #|          const milestone = state.nodeById.get(node.milestone);
  #|          if (milestone) {
  #|            visible.push(milestone);
  #|            visibleIds.add(milestone.id);
  #|          }
  #|        }
  #|      }
  #|    }
  #|
  #|    state.visibleNodes = visible;
  #|    state.visibleEdges = state.edges.filter(edge => visibleIds.has(edge.source) && visibleIds.has(edge.target));
  #|  }
  #|
  #|  function dependencyClosure(id) {
  #|    const keep = new Set([id]);
  #|    const depEdges = state.edges.filter(edge => edge.kind === 'dep');
  #|    const forward = new Map();
  #|    const reverse = new Map();
  #|
  #|    for (const edge of depEdges) {
  #|      if (!forward.has(edge.source)) forward.set(edge.source, []);
  #|      if (!reverse.has(edge.target)) reverse.set(edge.target, []);
  #|      forward.get(edge.source).push(edge.target);
  #|      reverse.get(edge.target).push(edge.source);
  #|    }
  #|
  #|    const walk = (map) => {
  #|      const queue = [id];
  #|      while (queue.length > 0) {
  #|        const current = queue.shift();
  #|        for (const next of (map.get(current) || [])) {
  #|          if (!keep.has(next)) {
  #|            keep.add(next);
  #|            queue.push(next);
  #|          }
  #|        }
  #|      }
  #|    };
  #|
  #|    walk(forward);
  #|    walk(reverse);
  #|    return keep;
  #|  }
  #|
  #|  function resizeCanvas() {
  #|    const rect = canvas.parentElement.getBoundingClientRect();
  #|    const width = Math.max(320, rect.width);
  #|    const height = Math.max(320, rect.height);
  #|    canvas.width = Math.floor(width * dpr);
  #|    canvas.height = Math.floor(height * dpr);
  #|    canvas.style.width = width + 'px';
  #|    canvas.style.height = height + 'px';
  #|    fitView(false);
  #|  }
  #|
  #|  function boundsFor(nodes) {
  #|    if (!nodes.length) return null;
  #|    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  #|    for (const node of nodes) {
  #|      minX = Math.min(minX, node.x - node.radius - 34);
  #|      minY = Math.min(minY, node.y - node.radius - 34);
  #|      maxX = Math.max(maxX, node.x + node.radius + 34);
  #|      maxY = Math.max(maxY, node.y + node.radius + 34);
  #|    }
  #|    return { minX, minY, maxX, maxY, width: maxX - minX, height: maxY - minY };
  #|  }
  #|
  #|  function fitView(animate) {
  #|    const bounds = boundsFor(state.visibleNodes.length ? state.visibleNodes : state.nodes);
  #|    if (!bounds) return;
  #|    const width = canvas.clientWidth || 800;
  #|    const height = canvas.clientHeight || 600;
  #|    const scale = Math.max(0.2, Math.min(1.8, Math.min(width / bounds.width, height / bounds.height) * 0.88));
  #|    const target = {
  #|      x: width / 2 - (bounds.minX + bounds.width / 2) * scale,
  #|      y: height / 2 - (bounds.minY + bounds.height / 2) * scale,
  #|      scale,
  #|    };
  #|    if (!animate) {
  #|      state.transform = target;
  #|      return;
  #|    }
  #|    const start = { ...state.transform };
  #|    const started = performance.now();
  #|    const duration = 180;
  #|    function step(now) {
  #|      const t = Math.min(1, (now - started) / duration);
  #|      const eased = 1 - Math.pow(1 - t, 3);
  #|      state.transform.x = start.x + (target.x - start.x) * eased;
  #|      state.transform.y = start.y + (target.y - start.y) * eased;
  #|      state.transform.scale = start.scale + (target.scale - start.scale) * eased;
  #|      if (t < 1) requestAnimationFrame(step);
  #|    }
  #|    requestAnimationFrame(step);
  #|  }
  #|
  #|  function worldFromScreen(screenX, screenY) {
  #|    return {
  #|      x: (screenX - state.transform.x) / state.transform.scale,
  #|      y: (screenY - state.transform.y) / state.transform.scale,
  #|    };
  #|  }
  #|
  #|  function hitTest(screenX, screenY) {
  #|    const p = worldFromScreen(screenX, screenY);
  #|    for (let i = state.visibleNodes.length - 1; i >= 0; i -= 1) {
  #|      const node = state.visibleNodes[i];
  #|      const dx = p.x - node.x;
  #|      const dy = p.y - node.y;
  #|      if (dx * dx + dy * dy <= node.radius * node.radius * 1.35) return node;
  #|    }
  #|    return null;
  #|  }
  #|
  #|  function drawGrid(width, height) {
  #|    const gap = 42;
  #|    const startX = -state.transform.x / state.transform.scale;
  #|    const startY = -state.transform.y / state.transform.scale;
  #|    const endX = startX + width / state.transform.scale;
  #|    const endY = startY + height / state.transform.scale;
  #|    const gridStartX = Math.floor(startX / gap) * gap;
  #|    const gridStartY = Math.floor(startY / gap) * gap;
  #|    ctx.fillStyle = 'rgba(125, 211, 252, 0.12)';
  #|    for (let x = gridStartX; x <= endX; x += gap) {
  #|      for (let y = gridStartY; y <= endY; y += gap) {
  #|        ctx.beginPath();
  #|        ctx.arc(x, y, 1.1, 0, Math.PI * 2);
  #|        ctx.fill();
  #|      }
  #|    }
  #|  }
  #|
  #|  function drawHexPath(x, y, r) {
  #|    ctx.beginPath();
  #|    for (let i = 0; i < 6; i += 1) {
  #|      const angle = Math.PI / 6 + i * Math.PI / 3;
  #|      const px = x + Math.cos(angle) * r;
  #|      const py = y + Math.sin(angle) * r;
  #|      if (i === 0) ctx.moveTo(px, py);
  #|      else ctx.lineTo(px, py);
  #|    }
  #|    ctx.closePath();
  #|  }
  #|
  #|  function drawArrow(x, y, angle, size, color) {
  #|    ctx.fillStyle = color;
  #|    ctx.beginPath();
  #|    ctx.moveTo(x, y);
  #|    ctx.lineTo(x - Math.cos(angle - Math.PI / 6) * size, y - Math.sin(angle - Math.PI / 6) * size);
  #|    ctx.lineTo(x - Math.cos(angle + Math.PI / 6) * size, y - Math.sin(angle + Math.PI / 6) * size);
  #|    ctx.closePath();
  #|    ctx.fill();
  #|  }
  #|
  #|  function drawEdge(edge, time) {
  #|    const source = state.nodeById.get(edge.source);
  #|    const target = state.nodeById.get(edge.target);
  #|    if (!source || !target) return;
  #|    const dx = target.x - source.x;
  #|    const dy = target.y - source.y;
  #|    const dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
  #|    const nx = dx / dist;
  #|    const ny = dy / dist;
  #|    const startX = source.x + nx * (source.radius + 3);
  #|    const startY = source.y + ny * (source.radius + 3);
  #|    const endX = target.x - nx * (target.radius + 12);
  #|    const endY = target.y - ny * (target.radius + 12);
  #|    const isFocused = state.focusIds && state.focusIds.has(source.id) && state.focusIds.has(target.id);
  #|    const isDimmed = state.focusIds && !isFocused;
  #|
  #|    ctx.save();
  #|    ctx.globalAlpha = edge.kind === 'member' ? (isDimmed ? 0.04 : 0.18) : (isDimmed ? 0.08 : 0.86);
  #|    ctx.lineWidth = edge.kind === 'member' ? 1 : (isFocused ? 3.2 : 2.1);
  #|    ctx.strokeStyle = edge.kind === 'member' ? 'rgba(148, 163, 184, 0.48)' : (isFocused ? '#fcd34d' : '#7dd3fc');
  #|    ctx.shadowColor = edge.kind === 'member' ? 'transparent' : (isFocused ? 'rgba(252,211,77,0.65)' : 'rgba(125,211,252,0.35)');
  #|    ctx.shadowBlur = edge.kind === 'member' ? 0 : (isFocused ? 16 : 9);
  #|    if (edge.kind === 'member') ctx.setLineDash([4, 7]);
  #|
  #|    const curve = edge.kind === 'member' ? 0 : Math.sin((source.x + target.y) * 0.003) * 26;
  #|    const mx = (startX + endX) / 2 - ny * curve;
  #|    const my = (startY + endY) / 2 + nx * curve;
  #|    ctx.beginPath();
  #|    ctx.moveTo(startX, startY);
  #|    ctx.quadraticCurveTo(mx, my, endX, endY);
  #|    ctx.stroke();
  #|    ctx.setLineDash([]);
  #|
  #|    if (edge.kind === 'dep') {
  #|      const pulse = isFocused ? 1 + Math.sin(time / 190) * 0.12 : 1;
  #|      drawArrow(endX, endY, Math.atan2(endY - my, endX - mx), 10 * pulse, isFocused ? '#fcd34d' : '#7dd3fc');
  #|    }
  #|    ctx.restore();
  #|  }
  #|
  #|  function roundedTextLines(text, maxChars) {
  #|    const words = String(text || '').split(/\s+/).filter(Boolean);
  #|    if (words.length <= 1) {
  #|      const raw = String(text || '');
  #|      return raw.length > maxChars ? [truncateText(raw, maxChars), ''] : [raw, ''];
  #|    }
  #|    const lines = ['', ''];
  #|    let line = 0;
  #|    for (const word of words) {
  #|      const next = lines[line] ? lines[line] + ' ' + word : word;
  #|      if (next.length <= maxChars || !lines[line]) {
  #|        lines[line] = next;
  #|      } else if (line === 0) {
  #|        line = 1;
  #|        lines[line] = word;
  #|      } else {
  #|        lines[line] = truncateText(lines[line] + ' ' + word, maxChars);
  #|        break;
  #|      }
  #|    }
  #|    return [truncateText(lines[0], maxChars), truncateText(lines[1], maxChars)];
  #|  }
  #|
  #|  function drawNode(node, time) {
  #|    const meta = statusMeta(node.status);
  #|    const selected = node.id === state.selectedId;
  #|    const hovered = node.id === state.hoveredId;
  #|    const focused = state.focusIds ? state.focusIds.has(node.id) : true;
  #|    const dim = state.focusIds && !focused ? 0.16 : meta.opacity;
  #|    const pulse = (node.status === 'in-progress' || selected) ? (1 + Math.sin(time / 260) * 0.055) : 1;
  #|    const radius = node.radius * pulse;
  #|
  #|    ctx.save();
  #|    ctx.globalAlpha = dim;
  #|    ctx.shadowColor = selected ? 'rgba(252,211,77,0.82)' : meta.glow;
  #|    ctx.shadowBlur = selected ? 30 : (node.status === 'in-progress' ? 24 : 15);
  #|
  #|    const gradient = ctx.createRadialGradient(node.x - radius * 0.28, node.y - radius * 0.32, radius * 0.1, node.x, node.y, radius);
  #|    gradient.addColorStop(0, '#f8fafc');
  #|    gradient.addColorStop(0.13, meta.border);
  #|    gradient.addColorStop(1, meta.color);
  #|
  #|    if (node.kind === 'milestone') {
  #|      drawHexPath(node.x, node.y, radius);
  #|    } else {
  #|      ctx.beginPath();
  #|      ctx.arc(node.x, node.y, radius, 0, Math.PI * 2);
  #|    }
  #|    ctx.fillStyle = gradient;
  #|    ctx.fill();
  #|    ctx.shadowBlur = 0;
  #|    ctx.strokeStyle = selected ? '#fcd34d' : meta.border;
  #|    ctx.lineWidth = selected ? 3.2 : 2;
  #|    ctx.stroke();
  #|
  #|    if (selected || hovered) {
  #|      ctx.globalAlpha = selected ? 0.88 : 0.5;
  #|      ctx.strokeStyle = selected ? '#fcd34d' : 'rgba(248,250,252,0.7)';
  #|      ctx.lineWidth = selected ? 2.4 : 1.5;
  #|      ctx.beginPath();
  #|      ctx.arc(node.x, node.y, radius + (selected ? 9 : 6), 0, Math.PI * 2);
  #|      ctx.stroke();
  #|    }
  #|
  #|    if (node.kind === 'milestone' && node.progress && node.progress.total > 0) {
  #|      ctx.globalAlpha = dim;
  #|      ctx.strokeStyle = 'rgba(15,23,42,0.58)';
  #|      ctx.lineWidth = 5;
  #|      ctx.beginPath();
  #|      ctx.arc(node.x, node.y, radius + 13, -Math.PI / 2, Math.PI * 1.5);
  #|      ctx.stroke();
  #|      ctx.strokeStyle = '#86efac';
  #|      ctx.lineWidth = 5;
  #|      ctx.beginPath();
  #|      ctx.arc(node.x, node.y, radius + 13, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (node.progress.pct / 100));
  #|      ctx.stroke();
  #|    }
  #|
  #|    ctx.globalAlpha = Math.min(1, dim + 0.2);
  #|    ctx.shadowBlur = 0;
  #|    ctx.fillStyle = '#06101a';
  #|    ctx.textAlign = 'center';
  #|    ctx.textBaseline = 'middle';
  #|    ctx.font = '700 10px ui-monospace, SFMono-Regular, Menlo, monospace';
  #|    ctx.fillText(node.kind === 'milestone' ? 'GOAL' : meta.label, node.x, node.y - 9);
  #|    const lines = roundedTextLines(node.title || node.id, node.kind === 'milestone' ? 11 : 10);
  #|    ctx.font = '650 10px Inter, system-ui, sans-serif';
  #|    ctx.fillText(lines[0], node.x, node.y + 6);
  #|    if (lines[1]) ctx.fillText(lines[1], node.x, node.y + 18);
  #|    ctx.restore();
  #|  }
  #|
  #|  function render(time) {
  #|    const width = canvas.clientWidth || 800;
  #|    const height = canvas.clientHeight || 600;
  #|
  #|    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  #|    ctx.clearRect(0, 0, width, height);
  #|    ctx.fillStyle = '#080c12';
  #|    ctx.fillRect(0, 0, width, height);
  #|
  #|    ctx.save();
  #|    ctx.translate(state.transform.x, state.transform.y);
  #|    ctx.scale(state.transform.scale, state.transform.scale);
  #|    drawGrid(width, height);
  #|    for (const edge of state.visibleEdges) drawEdge(edge, time);
  #|    for (const node of state.visibleNodes) drawNode(node, time);
  #|    ctx.restore();
  #|
  #|    requestAnimationFrame(render);
  #|  }
  #|
  #|  function selectNode(id, focusView) {
  #|    state.selectedId = id;
  #|    state.focusIds = id ? dependencyClosure(id) : null;
  #|    renderDetails();
  #|    renderMilestoneList();
  #|    if (focusView && id) {
  #|      const node = state.nodeById.get(id);
  #|      if (node) {
  #|        state.transform.x = (canvas.clientWidth || 800) / 2 - node.x * state.transform.scale;
  #|        state.transform.y = (canvas.clientHeight || 600) / 2 - node.y * state.transform.scale;
  #|      }
  #|    }
  #|  }
  #|
  #|  function renderStats() {
  #|    const dagGoals = dag.goals || dag.milestones || [];
  #|    const dagTasks = dag.tasks || dag.issues || [];
  #|    const milestones = dagGoals.length;
  #|    const issues = dagTasks.length;
  #|    const depCount = state.edges.filter(e => e.kind === 'dep').length;
  #|    const done = dagTasks.filter(i => i.status === 'done').length;
  #|    const pct = issues > 0 ? Math.round((done / issues) * 100) : 0;
  #|    document.getElementById('title').textContent = dag.project?.name || 'vibe-map';
  #|    document.getElementById('desc').textContent = dag.project?.description || '';
  #|    document.getElementById('metric-progress').textContent = pct + '%';
  #|    document.getElementById('metric-milestones').textContent = String(milestones);
  #|    document.getElementById('metric-issues').textContent = String(issues);
  #|    document.getElementById('metric-deps').textContent = String(depCount);
  #|    document.getElementById('overall-progress-label').textContent = done + '/' + issues;
  #|    document.getElementById('overall-progress-bar').style.width = pct + '%';
  #|    document.getElementById('overview-subtitle').textContent = milestones + ' 个目标，' + issues + ' 个任务';
  #|    document.getElementById('canvas-subtitle').textContent = 'n=' + state.nodes.length + ' e=' + depCount;
  #|  }
  #|
  #|  function renderMilestoneList() {
  #|    const list = document.getElementById('milestone-list');
  #|    const milestones = state.nodes.filter(n => n.kind === 'milestone');
  #|    if (milestones.length === 0) {
  #|      list.innerHTML = '<div class="detail-empty">暂无目标</div>';
  #|      return;
  #|    }
  #|    list.innerHTML = milestones.map(node => {
  #|      const meta = statusMeta(node.status);
  #|      const progress = node.progress ? node.progress.done + '/' + node.progress.total + ' · ' + node.progress.pct + '%' : '';
  #|      return `
  #|        <button class="node-row ${node.id === state.selectedId ? 'active' : ''}" type="button" data-node-id="${escapeHtml(node.id)}">
  #|          <div class="node-row-title">${escapeHtml(node.title)}</div>
  #|          <div class="node-row-meta">
  #|            <i class="status-dot" style="--dot:${meta.color};--dot-glow:${meta.glow}"></i>
  #|            <span>${escapeHtml(meta.label)}</span>
  #|            <span>${escapeHtml(progress)}</span>
  #|          </div>
  #|        </button>`;
  #|    }).join('');
  #|    list.querySelectorAll('[data-node-id]').forEach(button => {
  #|      button.addEventListener('click', () => selectNode(button.getAttribute('data-node-id'), true));
  #|    });
  #|  }
  #|
  #|  function relatedIds(id, direction) {
  #|    return state.edges
  #|      .filter(edge => edge.kind === 'dep' && (direction === 'in' ? edge.target === id : edge.source === id))
  #|      .map(edge => direction === 'in' ? edge.source : edge.target);
  #|  }
  #|
  #|  function chips(items, emptyText) {
  #|    if (!items || items.length === 0) return '<span>' + escapeHtml(emptyText) + '</span>';
  #|    return '<div class="chip-list">' + items.map(item => '<span class="chip" title="' + escapeHtml(item) + '">' + escapeHtml(item) + '</span>').join('') + '</div>';
  #|  }
  #|
  #|  function renderDetails() {
  #|    const panel = document.getElementById('details-panel');
  #|    const subtitle = document.getElementById('detail-subtitle');
  #|    const node = state.selectedId ? state.nodeById.get(state.selectedId) : null;
  #|    if (!node) {
  #|      subtitle.textContent = '未选择节点';
  #|      panel.innerHTML = '<div class="detail-empty">未选择节点</div>';
  #|      return;
  #|    }
  #|
  #|    const meta = statusMeta(node.status);
  #|    const inbound = relatedIds(node.id, 'in');
  #|    const outbound = relatedIds(node.id, 'out');
  #|    const memberIssues = node.kind === 'milestone'
  #|      ? state.nodes.filter(n => n.kind === 'issue' && n.milestone === node.id).map(n => n.id)
  #|      : [];
  #|    const milestone = node.kind === 'issue' ? state.nodeById.get(node.milestone) : null;
  #|    subtitle.textContent = node.kind === 'milestone' ? '目标' : '任务';
  #|
  #|    panel.innerHTML = `
  #|      <div class="detail-stack">
  #|        <div>
  #|          <div class="detail-id">${escapeHtml(node.id)}</div>
  #|          <h3 class="detail-title">${escapeHtml(node.title)}</h3>
  #|        </div>
  #|        <div class="badge-row">
  #|          <span class="badge">${node.kind === 'milestone' ? '目标' : '任务'}</span>
  #|          <span class="badge" style="border-color:${meta.border};color:${meta.border}">${escapeHtml(meta.label)}</span>
  #|          ${node.regressionTestable ? '<span class="badge">regression-testable</span>' : ''}
  #|        </div>
  #|        ${node.description ? '<div class="notes">' + escapeHtml(node.description) + '</div>' : ''}
  #|        ${node.progress ? '<div class="progress-row"><label><span>完成</span><span>' + node.progress.done + '/' + node.progress.total + ' · ' + node.progress.pct + '%</span></label><div class="progress"><span style="width:' + node.progress.pct + '%"></span></div></div>' : ''}
  #|        ${milestone ? '<div class="kv"><strong>所属</strong><span>' + escapeHtml(milestone.title) + '</span></div>' : ''}
  #|        <div class="kv"><strong>依赖</strong>${chips(inbound, '无')}</div>
  #|        <div class="kv"><strong>被依赖</strong>${chips(outbound, '无')}</div>
  #|        ${memberIssues.length ? '<div class="kv"><strong>任务</strong>' + chips(memberIssues, '无') + '</div>' : ''}
  #|        <div class="kv"><strong>测试</strong>${chips(node.tests, '未记录')}</div>
  #|        <div class="kv"><strong>文档</strong>${chips(node.docs, '未记录')}</div>
  #|      </div>`;
  #|  }
  #|
  #|  function setFilter(filter) {
  #|    state.filter = filter;
  #|    document.querySelectorAll('.filter-button').forEach(button => {
  #|      button.classList.toggle('active', button.getAttribute('data-filter') === filter);
  #|    });
  #|    applyFilter();
  #|    if (state.selectedId && !state.visibleNodes.some(n => n.id === state.selectedId)) {
  #|      selectNode(null, false);
  #|    }
  #|    fitView(true);
  #|  }
  #|
  #|  function zoomAt(screenX, screenY, factor) {
  #|    const before = worldFromScreen(screenX, screenY);
  #|    state.transform.scale = Math.max(0.16, Math.min(3, state.transform.scale * factor));
  #|    state.transform.x = screenX - before.x * state.transform.scale;
  #|    state.transform.y = screenY - before.y * state.transform.scale;
  #|  }
  #|
  #|  function bindEvents() {
  #|    window.addEventListener('resize', resizeCanvas);
  #|
  #|    document.querySelectorAll('.filter-button').forEach(button => {
  #|      button.addEventListener('click', () => setFilter(button.getAttribute('data-filter') || 'all'));
  #|    });
  #|
  #|    document.getElementById('zoom-in').addEventListener('click', () => zoomAt((canvas.clientWidth || 800) / 2, (canvas.clientHeight || 600) / 2, 1.18));
  #|    document.getElementById('zoom-out').addEventListener('click', () => zoomAt((canvas.clientWidth || 800) / 2, (canvas.clientHeight || 600) / 2, 1 / 1.18));
  #|    document.getElementById('fit-view').addEventListener('click', () => fitView(true));
  #|    document.getElementById('clear-focus').addEventListener('click', () => selectNode(null, false));
  #|
  #|    canvas.addEventListener('wheel', event => {
  #|      event.preventDefault();
  #|      const rect = canvas.getBoundingClientRect();
  #|      const factor = event.deltaY < 0 ? 1.12 : 1 / 1.12;
  #|      zoomAt(event.clientX - rect.left, event.clientY - rect.top, factor);
  #|    }, { passive: false });
  #|
  #|    canvas.addEventListener('mousedown', event => {
  #|      if (event.button !== 0) return;
  #|      const rect = canvas.getBoundingClientRect();
  #|      const x = event.clientX - rect.left;
  #|      const y = event.clientY - rect.top;
  #|      const node = hitTest(x, y);
  #|      state.pointer = { down: true, mode: node ? 'node' : 'pan', moved: false, lastX: x, lastY: y, node };
  #|      canvas.classList.add('dragging');
  #|    });
  #|
  #|    window.addEventListener('mousemove', event => {
  #|      const rect = canvas.getBoundingClientRect();
  #|      const x = event.clientX - rect.left;
  #|      const y = event.clientY - rect.top;
  #|
  #|      if (state.pointer.down) {
  #|        const dx = x - state.pointer.lastX;
  #|        const dy = y - state.pointer.lastY;
  #|        if (Math.abs(dx) + Math.abs(dy) > 2) state.pointer.moved = true;
  #|        if (state.pointer.mode === 'node' && state.pointer.node) {
  #|          const point = worldFromScreen(x, y);
  #|          state.pointer.node.x = point.x;
  #|          state.pointer.node.y = point.y;
  #|          state.pointer.node.vx = 0;
  #|          state.pointer.node.vy = 0;
  #|        } else if (state.pointer.mode === 'pan') {
  #|          state.transform.x += dx;
  #|          state.transform.y += dy;
  #|        }
  #|        state.pointer.lastX = x;
  #|        state.pointer.lastY = y;
  #|      } else {
  #|        const hover = hitTest(x, y);
  #|        state.hoveredId = hover ? hover.id : null;
  #|      }
  #|    });
  #|
  #|    window.addEventListener('mouseup', () => {
  #|      if (!state.pointer.down) return;
  #|      if (state.pointer.mode === 'node' && state.pointer.node && !state.pointer.moved) {
  #|        selectNode(state.pointer.node.id, false);
  #|      } else if (state.pointer.mode === 'pan' && !state.pointer.moved) {
  #|        selectNode(null, false);
  #|      }
  #|      state.pointer.down = false;
  #|      canvas.classList.remove('dragging');
  #|    });
  #|
  #|    canvas.addEventListener('mouseleave', () => {
  #|      state.hoveredId = null;
  #|    });
  #|  }
  #|
  #|  function init() {
  #|    const graph = buildGraph(dag);
  #|    state.nodes = graph.nodes;
  #|    state.edges = graph.edges;
  #|    state.nodeById = graph.nodeById;
  #|    seedLayout();
  #|    applyFilter();
  #|    renderStats();
  #|    renderMilestoneList();
  #|    renderDetails();
  #|    resizeCanvas();
  #|    bindEvents();
  #|    requestAnimationFrame(render);
  #|  }
  #|
  #|  init();
  #|})();
  #|</script>
  #|</body>
  #|</html>
  #|

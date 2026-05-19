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
    $|    background: linear-gradient(135deg, #070a0f 0%, #0b111a 52%, #10151f 100%);
    $|    color: var(--text-primary);
    $|    font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    $|    letter-spacing: 0;
    $|  }
    $|
    $|  button, input, select { font: inherit; }
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
    $|  .control-stack {
    $|    display: grid;
    $|    gap: 8px;
    $|    margin-bottom: 12px;
    $|  }
    $|
    $|  .search-input, .select-input {
    $|    width: 100%;
    $|    min-height: 32px;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: rgba(15, 23, 42, 0.72);
    $|    color: var(--text-secondary);
    $|    padding: 7px 9px;
    $|    outline: none;
    $|    font-size: 12px;
    $|  }
    $|
    $|  .search-input:focus, .select-input:focus {
    $|    border-color: rgba(125, 211, 252, 0.58);
    $|    box-shadow: 0 0 0 2px rgba(125, 211, 252, 0.12);
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
    $|  .node-tooltip {
    $|    position: fixed;
    $|    z-index: 40;
    $|    max-width: min(360px, calc(100vw - 24px));
    $|    padding: 8px 10px;
    $|    border: 1px solid rgba(125, 211, 252, 0.38);
    $|    border-radius: 7px;
    $|    background: rgba(8, 13, 22, 0.94);
    $|    color: var(--text-secondary);
    $|    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.38), 0 0 18px rgba(125, 211, 252, 0.12);
    $|    font-size: 12px;
    $|    font-weight: 650;
    $|    line-height: 1.35;
    $|    overflow-wrap: anywhere;
    $|    pointer-events: none;
    $|  }
    $|
    $|  .node-modal-backdrop {
    $|    position: fixed;
    $|    inset: 0;
    $|    z-index: 50;
    $|    display: grid;
    $|    place-items: center;
    $|    padding: 22px;
    $|    background: rgba(2, 6, 12, 0.48);
    $|    backdrop-filter: blur(12px) saturate(130%);
    $|  }
    $|
    $|  .node-modal-backdrop[hidden] {
    $|    display: none;
    $|  }
    $|
    $|  .node-modal {
    $|    display: grid;
    $|    grid-template-rows: auto minmax(0, 1fr);
    $|    width: min(740px, calc(100vw - 32px));
    $|    max-height: min(820px, calc(100vh - 44px));
    $|    overflow: hidden;
    $|    border: 1px solid rgba(125, 211, 252, 0.28);
    $|    border-radius: var(--radius);
    $|    background: rgba(10, 16, 26, 0.78);
    $|    box-shadow: 0 28px 80px rgba(0, 0, 0, 0.52), 0 0 36px rgba(125, 211, 252, 0.14);
    $|    backdrop-filter: blur(18px) saturate(145%);
    $|  }
    $|
    $|  .node-modal:focus {
    $|    outline: 1px solid rgba(125, 211, 252, 0.55);
    $|    outline-offset: 3px;
    $|  }
    $|
    $|  .node-modal-head {
    $|    display: flex;
    $|    align-items: center;
    $|    justify-content: space-between;
    $|    gap: 14px;
    $|    min-width: 0;
    $|    padding: 15px 16px;
    $|    border-bottom: 1px solid var(--border-subtle);
    $|    background: rgba(15, 23, 42, 0.46);
    $|  }
    $|
    $|  .node-modal-heading {
    $|    min-width: 0;
    $|  }
    $|
    $|  .node-modal-title {
    $|    margin: 0;
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    color: var(--text-primary);
    $|    font-size: 15px;
    $|    font-weight: 700;
    $|  }
    $|
    $|  .node-modal-subtitle {
    $|    margin: 4px 0 0;
    $|    overflow: hidden;
    $|    text-overflow: ellipsis;
    $|    white-space: nowrap;
    $|    color: var(--text-muted);
    $|    font-size: 11px;
    $|  }
    $|
    $|  .node-modal-close {
    $|    flex: 0 0 auto;
    $|  }
    $|
    $|  .node-modal-body {
    $|    min-height: 0;
    $|    overflow: auto;
    $|    padding: 16px;
    $|  }
    $|
    $|  .node-modal-body .detail-title {
    $|    font-size: 17px;
    $|  }
    $|
    $|  .node-modal-body .kv {
    $|    grid-template-columns: 92px minmax(0, 1fr);
    $|  }
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
    $|  .kv.kv-wide {
    $|    grid-template-columns: minmax(0, 1fr);
    $|  }
    $|
    $|  .kv.kv-wide > strong {
    $|    margin-bottom: 2px;
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
    $|  .task-detail-list {
    $|    display: grid;
    $|    gap: 8px;
    $|  }
    $|
    $|  .task-detail {
    $|    overflow: hidden;
    $|    border: 1px solid var(--border-subtle);
    $|    border-radius: var(--radius);
    $|    background: rgba(15, 23, 42, 0.58);
    $|  }
    $|
    $|  .task-detail[open] {
    $|    border-color: rgba(148, 163, 184, 0.28);
    $|  }
    $|
    $|  .task-detail summary {
    $|    display: grid;
    $|    gap: 6px;
    $|    padding: 9px;
    $|    cursor: pointer;
    $|    list-style: none;
    $|  }
    $|
    $|  .task-detail summary::-webkit-details-marker { display: none; }
    $|
    $|  .task-summary-main {
    $|    display: flex;
    $|    align-items: center;
    $|    justify-content: space-between;
    $|    gap: 8px;
    $|    min-width: 0;
    $|  }
    $|
    $|  .task-title {
    $|    min-width: 0;
    $|    overflow-wrap: anywhere;
    $|    color: var(--text-primary);
    $|    font-size: 12px;
    $|    font-weight: 650;
    $|  }
    $|
    $|  .task-id {
    $|    color: var(--text-dimmed);
    $|    font: 10px ui-monospace, SFMono-Regular, Menlo, monospace;
    $|    overflow-wrap: anywhere;
    $|  }
    $|
    $|  .task-status {
    $|    flex: 0 0 auto;
    $|    display: inline-flex;
    $|    align-items: center;
    $|    gap: 5px;
    $|    color: var(--task-color, var(--text-secondary));
    $|    font-size: 10px;
    $|  }
    $|
    $|  .task-detail-body {
    $|    display: grid;
    $|    gap: 0;
    $|    padding: 0 9px 9px;
    $|  }
    $|
    $|  .task-field {
    $|    display: grid;
    $|    grid-template-columns: 58px minmax(0, 1fr);
    $|    gap: 8px;
    $|    padding: 7px 0;
    $|    border-top: 1px solid var(--border-subtle);
    $|    color: var(--text-muted);
    $|    font-size: 11px;
    $|  }
    $|
    $|  .task-field strong {
    $|    color: var(--text-dimmed);
    $|    font-weight: 600;
    $|  }
    $|
    $|  .task-field span {
    $|    min-width: 0;
    $|    overflow-wrap: anywhere;
    $|    color: var(--text-secondary);
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
    $|    .node-modal-backdrop { padding: 10px; }
    $|    .node-modal { width: calc(100vw - 20px); max-height: calc(100vh - 20px); }
    $|    .node-modal-body { padding: 12px; }
    $|    .node-modal-body .kv { grid-template-columns: minmax(0, 1fr); gap: 4px; }
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
    $|      <div class="metric"><b id="metric-deps">0</b><span>连线</span></div>
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
    $|        <div class="control-stack">
    $|          <input class="search-input" id="goal-search" type="search" placeholder="搜索 goal / owner / milestone" aria-label="搜索 goal" />
    $|          <select class="select-input" id="product-filter" aria-label="产品筛选">
    $|            <option value="all">全部产品</option>
    $|          </select>
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
    $|          <button class="filter-button" data-filter="focus" type="button">焦点</button>
    $|          <button class="filter-button" data-filter="active" type="button">进行中</button>
    $|          <button class="filter-button" data-filter="archived" type="button">封档</button>
    $|        </div>
    $|        <div class="toolbar" aria-label="Map controls">
    $|          <button class="icon-button" id="reset-layout" type="button">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v6h6"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="zoom-in" type="button" aria-label="放大">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="zoom-out" type="button" aria-label="缩小">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M5 12h14"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="fit-view" type="button" aria-label="适配视图">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg>
    $|          </button>
    $|          <button class="icon-button" id="clear-focus" type="button" aria-label="清除聚焦">
    $|            <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
    $|          </button>
    $|        </div>
    $|      </div>
    $|      <div class="canvas-wrap">
    $|        <canvas id="map-canvas"></canvas>
    $|      </div>
    $|      <div class="legend">
    $|        <div class="legend-group" id="legend-closure"></div>
    $|        <div class="legend-group">
    $|          <span class="legend-chip"><i class="legend-shape" style="width:28px;height:2px;--legend-color:#fcd34d;--legend-glow:rgba(252,211,77,.55)"></i>目标依赖</span>
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
    $|<div class="node-tooltip" id="node-tooltip" role="tooltip" hidden></div>
    $|<div class="node-modal-backdrop" id="node-detail-modal" hidden>
    $|  <section class="node-modal" role="dialog" aria-modal="true" aria-labelledby="node-modal-title" tabindex="-1">
    $|    <div class="node-modal-head">
    $|      <div class="node-modal-heading">
    $|        <h2 class="node-modal-title" id="node-modal-title">节点详情</h2>
    $|        <p class="node-modal-subtitle" id="node-modal-subtitle"></p>
    $|      </div>
    $|      <button class="icon-button node-modal-close" id="node-modal-close" type="button" aria-label="关闭详情">
    $|        <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
    $|      </button>
    $|    </div>
    $|    <div class="node-modal-body" id="node-modal-body"></div>
    $|  </section>
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
  #|  const nodeTooltip = document.getElementById('node-tooltip');
  #|  const nodeModal = document.getElementById('node-detail-modal');
  #|  const nodeModalPanel = nodeModal ? nodeModal.querySelector('.node-modal') : null;
  #|  const nodeModalTitle = document.getElementById('node-modal-title');
  #|  const nodeModalSubtitle = document.getElementById('node-modal-subtitle');
  #|  const nodeModalBody = document.getElementById('node-modal-body');
  #|  const nodeModalClose = document.getElementById('node-modal-close');
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
  #|  const DEFAULT_CONFIG = {
  #|    products: [{ key: 'default', label: { en: 'Default', zh: '默认' } }],
  #|    closure_tiers: [
  #|      { key: 'seed', label: { en: 'Proposed', zh: '提出' }, color: '#94a3b8', trigger: { en: 'issue / discussion created', zh: 'issue / discussion 已创建' } },
  #|      { key: 'obligation', label: { en: 'Claimed', zh: '接手' }, color: '#38bdf8', trigger: { en: 'assignee set', zh: 'assignee 字段非空' } },
  #|      { key: 'scoped', label: { en: 'Designed', zh: '设计完' }, color: '#a78bfa', trigger: { en: 'RFC / ADR / design doc merged', zh: 'RFC / ADR / 设计 doc merged' } },
  #|      { key: 'public', label: { en: 'Committed', zh: '已承诺' }, color: '#fdba74', trigger: { en: 'external commitment published', zh: '对外承诺已发' } },
  #|      { key: 'bridged', label: { en: 'Integrated', zh: '已集成' }, color: '#2dd4bf', trigger: { en: 'up/downstream closed + smoke passed', zh: '上下游 closed + smoke 通过' } },
  #|      { key: 'mature', label: { en: 'Operating', zh: '运行中' }, color: '#34d399', trigger: { en: '30 days incident-free', zh: '30 天无 incident' } },
  #|    ],
  #|    formal_levels: [
  #|      { key: 'none', label: { en: 'No automation', zh: '无自动化' } },
  #|      { key: 'sop', label: { en: 'Has SOP / runbook', zh: '有 SOP / runbook' } },
  #|      { key: 'checked', label: { en: 'Has CI / tests', zh: '有自动化测试 / CI' } },
  #|      { key: 'audited', label: { en: 'Has monitoring + SLO', zh: '有监控 / 告警 / SLO' } },
  #|    ],
  #|    focus_quarter: { label: { en: 'Current focus', zh: '当前焦点' }, border_color: '#f43f5e', border_width: 3 },
  #|    archive_rule: { after_mature_days: 30, opacity: 0.35 },
  #|    ui: { title: { en: 'Vibe Region Map', zh: 'Vibe Region Map' }, default_lang: 'zh' },
  #|  };
  #|  const CONFIG = normalizeConfig(dag.config || {});
  #|  const LANG = CONFIG.ui?.default_lang || 'zh';
  #|  const CLOSURE_BY_KEY = byKey(CONFIG.closure_tiers);
  #|  const FORMAL_BY_KEY = byKey(CONFIG.formal_levels);
  #|  const PRODUCT_BY_KEY = byKey(CONFIG.products);
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
  #|    productFilter: 'all',
  #|    search: '',
  #|    focusIds: null,
  #|    navigationPeerIds: null,
  #|    modalNodeId: null,
  #|    transform: { x: 0, y: 0, scale: 1 },
  #|    pointer: { down: false, mode: null, moved: false, lastX: 0, lastY: 0, node: null },
  #|  };
  #|
  #|  const SHORTCUTS = {
  #|    resetLayout: {
  #|      id: 'map.reset-layout',
  #|      label: 'R',
  #|      actionLabel: '刷新布局',
  #|      keys: ['r'],
  #|    },
  #|    nodeNavigation: {
  #|      id: 'map.node-navigation',
  #|      label: '方向键',
  #|      actionLabel: '切换节点',
  #|      keys: ['arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'enter'],
  #|    },
  #|    sidebarNavigation: {
  #|      id: 'map.sidebar-navigation',
  #|      label: '⌘↑/⌘↓',
  #|      actionLabel: '按左侧列表顺序切换',
  #|      keys: ['meta+arrowup', 'meta+arrowdown', 'meta+home', 'meta+end'],
  #|    },
  #|  };
  #|
  #|  function shortcutKeyLabel(key) {
  #|    const labels = {
  #|      meta: '⌘',
  #|      ctrl: 'Ctrl',
  #|      alt: 'Alt',
  #|      shift: 'Shift',
  #|      arrowup: '↑',
  #|      arrowdown: '↓',
  #|      arrowleft: '←',
  #|      arrowright: '→',
  #|      home: 'Home',
  #|      end: 'End',
  #|      enter: 'Enter',
  #|    };
  #|    return String(key || '').toLowerCase().split('+').map(part => labels[part] || part.toUpperCase()).join('');
  #|  }
  #|
  #|  function shortcutHint(shortcut) {
  #|    return shortcut.keys.map(shortcutKeyLabel).join('/');
  #|  }
  #|
  #|  function ariaShortcutKey(key) {
  #|    const names = {
  #|      meta: 'Meta',
  #|      ctrl: 'Control',
  #|      alt: 'Alt',
  #|      shift: 'Shift',
  #|      arrowup: 'ArrowUp',
  #|      arrowdown: 'ArrowDown',
  #|      arrowleft: 'ArrowLeft',
  #|      arrowright: 'ArrowRight',
  #|      home: 'Home',
  #|      end: 'End',
  #|      enter: 'Enter',
  #|    };
  #|    return String(key || '').toLowerCase().split('+').map(part => names[part] || part.toUpperCase()).join('+');
  #|  }
  #|
  #|  function ariaShortcutKeys(shortcut) {
  #|    return shortcut.keys.map(ariaShortcutKey).join(' ');
  #|  }
  #|
  #|  function normalizeConfig(raw) {
  #|    return {
  #|      ...DEFAULT_CONFIG,
  #|      ...raw,
  #|      products: Array.isArray(raw.products) && raw.products.length ? raw.products : DEFAULT_CONFIG.products,
  #|      closure_tiers: Array.isArray(raw.closure_tiers) && raw.closure_tiers.length ? raw.closure_tiers : DEFAULT_CONFIG.closure_tiers,
  #|      formal_levels: Array.isArray(raw.formal_levels) && raw.formal_levels.length ? raw.formal_levels : DEFAULT_CONFIG.formal_levels,
  #|      focus_quarter: { ...DEFAULT_CONFIG.focus_quarter, ...(raw.focus_quarter || {}) },
  #|      archive_rule: { ...DEFAULT_CONFIG.archive_rule, ...(raw.archive_rule || {}) },
  #|      ui: { ...DEFAULT_CONFIG.ui, ...(raw.ui || {}) },
  #|    };
  #|  }
  #|
  #|  function byKey(items) {
  #|    const out = new Map();
  #|    for (const item of items || []) out.set(item.key, item);
  #|    return out;
  #|  }
  #|
  #|  function localized(value, fallback) {
  #|    if (!value) return fallback || '';
  #|    if (typeof value === 'string') return value;
  #|    return value[LANG] || value.zh || value.en || fallback || '';
  #|  }
  #|
  #|  function hexToRgba(hex, alpha) {
  #|    const raw = String(hex || '').replace('#', '');
  #|    if (raw.length !== 6) return 'rgba(148,163,184,' + alpha + ')';
  #|    const n = parseInt(raw, 16);
  #|    const r = (n >> 16) & 255;
  #|    const g = (n >> 8) & 255;
  #|    const b = n & 255;
  #|    return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
  #|  }
  #|
  #|  function closureFromStatus(status) {
  #|    if (status === 'done') return 'bridged';
  #|    if (status === 'in-progress') return 'obligation';
  #|    if (status === 'blocked') return 'scoped';
  #|    return 'seed';
  #|  }
  #|
  #|  function closureMeta(key) {
  #|    const tier = CLOSURE_BY_KEY.get(key) || CONFIG.closure_tiers[0] || DEFAULT_CONFIG.closure_tiers[0];
  #|    const color = tier.color || '#94a3b8';
  #|    return {
  #|      key: tier.key || key || 'seed',
  #|      label: localized(tier.label, tier.key || key || 'seed'),
  #|      trigger: localized(tier.trigger, ''),
  #|      color,
  #|      border: color,
  #|      glow: hexToRgba(color, 0.48),
  #|    };
  #|  }
  #|
  #|  function formalMeta(key) {
  #|    const formal = FORMAL_BY_KEY.get(key) || CONFIG.formal_levels[0] || DEFAULT_CONFIG.formal_levels[0];
  #|    return {
  #|      key: formal.key || key || 'none',
  #|      label: localized(formal.label, formal.key || key || 'none'),
  #|    };
  #|  }
  #|
  #|  function productLabel(key) {
  #|    const product = PRODUCT_BY_KEY.get(key);
  #|    return product ? localized(product.label, key) : (key || 'default');
  #|  }
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
  #|    const taskOwner = new Map();
  #|    const tasksByGoal = new Map();
  #|
  #|    for (const m of milestones) {
  #|      milestoneState.set(m.id, { done: 0, total: 0, worst: 'done' });
  #|      tasksByGoal.set(m.id, []);
  #|    }
  #|
  #|    for (const issue of issues) {
  #|      const status = issue.status || 'todo';
  #|      const owner = issue.goal || issue.milestone;
  #|      taskOwner.set(issue.id, owner);
  #|      const bucket = milestoneState.get(owner);
  #|      if (!bucket) continue;
  #|      tasksByGoal.get(owner).push(issue);
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
  #|      const closureKey = m.closure || closureFromStatus(bucket.worst);
  #|      const formalKey = m.formal || ((m.tests || []).length || bucket.done > 0 ? 'checked' : 'none');
  #|      const issueCount = Number.isFinite(m.issue_count) ? m.issue_count : bucket.total;
  #|      const closure = closureMeta(closureKey);
  #|      const formal = formalMeta(formalKey);
  #|      const node = {
  #|        id: m.id,
  #|        title: m.title || m.id,
  #|        description: m.description || '',
  #|        kind: 'milestone',
  #|        status: bucket.worst,
  #|        closure: closure.key,
  #|        closureLabel: closure.label,
  #|        closureTrigger: closure.trigger,
  #|        formal: formal.key,
  #|        formalLabel: formal.label,
  #|        product: m.product || 'default',
  #|        productLabel: productLabel(m.product || 'default'),
  #|        milestone: m.milestone || '',
  #|        owner: m.owner || '',
  #|        issueCount,
  #|        focus: m.focus === true,
  #|        archived: m.archived === true,
  #|        promotedAt: m.promoted_at || {},
  #|        ghQuery: m.gh_query || '',
  #|        color: closure.color,
  #|        border: closure.border,
  #|        glow: closure.glow,
  #|        deps: m.deps || [],
  #|        docs: m.docs || [],
  #|        tests: m.tests || [],
  #|        tasks: (tasksByGoal.get(m.id) || []).map(task => ({
  #|          id: task.id,
  #|          title: task.title || task.id,
  #|          status: task.status || 'todo',
  #|          deps: task.deps || [],
  #|          notes: task.notes || '',
  #|          tests: task.tests || [],
  #|          docs: task.docs || [],
  #|          regressionTestable: !!task.regression_testable,
  #|        })),
  #|        regressionTestable: !!m.regression_testable,
  #|        progress: { done: bucket.done, total: bucket.total, pct },
  #|        radius: Math.max(40, Math.min(70, 40 + Math.sqrt(Math.max(1, issueCount)) * 5)),
  #|        x: 0,
  #|        y: 0,
  #|        vx: 0,
  #|        vy: 0,
  #|      };
  #|      nodes.push(node);
  #|      nodeById.set(node.id, node);
  #|    }
  #|
  #|    const edgeIds = new Set();
  #|    function addGoalEdge(source, target, derived) {
  #|      if (!source || !target || source === target) return;
  #|      if (!nodeById.has(source) || !nodeById.has(target)) return;
  #|      const id = source + '->' + target;
  #|      if (edgeIds.has(id)) return;
  #|      edgeIds.add(id);
  #|      edges.push({ source, target, kind: 'dep', derived });
  #|    }
  #|
  #|    for (const m of milestones) {
  #|      for (const dep of (m.deps || [])) {
  #|        addGoalEdge(dep, m.id, false);
  #|      }
  #|    }
  #|
  #|    for (const issue of issues) {
  #|      const owner = issue.goal || issue.milestone;
  #|      for (const dep of (issue.deps || [])) {
  #|        const depOwner = taskOwner.get(dep);
  #|        if (depOwner && depOwner !== owner) addGoalEdge(depOwner, owner, true);
  #|      }
  #|    }
  #|
  #|    return { nodes, edges, nodeById };
  #|  }
  #|
  #|  function seedLayout() {
  #|    const goals = [...state.nodes];
  #|    const levels = goalLevels(goals);
  #|    const byLevel = new Map();
  #|    const levelOf = new Map();
  #|    const originalOrder = new Map(goals.map((goal, index) => [goal.id, index]));
  #|    const levelGap = 320;
  #|    const rowGap = 126;
  #|    const collisionGap = 108;
  #|
  #|    for (const goal of goals) {
  #|      const level = levels.get(goal.id) || 0;
  #|      goal.level = level;
  #|      levelOf.set(goal.id, level);
  #|      if (!byLevel.has(level)) byLevel.set(level, []);
  #|      byLevel.get(level).push(goal);
  #|    }
  #|
  #|    const maxLevel = Math.max(0, ...goals.map(goal => levelOf.get(goal.id) || 0));
  #|    const levelsList = [];
  #|    for (let level = 0; level <= maxLevel; level += 1) {
  #|      levelsList[level] = byLevel.get(level) || [];
  #|    }
  #|
  #|    const incoming = new Map();
  #|    const outgoing = new Map();
  #|    for (const goal of goals) {
  #|      incoming.set(goal.id, []);
  #|      outgoing.set(goal.id, []);
  #|    }
  #|    for (const edge of state.edges.filter(edge => edge.kind === 'dep')) {
  #|      if (!state.nodeById.has(edge.source) || !state.nodeById.has(edge.target)) continue;
  #|      outgoing.get(edge.source)?.push(edge.target);
  #|      incoming.get(edge.target)?.push(edge.source);
  #|    }
  #|
  #|    function stableNodeSort(a, b) {
  #|      return (originalOrder.get(a.id) ?? 0) - (originalOrder.get(b.id) ?? 0) ||
  #|        a.title.localeCompare(b.title) ||
  #|        a.id.localeCompare(b.id);
  #|    }
  #|
  #|    for (const list of incoming.values()) list.sort((a, b) => stableNodeSort(state.nodeById.get(a), state.nodeById.get(b)));
  #|    for (const list of outgoing.values()) list.sort((a, b) => stableNodeSort(state.nodeById.get(a), state.nodeById.get(b)));
  #|
  #|    function nearestParents(node) {
  #|      const currentLevel = levelOf.get(node.id) || 0;
  #|      const parents = (incoming.get(node.id) || [])
  #|        .map(id => state.nodeById.get(id))
  #|        .filter(Boolean)
  #|        .filter(parent => (levelOf.get(parent.id) || 0) < currentLevel);
  #|      if (parents.length === 0) return [];
  #|      const nearestLevel = Math.max(...parents.map(parent => levelOf.get(parent.id) || 0));
  #|      return parents
  #|        .filter(parent => (levelOf.get(parent.id) || 0) === nearestLevel)
  #|        .sort(stableNodeSort);
  #|    }
  #|
  #|    function average(values) {
  #|      const finite = values.filter(value => Number.isFinite(value));
  #|      return finite.length
  #|        ? finite.reduce((sum, value) => sum + value, 0) / finite.length
  #|        : 0;
  #|    }
  #|
  #|    const roots = goals
  #|      .filter(goal => (levelOf.get(goal.id) || 0) === 0)
  #|      .sort(stableNodeSort);
  #|    let branchStarts = goals
  #|      .filter(goal => {
  #|        const level = levelOf.get(goal.id) || 0;
  #|        if (level === 0) return (outgoing.get(goal.id) || []).length === 0;
  #|        const parents = nearestParents(goal);
  #|        return parents.length === 0 || parents.every(parent => (levelOf.get(parent.id) || 0) === 0);
  #|      })
  #|      .sort(stableNodeSort);
  #|    if (branchStarts.length === 0) branchStarts = roots;
  #|
  #|    const idealRowById = new Map();
  #|    branchStarts.forEach((node, index) => {
  #|      idealRowById.set(node.id, (index - (branchStarts.length - 1) / 2) * rowGap);
  #|    });
  #|
  #|    const topo = [...goals].sort((a, b) => {
  #|      return (levelOf.get(a.id) || 0) - (levelOf.get(b.id) || 0) || stableNodeSort(a, b);
  #|    });
  #|    for (const goal of topo) {
  #|      if (idealRowById.has(goal.id) || (levelOf.get(goal.id) || 0) === 0) continue;
  #|      const parentRows = nearestParents(goal)
  #|        .map(parent => idealRowById.get(parent.id))
  #|        .filter(value => Number.isFinite(value));
  #|      idealRowById.set(goal.id, parentRows.length ? average(parentRows) : 0);
  #|    }
  #|
  #|    for (const root of roots) {
  #|      const childRows = (outgoing.get(root.id) || [])
  #|        .map(id => idealRowById.get(id))
  #|        .filter(value => Number.isFinite(value));
  #|      idealRowById.set(root.id, childRows.length ? average(childRows) : (idealRowById.get(root.id) || 0));
  #|    }
  #|
  #|    function relaxedRows(list) {
  #|      const sorted = [...list].sort((a, b) => {
  #|        return (idealRowById.get(a.id) || 0) - (idealRowById.get(b.id) || 0) || stableNodeSort(a, b);
  #|      });
  #|      const rows = new Map();
  #|      if (sorted.length === 0) return rows;
  #|      const desiredCenter = average(sorted.map(node => idealRowById.get(node.id) || 0));
  #|      let lastY = -Infinity;
  #|      for (const node of sorted) {
  #|        const desired = idealRowById.get(node.id) || 0;
  #|        const y = Math.max(desired, lastY + collisionGap);
  #|        rows.set(node.id, y);
  #|        lastY = y;
  #|      }
  #|      const values = sorted.map(node => rows.get(node.id));
  #|      const actualCenter = (values[0] + values[values.length - 1]) / 2;
  #|      const shift = desiredCenter - actualCenter;
  #|      for (const node of sorted) rows.set(node.id, rows.get(node.id) + shift);
  #|      return rows;
  #|    }
  #|
  #|    for (const [level, list] of levelsList.entries()) {
  #|      const rows = relaxedRows(list);
  #|      list.forEach(goal => {
  #|        goal.x = level * levelGap;
  #|        goal.y = rows.get(goal.id) ?? (idealRowById.get(goal.id) || 0);
  #|        goal.layoutRow = idealRowById.get(goal.id) || 0;
  #|      });
  #|    }
  #|
  #|    centerGraph();
  #|  }
  #|
  #|  function goalLevels(goals) {
  #|    const memo = new Map();
  #|    const visiting = new Set();
  #|
  #|    function levelFor(goal) {
  #|      if (memo.has(goal.id)) return memo.get(goal.id);
  #|      if (visiting.has(goal.id)) return 0;
  #|      visiting.add(goal.id);
  #|      let level = 0;
  #|      const incoming = state.edges.filter(edge => edge.target === goal.id);
  #|      for (const edge of incoming) {
  #|        const depGoal = state.nodeById.get(edge.source);
  #|        if (depGoal) level = Math.max(level, levelFor(depGoal) + 1);
  #|      }
  #|      visiting.delete(goal.id);
  #|      memo.set(goal.id, level);
  #|      return level;
  #|    }
  #|
  #|    goals.forEach(levelFor);
  #|    return memo;
  #|  }
  #|
  #|  function centerGraph() {
  #|    const bounds = boundsFor(state.nodes);
  #|    if (!bounds) return;
  #|    const centerX = bounds.minX + bounds.width / 2;
  #|    const centerY = bounds.minY + bounds.height / 2;
  #|    for (const node of state.nodes) {
  #|      node.x -= centerX;
  #|      node.y -= centerY;
  #|    }
  #|  }
  #|
  #|  function applyFilter() {
  #|    const activeStatuses = new Set(['in-progress', 'blocked']);
  #|    let visible = state.nodes.filter(node => {
  #|      if (state.filter === 'focus' && !node.focus) return false;
  #|      if (state.filter === 'archived' && !node.archived) return false;
  #|      if (state.filter === 'active' && !activeStatuses.has(node.status)) return false;
  #|      if (state.productFilter !== 'all' && node.product !== state.productFilter) return false;
  #|      if (state.search) {
  #|        const haystack = [node.id, node.title, node.owner, node.milestone, node.productLabel, node.closureLabel].join(' ').toLowerCase();
  #|        if (!haystack.includes(state.search)) return false;
  #|      }
  #|      return true;
  #|    });
  #|
  #|    const visibleIds = new Set(visible.map(n => n.id));
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
  #|    const fitScale = Math.min(width / bounds.width, height / bounds.height) * 0.92;
  #|    const scale = Math.max(0.58, Math.min(1.8, fitScale));
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
  #|  function hideNodeTooltip() {
  #|    if (nodeTooltip) nodeTooltip.hidden = true;
  #|  }
  #|
  #|  function showNodeTooltip(node, clientX, clientY) {
  #|    if (!nodeTooltip || !node) return;
  #|    nodeTooltip.textContent = node.title || node.id;
  #|    nodeTooltip.hidden = false;
  #|    const margin = 12;
  #|    const offset = 14;
  #|    const rect = nodeTooltip.getBoundingClientRect();
  #|    let left = clientX + offset;
  #|    let top = clientY + offset;
  #|    if (left + rect.width + margin > window.innerWidth) {
  #|      left = clientX - rect.width - offset;
  #|    }
  #|    if (top + rect.height + margin > window.innerHeight) {
  #|      top = clientY - rect.height - offset;
  #|    }
  #|    nodeTooltip.style.left = Math.max(margin, left) + 'px';
  #|    nodeTooltip.style.top = Math.max(margin, top) + 'px';
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
  #|  function drawNodePath(node, r) {
  #|    ctx.beginPath();
  #|    ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
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
  #|    const isFocused = state.focusIds && state.focusIds.has(source.id) && state.focusIds.has(target.id);
  #|    const isDimmed = state.focusIds && !isFocused;
  #|    const forward = target.x >= source.x;
  #|    const sourceSide = forward ? 1 : -1;
  #|    const targetSide = forward ? -1 : 1;
  #|    const startX = source.x + sourceSide * (source.radius + 5);
  #|    const startY = source.y;
  #|    const endX = target.x + targetSide * (target.radius + 13);
  #|    const endY = target.y;
  #|    const midX = forward
  #|      ? Math.max(startX + 42, (startX + endX) / 2)
  #|      : Math.min(startX - 42, (startX + endX) / 2);
  #|    const levelSpan = Math.abs((target.level || 0) - (source.level || 0));
  #|    const skipLevel = levelSpan > 1;
  #|    const sameRow = Math.abs(endY - startY) < 8;
  #|    const bendSign = sameRow
  #|      ? (endY >= 0 ? -1 : 1)
  #|      : (endY > startY ? -1 : 1);
  #|    const bend = skipLevel ? bendSign * Math.min(88, 38 + (levelSpan - 1) * 24) : 0;
  #|    const control1X = midX;
  #|    const control1Y = startY + bend;
  #|    const control2X = midX;
  #|    const control2Y = endY + bend;
  #|    const color = edge.derived ? '#bae6fd' : '#fcd34d';
  #|    const glow = edge.derived ? 'rgba(186,230,253,0.58)' : 'rgba(252,211,77,0.75)';
  #|
  #|    ctx.save();
  #|    ctx.globalAlpha = isDimmed ? 0.12 : 0.95;
  #|    ctx.lineWidth = isFocused ? 4 : 2.8;
  #|    ctx.strokeStyle = isFocused ? '#fcd34d' : color;
  #|    ctx.shadowColor = isFocused ? 'rgba(252,211,77,0.9)' : glow;
  #|    ctx.shadowBlur = isFocused ? 20 : 14;
  #|    ctx.beginPath();
  #|    ctx.moveTo(startX, startY);
  #|    ctx.bezierCurveTo(control1X, control1Y, control2X, control2Y, endX, endY);
  #|    ctx.stroke();
  #|    ctx.setLineDash([]);
  #|
  #|    const pulse = isFocused ? 1 + Math.sin(time / 190) * 0.12 : 1;
  #|    const arrowSize = 11 * pulse;
  #|    drawArrow(endX, endY, Math.atan2(endY - control2Y, endX - control2X), arrowSize, isFocused ? '#fcd34d' : color);
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
  #|    const meta = { color: node.color, border: node.border, glow: node.glow, opacity: 1 };
  #|    const selected = node.id === state.selectedId;
  #|    const hovered = node.id === state.hoveredId;
  #|    const focused = state.focusIds ? state.focusIds.has(node.id) : true;
  #|    const archiveOpacity = node.archived ? (CONFIG.archive_rule?.opacity ?? 0.35) : 1;
  #|    const dim = state.focusIds && !focused ? 0.16 : archiveOpacity;
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
  #|    drawNodePath(node, radius);
  #|    ctx.fillStyle = gradient;
  #|    ctx.fill();
  #|    ctx.shadowBlur = 0;
  #|    ctx.strokeStyle = node.focus ? (CONFIG.focus_quarter?.border_color || '#f43f5e') : (selected ? '#fcd34d' : meta.border);
  #|    ctx.lineWidth = node.focus ? (CONFIG.focus_quarter?.border_width || 3) : (selected ? 3.2 : 2);
  #|    ctx.stroke();
  #|
  #|    if (selected || hovered) {
  #|      ctx.globalAlpha = selected ? 0.88 : 0.5;
  #|      ctx.strokeStyle = selected ? '#fcd34d' : 'rgba(248,250,252,0.7)';
  #|      ctx.lineWidth = selected ? 2.4 : 1.5;
  #|      drawNodePath(node, radius + (selected ? 9 : 6));
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
  #|    const lines = roundedTextLines(node.title || node.id, node.kind === 'milestone' ? 11 : 10);
  #|    ctx.font = '700 11px Inter, system-ui, sans-serif';
  #|    ctx.fillText(lines[0], node.x, lines[1] ? node.y - 5 : node.y + 1);
  #|    if (lines[1]) ctx.fillText(lines[1], node.x, node.y + 10);
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
  #|    state.navigationPeerIds = null;
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
  #|    const edgeCount = state.edges.length;
  #|    const done = dagTasks.filter(i => i.status === 'done').length;
  #|    const pct = issues > 0 ? Math.round((done / issues) * 100) : 0;
  #|    document.getElementById('title').textContent = dag.project?.name || localized(CONFIG.ui?.title, 'vibe-map');
  #|    document.getElementById('desc').textContent = dag.project?.description || '';
  #|    document.getElementById('metric-progress').textContent = pct + '%';
  #|    document.getElementById('metric-milestones').textContent = String(milestones);
  #|    document.getElementById('metric-issues').textContent = String(issues);
  #|    document.getElementById('metric-deps').textContent = String(edgeCount);
  #|    document.getElementById('overall-progress-label').textContent = done + '/' + issues;
  #|    document.getElementById('overall-progress-bar').style.width = pct + '%';
  #|    const closureSummary = CONFIG.closure_tiers
  #|      .map(tier => {
  #|        const n = state.nodes.filter(node => node.closure === tier.key).length;
  #|        return n ? localized(tier.label, tier.key) + ' ' + n : '';
  #|      })
  #|      .filter(Boolean)
  #|      .join(' / ');
  #|    document.getElementById('overview-subtitle').textContent = milestones + ' 个目标，' + issues + ' 个任务' + (closureSummary ? ' · ' + closureSummary : '');
  #|    document.getElementById('canvas-subtitle').textContent = 'n=' + state.nodes.length + ' e=' + edgeCount + ' dep=' + depCount;
  #|  }
  #|
  #|  function renderMilestoneList() {
  #|    const list = document.getElementById('milestone-list');
  #|    const milestones = state.visibleNodes.filter(n => n.kind === 'milestone');
  #|    if (milestones.length === 0) {
  #|      list.innerHTML = '<div class="detail-empty">无匹配目标</div>';
  #|      return;
  #|    }
  #|    list.innerHTML = milestones.map(node => {
  #|      const progress = node.progress ? node.progress.done + '/' + node.progress.total + ' · ' + node.progress.pct + '%' : '';
  #|      return `
  #|        <button class="node-row ${node.id === state.selectedId ? 'active' : ''}" type="button" data-node-id="${escapeHtml(node.id)}">
  #|          <div class="node-row-title">${escapeHtml(node.title)}</div>
  #|          <div class="node-row-meta">
  #|            <i class="status-dot" style="--dot:${node.color};--dot-glow:${node.glow}"></i>
  #|            <span>${escapeHtml(node.closureLabel)}</span>
  #|            <span>${escapeHtml(node.productLabel)}</span>
  #|            ${node.owner ? '<span>@' + escapeHtml(node.owner) + '</span>' : ''}
  #|            <span>${escapeHtml(progress)}</span>
  #|          </div>
  #|        </button>`;
  #|    }).join('');
  #|    list.querySelectorAll('[data-node-id]').forEach(button => {
  #|      button.addEventListener('click', () => selectNode(button.getAttribute('data-node-id'), true));
  #|    });
  #|  }
  #|
  #|  function renderProductFilter() {
  #|    const select = document.getElementById('product-filter');
  #|    const used = new Set(state.nodes.map(node => node.product));
  #|    const options = ['<option value="all">全部产品</option>'];
  #|    for (const product of CONFIG.products) {
  #|      if (used.has(product.key)) {
  #|        options.push('<option value="' + escapeHtml(product.key) + '">' + escapeHtml(localized(product.label, product.key)) + '</option>');
  #|      }
  #|    }
  #|    select.innerHTML = options.join('');
  #|    select.value = state.productFilter;
  #|  }
  #|
  #|  function renderLegend() {
  #|    const closure = document.getElementById('legend-closure');
  #|    closure.innerHTML = CONFIG.closure_tiers.map(tier => {
  #|      const color = tier.color || '#94a3b8';
  #|      return '<span class="legend-chip"><i class="legend-shape circle" style="--legend-color:' + escapeHtml(color) + ';--legend-glow:' + escapeHtml(hexToRgba(color, 0.45)) + '"></i>' + escapeHtml(localized(tier.label, tier.key)) + '</span>';
  #|    }).join('');
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
  #|  function taskDetails(tasks) {
  #|    if (!tasks || tasks.length === 0) return '<span>暂无任务</span>';
  #|    return '<div class="task-detail-list">' + tasks.map(task => {
  #|      const meta = statusMeta(task.status);
  #|      const title = task.title || task.id;
  #|      const notes = task.notes || '未记录';
  #|      return `
  #|        <details class="task-detail">
  #|          <summary>
  #|            <div class="task-summary-main">
  #|              <span class="task-title">${escapeHtml(title)}</span>
  #|              <span class="task-status" style="--task-color:${meta.border}">
  #|                <i class="status-dot" style="--dot:${meta.color};--dot-glow:${meta.glow}"></i>${escapeHtml(meta.label)}
  #|              </span>
  #|            </div>
  #|            <div class="task-id">${escapeHtml(task.id)}</div>
  #|          </summary>
  #|          <div class="task-detail-body">
  #|            <div class="task-field"><strong>依赖</strong>${chips(task.deps, '无')}</div>
  #|            <div class="task-field"><strong>Notes</strong><span>${escapeHtml(notes)}</span></div>
  #|            <div class="task-field"><strong>测试</strong>${chips(task.tests, '未记录')}</div>
  #|            <div class="task-field"><strong>文档</strong>${chips(task.docs, '未记录')}</div>
  #|            <div class="task-field"><strong>质量</strong><span>${task.regressionTestable ? 'regression-testable' : '未标记'}</span></div>
  #|          </div>
  #|        </details>`;
  #|    }).join('') + '</div>';
  #|  }
  #|
  #|  function promotedTimeline(node) {
  #|    const promoted = node.promotedAt || {};
  #|    const pieces = [];
  #|    for (const tier of CONFIG.closure_tiers) {
  #|      if (promoted[tier.key]) {
  #|        pieces.push(localized(tier.label, tier.key) + ' ' + promoted[tier.key]);
  #|      }
  #|    }
  #|    return pieces;
  #|  }
  #|
  #|  function nodeDetailSubtitle(node) {
  #|    return node.closureLabel + (node.owner ? ' · @' + node.owner : '');
  #|  }
  #|
  #|  function nodeDetailsHtml(node) {
  #|    const status = statusMeta(node.status);
  #|    const inbound = relatedIds(node.id, 'in');
  #|    const outbound = relatedIds(node.id, 'out');
  #|    const goalTasks = node.tasks || [];
  #|    const timeline = promotedTimeline(node);
  #|
  #|    return `
  #|      <div class="detail-stack">
  #|        <div>
  #|          <div class="detail-id">${escapeHtml(node.id)}</div>
  #|          <h3 class="detail-title">${escapeHtml(node.title)}</h3>
  #|        </div>
  #|        <div class="badge-row">
  #|          <span class="badge" style="border-color:${node.border};color:${node.border}">${escapeHtml(node.closureLabel)}</span>
  #|          <span class="badge">${escapeHtml(node.formalLabel)}</span>
  #|          <span class="badge">${escapeHtml(node.productLabel)}</span>
  #|          <span class="badge" style="border-color:${status.border};color:${status.border}">${escapeHtml(status.label)}</span>
  #|          ${node.focus ? '<span class="badge" style="border-color:#f43f5e;color:#fda4af">当前焦点</span>' : ''}
  #|          ${node.archived ? '<span class="badge">封档</span>' : ''}
  #|          ${node.regressionTestable ? '<span class="badge">regression-testable</span>' : ''}
  #|        </div>
  #|        ${node.description ? '<div class="notes">' + escapeHtml(node.description) + '</div>' : ''}
  #|        ${node.progress ? '<div class="progress-row"><label><span>完成</span><span>' + node.progress.done + '/' + node.progress.total + ' · ' + node.progress.pct + '%</span></label><div class="progress"><span style="width:' + node.progress.pct + '%"></span></div></div>' : ''}
  #|        <div class="kv"><strong>Owner</strong><span>${escapeHtml(node.owner || '未记录')}</span></div>
  #|        <div class="kv"><strong>产品</strong><span>${escapeHtml(node.productLabel)}</span></div>
  #|        <div class="kv"><strong>Milestone</strong><span>${escapeHtml(node.milestone || '未记录')}</span></div>
  #|        <div class="kv"><strong>Issue 数</strong><span>${escapeHtml(String(node.issueCount || 0))}</span></div>
  #|        <div class="kv"><strong>Trigger</strong><span>${escapeHtml(node.closureTrigger || '未记录')}</span></div>
  #|        <div class="kv"><strong>推进</strong>${chips(timeline, '未记录')}</div>
  #|        <div class="kv"><strong>依赖</strong>${chips(inbound, '无')}</div>
  #|        <div class="kv"><strong>被依赖</strong>${chips(outbound, '无')}</div>
  #|        <div class="kv kv-wide"><strong>任务详情</strong>${taskDetails(goalTasks)}</div>
  #|        <div class="kv"><strong>测试</strong>${chips(node.tests, '未记录')}</div>
  #|        <div class="kv"><strong>文档</strong>${chips(node.docs, '未记录')}</div>
  #|        <div class="kv"><strong>GitHub</strong><span>${escapeHtml(node.ghQuery || '未记录')}</span></div>
  #|      </div>`;
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
  #|    subtitle.textContent = nodeDetailSubtitle(node);
  #|    panel.innerHTML = nodeDetailsHtml(node);
  #|  }
  #|
  #|  function isNodeModalOpen() {
  #|    return !!nodeModal && !nodeModal.hidden;
  #|  }
  #|
  #|  function openNodeModal(id) {
  #|    const node = id ? state.nodeById.get(id) : null;
  #|    if (!node || !nodeModal || !nodeModalBody) return;
  #|    state.modalNodeId = node.id;
  #|    if (nodeModalTitle) nodeModalTitle.textContent = node.title || node.id;
  #|    if (nodeModalSubtitle) nodeModalSubtitle.textContent = nodeDetailSubtitle(node);
  #|    nodeModalBody.innerHTML = nodeDetailsHtml(node);
  #|    nodeModal.hidden = false;
  #|    requestAnimationFrame(() => {
  #|      if (nodeModalPanel) {
  #|        try {
  #|          nodeModalPanel.focus({ preventScroll: true });
  #|        } catch (_) {
  #|          nodeModalPanel.focus();
  #|        }
  #|      }
  #|    });
  #|  }
  #|
  #|  function closeNodeModal() {
  #|    state.modalNodeId = null;
  #|    if (nodeModal) nodeModal.hidden = true;
  #|    if (nodeModalBody) nodeModalBody.innerHTML = '';
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
  #|    renderStats();
  #|    renderMilestoneList();
  #|    fitView(true);
  #|  }
  #|
  #|  function updateSearch(value) {
  #|    state.search = String(value || '').trim().toLowerCase();
  #|    applyFilter();
  #|    if (state.selectedId && !state.visibleNodes.some(n => n.id === state.selectedId)) {
  #|      selectNode(null, false);
  #|    }
  #|    renderStats();
  #|    renderMilestoneList();
  #|    fitView(true);
  #|  }
  #|
  #|  function updateProductFilter(value) {
  #|    state.productFilter = value || 'all';
  #|    applyFilter();
  #|    if (state.selectedId && !state.visibleNodes.some(n => n.id === state.selectedId)) {
  #|      selectNode(null, false);
  #|    }
  #|    renderStats();
  #|    renderMilestoneList();
  #|    fitView(true);
  #|  }
  #|
  #|  function resetLayout() {
  #|    state.filter = 'all';
  #|    state.productFilter = 'all';
  #|    state.search = '';
  #|    state.selectedId = null;
  #|    state.hoveredId = null;
  #|    state.focusIds = null;
  #|    state.navigationPeerIds = null;
  #|    closeNodeModal();
  #|    state.pointer = { down: false, mode: null, moved: false, lastX: 0, lastY: 0, node: null };
  #|    document.querySelectorAll('.filter-button').forEach(button => {
  #|      button.classList.toggle('active', button.getAttribute('data-filter') === 'all');
  #|    });
  #|    const search = document.getElementById('goal-search');
  #|    const product = document.getElementById('product-filter');
  #|    if (search) search.value = '';
  #|    if (product) product.value = 'all';
  #|    seedLayout();
  #|    applyFilter();
  #|    renderStats();
  #|    renderDetails();
  #|    renderMilestoneList();
  #|    fitView(true);
  #|  }
  #|
  #|  function isTypingTarget(target) {
  #|    if (!target || !(target instanceof Element)) return false;
  #|    const tag = target.tagName.toLowerCase();
  #|    const role = target.getAttribute('role');
  #|    return tag === 'input' ||
  #|      tag === 'textarea' ||
  #|      tag === 'select' ||
  #|      target.isContentEditable ||
  #|      role === 'textbox';
  #|  }
  #|
  #|  function matchesShortcut(event, shortcut) {
  #|    const eventKey = shortcutEventKey(event);
  #|    return shortcut.keys.some(rawKey => {
  #|      const parts = String(rawKey || '').toLowerCase().split('+').filter(Boolean);
  #|      const key = parts.pop();
  #|      const want = {
  #|        ctrl: parts.includes('ctrl') || parts.includes('control'),
  #|        alt: parts.includes('alt') || parts.includes('option'),
  #|        meta: parts.includes('meta') || parts.includes('cmd') || parts.includes('command'),
  #|        shift: parts.includes('shift'),
  #|      };
  #|      return eventKey === key &&
  #|        event.ctrlKey === want.ctrl &&
  #|        event.altKey === want.alt &&
  #|        event.metaKey === want.meta &&
  #|        event.shiftKey === want.shift;
  #|    });
  #|  }
  #|
  #|  function shortcutEventKey(event) {
  #|    const key = String(event.key || '').toLowerCase();
  #|    if (key === 'up') return 'arrowup';
  #|    if (key === 'down') return 'arrowdown';
  #|    if (key === 'left') return 'arrowleft';
  #|    if (key === 'right') return 'arrowright';
  #|    if (key && key !== 'unidentified') return key;
  #|    return String(event.code || '').toLowerCase();
  #|  }
  #|
  #|  function nodeSortKey(a, b) {
  #|    return a.y - b.y || a.x - b.x || a.title.localeCompare(b.title) || a.id.localeCompare(b.id);
  #|  }
  #|
  #|  function sidebarNodes() {
  #|    return state.visibleNodes.filter(node => node.kind === 'milestone');
  #|  }
  #|
  #|  function selectAndRevealNode(id, peerNodes) {
  #|    selectNode(id, true);
  #|    state.navigationPeerIds = Array.isArray(peerNodes) ? peerNodes.map(node => node.id) : null;
  #|    requestAnimationFrame(() => {
  #|      const list = document.getElementById('milestone-list');
  #|      const row = list ? [...list.querySelectorAll('[data-node-id]')].find(item => item.getAttribute('data-node-id') === id) : null;
  #|      if (row) row.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  #|    });
  #|  }
  #|
  #|  function selectSidebarNodeByOrder(direction) {
  #|    const nodes = sidebarNodes();
  #|    if (nodes.length === 0) return false;
  #|    let index = state.selectedId ? nodes.findIndex(node => node.id === state.selectedId) : -1;
  #|    if (index === -1) {
  #|      index = direction === 'up' ? nodes.length : -1;
  #|    }
  #|    const delta = direction === 'up' ? -1 : 1;
  #|    const target = nodes[(index + delta + nodes.length) % nodes.length];
  #|    selectAndRevealNode(target.id);
  #|    return true;
  #|  }
  #|
  #|  function relatedVisibleNodes(id, direction) {
  #|    const seen = new Set();
  #|    const nodes = [];
  #|    for (const edge of state.visibleEdges) {
  #|      if (edge.kind !== 'dep') continue;
  #|      const relatedId = direction === 'out'
  #|        ? (edge.source === id ? edge.target : null)
  #|        : (edge.target === id ? edge.source : null);
  #|      if (!relatedId || seen.has(relatedId)) continue;
  #|      const node = state.nodeById.get(relatedId);
  #|      if (!node) continue;
  #|      seen.add(relatedId);
  #|      nodes.push(node);
  #|    }
  #|    nodes.sort(nodeSortKey);
  #|    return nodes;
  #|  }
  #|
  #|  function visiblePeerNodes() {
  #|    if (!Array.isArray(state.navigationPeerIds)) return [];
  #|    const visibleIds = new Set(state.visibleNodes.map(node => node.id));
  #|    return state.navigationPeerIds
  #|      .filter(id => visibleIds.has(id))
  #|      .map(id => state.nodeById.get(id))
  #|      .filter(Boolean);
  #|  }
  #|
  #|  function selectRelatedNode(direction) {
  #|    if (!state.selectedId) return false;
  #|    const candidates = relatedVisibleNodes(state.selectedId, direction);
  #|    if (candidates.length === 0) return false;
  #|    selectAndRevealNode(candidates[0].id, candidates);
  #|    return true;
  #|  }
  #|
  #|  function selectPeerNode(direction) {
  #|    const current = state.selectedId ? state.nodeById.get(state.selectedId) : null;
  #|    if (!current) return false;
  #|    const peers = visiblePeerNodes();
  #|    if (peers.length <= 1 || !peers.some(node => node.id === current.id)) {
  #|      const outbound = relatedVisibleNodes(current.id, 'out');
  #|      if (outbound.length > 0) {
  #|        const target = direction === 'up' ? outbound[outbound.length - 1] : outbound[0];
  #|        selectAndRevealNode(target.id, outbound);
  #|        return true;
  #|      }
  #|      const inbound = relatedVisibleNodes(current.id, 'in');
  #|      if (inbound.length > 0) {
  #|        const target = direction === 'up' ? inbound[inbound.length - 1] : inbound[0];
  #|        selectAndRevealNode(target.id, inbound);
  #|        return true;
  #|      }
  #|      return false;
  #|    }
  #|    let index = peers.findIndex(node => node.id === current.id);
  #|    const delta = direction === 'up' ? -1 : 1;
  #|    const next = peers[(index + delta + peers.length) % peers.length];
  #|    if (!next || next.id === current.id) return false;
  #|    selectAndRevealNode(next.id, peers);
  #|    return true;
  #|  }
  #|
  #|  function selectFinalGoalNode() {
  #|    const nodes = sidebarNodes();
  #|    if (nodes.length === 0) return false;
  #|    const outgoing = new Set(state.visibleEdges.filter(edge => edge.kind === 'dep').map(edge => edge.source));
  #|    const candidates = nodes.filter(node => !outgoing.has(node.id));
  #|    const pool = candidates.length > 0 ? candidates : nodes;
  #|    const target = [...pool].sort((a, b) => b.x - a.x || a.y - b.y || a.title.localeCompare(b.title) || a.id.localeCompare(b.id))[0];
  #|    if (!target) return false;
  #|    selectAndRevealNode(target.id);
  #|    return true;
  #|  }
  #|
  #|  function handleNodeNavigation(event) {
  #|    const key = shortcutEventKey(event);
  #|    if ((key === 'arrowup' || key === 'arrowdown') && !state.selectedId) {
  #|      return false;
  #|    }
  #|    if (key === 'arrowup' || key === 'arrowdown') {
  #|      return selectPeerNode(key === 'arrowup' ? 'up' : 'down');
  #|    }
  #|    if (key === 'arrowright') return selectRelatedNode('out');
  #|    if (key === 'arrowleft') return selectRelatedNode('in');
  #|    if (key === 'enter') return selectFinalGoalNode();
  #|    return false;
  #|  }
  #|
  #|  function handleSidebarNavigation(event) {
  #|    const key = shortcutEventKey(event);
  #|    if (key === 'arrowup' || key === 'home') return selectSidebarNodeByOrder('up');
  #|    if (key === 'arrowdown' || key === 'end') return selectSidebarNodeByOrder('down');
  #|    return false;
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
  #|    document.getElementById('goal-search').addEventListener('input', event => updateSearch(event.target.value));
  #|    document.getElementById('product-filter').addEventListener('change', event => updateProductFilter(event.target.value));
  #|
  #|    const resetButton = document.getElementById('reset-layout');
  #|    const resetShortcut = SHORTCUTS.resetLayout;
  #|    resetButton.setAttribute('aria-label', resetShortcut.actionLabel + ' (' + shortcutHint(resetShortcut) + ')');
  #|    resetButton.setAttribute('aria-keyshortcuts', ariaShortcutKeys(resetShortcut));
  #|    resetButton.addEventListener('click', resetLayout);
  #|    const nodeNavigationShortcut = SHORTCUTS.nodeNavigation;
  #|    const sidebarNavigationShortcut = SHORTCUTS.sidebarNavigation;
  #|    canvas.setAttribute('aria-label', 'DAG 节点图');
  #|    canvas.setAttribute('aria-keyshortcuts', ariaShortcutKeys(nodeNavigationShortcut) + ' ' + ariaShortcutKeys(sidebarNavigationShortcut));
  #|    canvas.setAttribute('tabindex', '0');
  #|    document.getElementById('zoom-in').addEventListener('click', () => zoomAt((canvas.clientWidth || 800) / 2, (canvas.clientHeight || 600) / 2, 1.18));
  #|    document.getElementById('zoom-out').addEventListener('click', () => zoomAt((canvas.clientWidth || 800) / 2, (canvas.clientHeight || 600) / 2, 1 / 1.18));
  #|    document.getElementById('fit-view').addEventListener('click', () => fitView(true));
  #|    document.getElementById('clear-focus').addEventListener('click', () => selectNode(null, false));
  #|    if (nodeModalClose) nodeModalClose.addEventListener('click', closeNodeModal);
  #|    if (nodeModal) {
  #|      nodeModal.addEventListener('mousedown', event => {
  #|        if (event.target === nodeModal) closeNodeModal();
  #|      });
  #|    }
  #|
  #|    document.addEventListener('keydown', event => {
  #|      if (event.defaultPrevented || event.isComposing || event.repeat) return;
  #|      if (shortcutEventKey(event) === 'escape' && isNodeModalOpen()) {
  #|        event.preventDefault();
  #|        closeNodeModal();
  #|        return;
  #|      }
  #|      if (event.ctrlKey || event.altKey) return;
  #|      if (matchesShortcut(event, sidebarNavigationShortcut) && handleSidebarNavigation(event)) {
  #|        event.preventDefault();
  #|        return;
  #|      }
  #|      if (isTypingTarget(event.target)) return;
  #|      if (matchesShortcut(event, resetShortcut)) {
  #|        event.preventDefault();
  #|        resetLayout();
  #|        return;
  #|      }
  #|      if (matchesShortcut(event, nodeNavigationShortcut) && handleNodeNavigation(event)) {
  #|        event.preventDefault();
  #|      }
  #|    }, { capture: true });
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
  #|      hideNodeTooltip();
  #|      const rect = canvas.getBoundingClientRect();
  #|      const x = event.clientX - rect.left;
  #|      const y = event.clientY - rect.top;
  #|      const node = hitTest(x, y);
  #|      state.pointer = { down: true, mode: node ? 'node' : 'pan', moved: false, lastX: x, lastY: y, node };
  #|      canvas.classList.add('dragging');
  #|    });
  #|
  #|    canvas.addEventListener('dblclick', event => {
  #|      if (event.button !== 0) return;
  #|      const rect = canvas.getBoundingClientRect();
  #|      const x = event.clientX - rect.left;
  #|      const y = event.clientY - rect.top;
  #|      const node = hitTest(x, y);
  #|      if (!node) return;
  #|      event.preventDefault();
  #|      hideNodeTooltip();
  #|      selectNode(node.id, false);
  #|      openNodeModal(node.id);
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
  #|        if (hover) {
  #|          showNodeTooltip(hover, event.clientX, event.clientY);
  #|        } else {
  #|          hideNodeTooltip();
  #|        }
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
  #|      hideNodeTooltip();
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
  #|    renderProductFilter();
  #|    renderLegend();
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

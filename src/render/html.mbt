///|
/// Render a self-contained HTML page for the given DAG, styled like a Lean 4
/// region map: flat DAG (no compound nesting), shapes encode kind (hexagon =
/// milestone, ellipse = issue), color encodes status, opacity dims `todo`
/// nodes so the active surface pops. Bold red arrows are dependencies; thin
/// dashed grey edges are pure layout hints from a milestone to its issues.
/// Cytoscape.js is loaded from the unpkg CDN.
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
    $|<title>\{title} — vibe-map</title>
    $|<style>
    $|  html, body { margin: 0; padding: 0; height: 100%; font-family: system-ui, -apple-system, sans-serif; background: #fafafa; color: #1a1a1a; }
    $|  #app { display: grid; grid-template-rows: auto 1fr; height: 100%; }
    $|  header { padding: 12px 16px; border-bottom: 1px solid #e3e3e3; background: #fff; display: flex; align-items: center; gap: 16px; }
    $|  h1 { margin: 0; font-size: 16px; font-weight: 600; }
    $|  .desc { color: #666; font-size: 13px; }
    $|  .legend { margin-left: auto; display: flex; gap: 14px; font-size: 12px; color: #555; align-items: center; }
    $|  .legend .dot { display: inline-block; width: 10px; height: 10px; vertical-align: middle; margin-right: 4px; }
    $|  .legend .hex { width: 12px; height: 11px; clip-path: polygon(25% 0, 75% 0, 100% 50%, 75% 100%, 25% 100%, 0 50%); }
    $|  .legend .circle { border-radius: 50%; }
    $|  #cy { width: 100%; height: 100%; background: #fafafa; }
    $|  .focus-hint { position: fixed; bottom: 12px; right: 16px; font-size: 12px; color: #888; background: rgba(255,255,255,.92); padding: 6px 10px; border-radius: 4px; border: 1px solid #e3e3e3; }
    $|</style>
    $|</head>
    $|<body>
    $|<div id="app">
    $|  <header>
    $|    <h1 id="title"></h1>
    $|    <span class="desc" id="desc"></span>
    $|    <div class="legend">
    $|      <span><i class="dot hex" style="background:#7fbf7f"></i>milestone</span>
    $|      <span><i class="dot circle" style="background:#7fbf7f"></i>issue</span>
    $|      <span style="opacity:.55"><i class="dot circle" style="background:#7fbf7f"></i>done</span>
    $|      <span style="opacity:.55"><i class="dot circle" style="background:#5b9bd5"></i>in-progress</span>
    $|      <span style="opacity:.55"><i class="dot circle" style="background:#d96c6c"></i>blocked</span>
    $|      <span style="opacity:.55"><i class="dot circle" style="background:#c8c8c8"></i>todo (faded)</span>
    $|    </div>
    $|  </header>
    $|  <div id="cy"></div>
    $|</div>
    $|<div class="focus-hint">click a node → highlight its transitive deps · click background → reset</div>
    $|<script type="application/json" id="dag-data">
    $|
  head
}

///|
let page_tail : String =
  #|</script>
  #|<script src="https://unpkg.com/cytoscape@3.30.4/dist/cytoscape.min.js"></script>
  #|<script>
  #|(function () {
  #|  const raw = document.getElementById('dag-data').textContent;
  #|  const dag = JSON.parse(raw);
  #|  document.getElementById('title').textContent = dag.project.name || 'vibe-map';
  #|  document.getElementById('desc').textContent = dag.project.description || '';
  #|
  #|  // Per-milestone derived state: progress + a "worst case" status used to
  #|  // pick the hexagon's color.
  #|  const STATUS_RANK = { done: 0, todo: 1, 'in-progress': 2, blocked: 3 };
  #|  const milestoneState = {};
  #|  for (const m of dag.milestones) milestoneState[m.id] = { done: 0, total: 0, worst: 'done' };
  #|  for (const i of dag.issues) {
  #|    const s = milestoneState[i.milestone];
  #|    if (!s) continue;
  #|    s.total += 1;
  #|    if (i.status === 'done') s.done += 1;
  #|    if (STATUS_RANK[i.status] > STATUS_RANK[s.worst]) s.worst = i.status;
  #|  }
  #|  // Milestone with zero issues stays at 'todo' until something is filed.
  #|  for (const m of dag.milestones) {
  #|    const s = milestoneState[m.id];
  #|    if (s.total === 0) s.worst = 'todo';
  #|  }
  #|
  #|  const fill   = { todo: '#c8c8c8', 'in-progress': '#5b9bd5', blocked: '#d96c6c', done: '#7fbf7f' };
  #|  const border = { todo: '#9a9a9a', 'in-progress': '#2b6aa6', blocked: '#a33b3b', done: '#4f8f4f' };
  #|
  #|  const elements = [];
  #|  for (const m of dag.milestones) {
  #|    const s = milestoneState[m.id];
  #|    const pct = s.total > 0 ? Math.round((s.done / s.total) * 100) : 0;
  #|    elements.push({
  #|      data: {
  #|        id: m.id,
  #|        kind: 'milestone',
  #|        status: s.worst,
  #|        label: `${m.title}\n${s.done}/${s.total} · ${pct}%`,
  #|        title: m.title,
  #|      },
  #|    });
  #|  }
  #|  for (const i of dag.issues) {
  #|    elements.push({
  #|      data: {
  #|        id: i.id,
  #|        kind: 'issue',
  #|        status: i.status || 'todo',
  #|        milestone: i.milestone,
  #|        label: i.title,
  #|      },
  #|    });
  #|  }
  #|  // Real dependency edges — these are what the user actually drew.
  #|  for (const m of dag.milestones)
  #|    for (const d of (m.deps || []))
  #|      elements.push({ data: { id: `dep_${d}_${m.id}`, source: d, target: m.id, kind: 'dep' } });
  #|  for (const i of dag.issues)
  #|    for (const d of (i.deps || []))
  #|      elements.push({ data: { id: `dep_${d}_${i.id}`, source: d, target: i.id, kind: 'dep' } });
  #|  // Membership edges — invisible-ish, just so cose pulls an issue near its
  #|  // milestone when no inter-issue deps exist. Excluded from highlight.
  #|  for (const i of dag.issues) {
  #|    if (i.milestone) {
  #|      elements.push({
  #|        data: { id: `mem_${i.milestone}_${i.id}`, source: i.milestone, target: i.id, kind: 'member' },
  #|      });
  #|    }
  #|  }
  #|
  #|  const cy = cytoscape({
  #|    container: document.getElementById('cy'),
  #|    elements,
  #|    style: [
  #|      {
  #|        selector: 'node',
  #|        style: {
  #|          label: 'data(label)',
  #|          'text-valign': 'bottom',
  #|          'text-halign': 'center',
  #|          'text-margin-y': 6,
  #|          'text-wrap': 'wrap',
  #|          'text-max-width': 140,
  #|          'font-size': 11,
  #|          color: '#1a1a1a',
  #|          'background-color': ele => fill[ele.data('status')] || fill.todo,
  #|          'border-color': ele => border[ele.data('status')] || border.todo,
  #|          'border-width': 2,
  #|          opacity: ele => ele.data('status') === 'todo' ? 0.45 : 1.0,
  #|        },
  #|      },
  #|      {
  #|        selector: 'node[kind = "milestone"]',
  #|        style: {
  #|          shape: 'hexagon',
  #|          width: 64,
  #|          height: 56,
  #|          'font-weight': 600,
  #|          'font-size': 12,
  #|        },
  #|      },
  #|      {
  #|        selector: 'node[kind = "issue"]',
  #|        style: {
  #|          shape: 'ellipse',
  #|          width: 40,
  #|          height: 40,
  #|        },
  #|      },
  #|      {
  #|        selector: 'edge[kind = "dep"]',
  #|        style: {
  #|          width: 3,
  #|          'line-color': '#b22222',
  #|          'target-arrow-color': '#b22222',
  #|          'target-arrow-shape': 'triangle-backcurve',
  #|          'arrow-scale': 1.6,
  #|          'curve-style': 'bezier',
  #|          'target-distance-from-node': 4,
  #|          'source-distance-from-node': 2,
  #|          'z-index': 2,
  #|        },
  #|      },
  #|      {
  #|        selector: 'edge[kind = "member"]',
  #|        style: {
  #|          width: 1,
  #|          'line-color': '#d8d8d8',
  #|          'line-style': 'dashed',
  #|          'target-arrow-shape': 'none',
  #|          'curve-style': 'bezier',
  #|          opacity: 0.25,
  #|          'z-index': 1,
  #|        },
  #|      },
  #|      {
  #|        selector: '.dimmed',
  #|        style: { 'opacity': 0.08 },
  #|      },
  #|      {
  #|        selector: '.focus',
  #|        style: { 'border-width': 4, 'border-color': '#1a1a1a' },
  #|      },
  #|    ],
  #|    layout: {
  #|      name: 'cose',
  #|      animate: false,
  #|      nodeRepulsion: 22000,
  #|      idealEdgeLength: 170,
  #|      edgeElasticity: 120,
  #|      nestingFactor: 1.0,
  #|      gravity: 0.3,
  #|      numIter: 2500,
  #|      padding: 50,
  #|      randomize: false,
  #|    },
  #|    wheelSensitivity: 0.2,
  #|  });
  #|
  #|  // Click a node → show only its transitive dependency closure.
  #|  cy.on('tap', 'node', evt => {
  #|    const n = evt.target;
  #|    // Walk only over real dep edges, not member layout-hints.
  #|    const depEdges = cy.edges('[kind = "dep"]');
  #|    const ancestors = n.predecessors(depEdges);
  #|    const descendants = n.successors(depEdges);
  #|    const keep = n.union(ancestors).union(descendants);
  #|    cy.elements().addClass('dimmed');
  #|    keep.removeClass('dimmed');
  #|    n.addClass('focus');
  #|  });
  #|  cy.on('tap', evt => {
  #|    if (evt.target === cy) {
  #|      cy.elements().removeClass('dimmed').removeClass('focus');
  #|    }
  #|  });
  #|})();
  #|</script>
  #|</body>
  #|</html>
  #|

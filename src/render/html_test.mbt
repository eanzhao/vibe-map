///|
test "render produces a self-contained HTML document with embedded JSON" {
  let dag = @core.Dag::empty("demo")
  dag.add_goal(id="m1", title="用户能登录")
  dag.add_task(id="i1", goal="m1", title="auth middleware")
  dag.update_status("i1", @core.Done)
  let html = @render.render(dag)
  // Basic structural checks — we don't snapshot the whole document because
  // the embedded script is large.
  assert_true(html.contains("<!DOCTYPE html>"))
  assert_true(html.contains("id=\"map-canvas\""))
  assert_true(html.contains("项目进度"))
  assert_true(html.contains("节点详情"))
  assert_true(html.contains("id=\"dag-data\""))
  assert_true(html.contains("\"goals\""))
  assert_true(html.contains("\"tasks\""))
  assert_true(html.contains("\"用户能登录\""))
  assert_true(html.contains("auth middleware"))
  assert_true(html.contains("\"status\": \"done\""))
}

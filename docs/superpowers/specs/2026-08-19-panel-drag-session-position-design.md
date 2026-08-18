# TempoTasks 窗口拖动与会话位置记忆设计

## 目标

TempoTasks 悬浮面板允许用户拖动，并在 App 本次运行期间记住最后位置。完全退出 App 后不持久化位置；下次启动时恢复默认位置。

## 交互规则

1. App 每次启动后的首次显示，面板位于鼠标所在屏幕的顶部中央。
2. 用户可从左上角 Tempo 品牌区域，以及右侧标题与统计区域的静态背景拖动面板。
3. 日期按钮、日期选择器、任务输入框、添加按钮、任务列表、checkbox 和删除按钮不属于拖动区域。
4. 用户完成一次拖动后，本次运行期间隐藏并重新显示面板时，保留最后拖动位置。
5. 用户再次拖动后，内存中的最后位置立即更新。
6. 完全退出 App 后不保存窗口坐标；重新启动时恢复规则 1。
7. 拖动结束时，面板完整 frame 会被约束在所处屏幕的 `visibleFrame` 内，确保顶部拖动区和全部操作控件保持可用。
8. 如果会话内记录的位置不再完整位于任何可用屏幕的 `visibleFrame` 内，例如外接显示器断开，则清除本次位置并回到鼠标所在屏幕顶部中央。鼠标不属于任何屏幕时使用主屏幕，再回退到屏幕列表第一项。

## 实现边界

- `PanelController` 负责保存本次运行的位置状态，不写入 `UserDefaults`，也不使用窗口 frame autosave。
- SwiftUI 品牌区与标题区各自覆盖一个专用拖动表面。拖动表面只覆盖静态内容，不覆盖任何按钮、输入控件、列表、滚动区域或 popover；子控件事件始终优先。
- 拖动表面的原生视图在 `mouseDown` 时调用 `PanelController.beginUserDrag()`，再把事件交给 `NSWindow.performDrag(with:)`。该调用返回后调用 `PanelController.endUserDrag(originalFrame:currentFrame:)`。
- `PanelController` 只有在 begin/end 配对完成且 frame 确实变化时才写入会话 frame 并设置 `hasUserPosition = true`。拖动取消或 frame 未变化时不写入位置。
- 默认定位和屏幕回退直接设置 frame，不经过 begin/end 接口，因此不会被误判为用户拖动。窗口移动通知不负责判断事件来源，也不写入会话位置。
- `PanelController` 监听 `NSApplication.didChangeScreenParametersNotification`。面板显示时立即校验位置；面板隐藏时标记待校验，并在下次显示前完成校验。
- 现有 `Control + Space`、菜单栏入口、自动聚焦、日期 popover 和点击外部隐藏行为保持不变。

## 状态流程

- `hasUserPosition = false`：显示时执行默认定位。
- `beginUserDrag()`：记录拖动前 frame，并设置 `isUserDragging = true`，但不写入会话位置。
- `endUserDrag(originalFrame:currentFrame:)`：清除 `isUserDragging`；frame 发生变化时，把约束到当前屏幕 `visibleFrame` 后的 frame 写入内存，并设置 `hasUserPosition = true`；frame 未变化时视为取消。
- `hasUserPosition = true` 且 frame 完整位于任一屏幕 `visibleFrame`：显示时恢复会话 frame。
- frame 不满足完整可见条件：清除会话 frame 和 `hasUserPosition`，重新默认定位。
- 屏幕参数变化：显示中的面板立即执行上述校验；隐藏面板在下次显示前执行。
- App 退出：对象销毁，内存状态自然清空。

## 验证

1. 首次启动后显示位置为当前屏幕顶部中央。
2. 从品牌区域拖动成功；从标题区域拖动成功。
3. 输入框、日期按钮和任务行仍正常交互，不会误拖动。
4. 拖动后隐藏再显示，位置保持。
5. 退出进程后重新启动，位置恢复默认。
6. `Control + Space`、任务添加、完成、日期选择和现有自动化测试无回归。
7. 程序化默认定位不会写入会话位置。
8. 点击但未移动、按 Escape 取消或其他未改变 frame 的拖动不会写入会话位置。
9. 面板部分移出屏幕时会被约束到完整可操作范围。
10. 面板显示或隐藏期间断开显示器，均会在当前或下次显示时回到有效屏幕。
11. 拖动表面不会截获日期、输入、任务、滚动或 popover 事件。

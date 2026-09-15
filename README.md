# CursorParker

CursorParker 是一个轻量、免安装的 Windows 鼠标停放脚本，用于防止静止的鼠标指针遮挡输入内容。

## 工作方式

- 仅当鼠标保持静止且检测到文字输入键时进入待停放状态。
- 忽略鼠标点击、滚轮以及带 Ctrl、Alt 或 Win 的快捷键。
- 鼠标静止 1 秒后，记录当前位置并将指针停放到当前显示器右下角。
- 再次移动鼠标时，将指针恢复到停放前的位置。
- 当前台运行无标题栏全屏窗口，或鼠标被程序捕获时，自动暂停停放功能。
- 不替换系统光标、不安装键盘钩子、不使用 UI Automation，因此不会破坏动态光标。

## 系统要求

- Windows 10 或 Windows 11
- 系统自带的 Windows PowerShell 5.1
- 不需要管理员权限或第三方运行环境

## 使用方法

- `start_cursor_parker.cmd`：启动后台进程。
- `stop_cursor_parker.cmd`：停止进程；如果指针正停放在角落，会恢复到原位置。
- `pause_cursor_parker.cmd`：临时暂停停放功能。
- `resume_cursor_parker.cmd`：恢复停放功能。

重复运行启动脚本不会产生多个实例。

## 开机启动

- `enable_startup.cmd`：开启当前用户的开机启动。
- `disable_startup.cmd`：关闭当前用户的开机启动。
- `toggle_startup.cmd`：在开启与关闭之间切换。

开机启动通过当前用户“启动”目录内的 `CursorParker.lnk` 实现，不修改注册表，也不需要管理员权限。关闭开机启动时，该快捷方式会被删除。程序和源码始终保留在原目录。

## 调整停放时间

编辑 `start_cursor_parker.cmd`，修改下面参数后的数字：

```text
-TimeoutSeconds 1
```

也可以直接运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\cursor_parker.ps1 -TimeoutSeconds 2
```

## 已知限制

- 首次移动鼠标时会先恢复停放前的位置，因此可能看到一次轻微的位置跳动。
- 无法确认应用中的实际输入框焦点；在非输入框中单独按字母、数字或标点也可能进入待停放状态。
- 全屏保护无法覆盖所有窗口化游戏；运行窗口化游戏前可使用暂停脚本。

## 许可证

本项目采用 [MIT License](LICENSE)。

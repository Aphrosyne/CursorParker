# CursorParker

CursorParker 是一个轻量、免安装的 Windows 鼠标停放工具，用于减少静止指针遮挡输入内容的情况。

## 工作方式

- 鼠标保持静止且检测到文字输入键后，开始等待配置的时间。
- 等待结束后记录鼠标原位置，并将指针停到当前显示器最右侧、靠近右下方的位置。
- 再次移动鼠标时，将指针恢复到停放前的位置。
- 当前台窗口是无标题栏全屏窗口、鼠标被程序捕获，或当前程序路径列在排除列表中时，自动暂停停放。
- 忽略鼠标点击、滚轮以及带 Ctrl、Alt 或 Win 的快捷键。
- 不替换系统光标，不安装键盘钩子，也不使用 UI Automation。

## 配置

编辑程序目录里的 `CursorParker.ini`：

```ini
[General]
IdleSeconds=1

[ExcludedGames]
Game1=C:\Games\Example\game.exe
; Game2=D:\Games\AnotherGame\game.exe
```

- `IdleSeconds` 是检测到文字输入后等待的秒数，可以使用小数，例如 `1.5`。
- 在 `[ExcludedGames]` 下，每个 `GameN` 填一条游戏 EXE 的完整绝对路径。游戏窗口处于前台时会暂停停放；路径必须和实际运行的 EXE 完全对应，不支持通配符。
- 不确定游戏 EXE 路径时，可在任务管理器“详细信息”页右键游戏进程，选择“打开文件所在的位置”。
- 配置只在下次启动时读取。保存配置后重新启动 CursorParker 即可生效。
- INI 支持 UTF-8、UTF-8 BOM、UTF-16 BOM，以及当前 Windows ANSI 编码，便于填写含中文目录的路径。

## 使用

双击 `光标停放.cmd` 会打开中文命令行选择器，可选择启动、暂停、恢复、停止或切换开机启动；选择“退出”后关闭窗口。选择器只使用控制台，不打开额外的图形界面。

外层 CMD 文件只含 ASCII 字符。中文菜单脚本 `launcher.ps1` 使用 UTF-16LE BOM 编码，适配系统自带的 Windows PowerShell 5.1，不使用 UTF-8 中文批处理文本。

也保留了独立的 `start_cursor_parker.cmd`、`stop_cursor_parker.cmd`、`pause_cursor_parker.cmd` 和 `resume_cursor_parker.cmd`，可直接双击使用。

开机启动通过当前用户“启动”目录里的 `CursorParker.lnk` 实现，不修改注册表，也不需要管理员权限。关闭开机启动会删除这个快捷方式；程序和配置仍保留在本目录。

## 系统要求

- Windows 10 或 Windows 11
- 系统自带的 Windows PowerShell 5.1
- 不需要管理员权限或第三方运行环境

## 已知限制

- 首次移动鼠标时会先恢复停放前的位置，因此可能看到一次轻微的位置跳动。
- 脚本无法确认应用中的实际输入框焦点；未列入排除列表的程序中，单独按字母、数字或标点也可能触发停放。
- 全屏保护无法覆盖所有窗口化游戏；可将游戏 EXE 完整路径加入排除列表。

## 许可证

本项目采用 [MIT License](LICENSE)。

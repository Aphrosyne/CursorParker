Option Explicit

Dim fileSystem, shell, folder, action, target
Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
folder = fileSystem.GetParentFolderName(WScript.ScriptFullName)

action = "start"
If WScript.Arguments.Count > 0 Then
    action = LCase(WScript.Arguments(0))
End If

Select Case action
    Case "start": target = "start_cursor_parker.cmd"
    Case "stop": target = "stop_cursor_parker.cmd"
    Case "pause": target = "pause_cursor_parker.cmd"
    Case "resume": target = "resume_cursor_parker.cmd"
    Case "startup-on": target = "enable_startup.cmd"
    Case "startup-off": target = "disable_startup.cmd"
    Case "startup-toggle": target = "toggle_startup.cmd"
    Case Else: WScript.Quit 2
End Select

shell.Run Chr(34) & folder & "\" & target & Chr(34), 0, False

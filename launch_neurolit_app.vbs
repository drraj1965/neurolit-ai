Option Explicit

Dim shell
Dim fso
Dim appRoot
Dim backendScript
Dim backendExe
Dim appExe
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appRoot = fso.GetParentFolderName(WScript.ScriptFullName)
backendScript = appRoot & "\backend\run_backend.ps1"
backendExe = appRoot & "\backend_runtime\neurolit_backend.exe"
appExe = appRoot & "\neurolit_review_app.exe"

If Not fso.FileExists(appExe) Then
  appExe = appRoot & "\build\windows\x64\runner\Release\neurolit_review_app.exe"
End If

If Not fso.FileExists(backendExe) Then
  backendExe = appRoot & "\backend\dist\neurolit_backend\neurolit_backend.exe"
End If

If Not fso.FileExists(appExe) Then
  MsgBox "Windows app executable not found:" & vbCrLf & appExe, vbCritical, "NeuroLit App"
  WScript.Quit 1
End If

shell.CurrentDirectory = appRoot

If fso.FileExists(backendExe) Then
  shell.Run """" & backendExe & """ --host 127.0.0.1 --port 8000", 0, False
ElseIf fso.FileExists(backendScript) Then
  command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & backendScript & """"
  shell.Run command, 0, False
End If

WScript.Sleep 1500
shell.Run """" & appExe & """", 1, False

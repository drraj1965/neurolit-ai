Option Explicit

Dim shell
Dim fso
Dim projectRoot
Dim backendScript
Dim appExe
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

projectRoot = fso.GetParentFolderName(WScript.ScriptFullName)
backendScript = projectRoot & "\backend\run_backend.ps1"
appExe = projectRoot & "\build\windows\x64\runner\Release\neurolit_review_app.exe"

If Not fso.FileExists(backendScript) Then
  MsgBox "Backend launcher not found:" & vbCrLf & backendScript, vbCritical, "NeuroLit App"
  WScript.Quit 1
End If

If Not fso.FileExists(appExe) Then
  MsgBox "Windows app executable not found:" & vbCrLf & appExe, vbCritical, "NeuroLit App"
  WScript.Quit 1
End If

shell.CurrentDirectory = projectRoot
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & backendScript & """"

' Wait for the backend launcher to finish so the local API is ready before the app opens.
shell.Run command, 0, True
shell.Run """" & appExe & """", 1, False

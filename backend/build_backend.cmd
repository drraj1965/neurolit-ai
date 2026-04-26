@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0build_backend.ps1" %*

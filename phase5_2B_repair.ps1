# ==============================
# PHASE 5.2B REPAIR (ADD MISSING FUNCTIONS)
# ==============================

Write-Host "=== REPAIRING SESSION FUNCTIONS ==="

$BackupDir = "_phase5_2B_repair_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $homeFile -Raw

# ==============================
# ADD IMPORTS IF MISSING
# ==============================

if ($content -notmatch "dart:io") {

$content = $content -replace "import 'package:flutter/material.dart';",
"import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';"
}

# ==============================
# ADD VARIABLE
# ==============================

if ($content -notmatch "currentSessionFile") {

$content = $content -replace "_HomeScreenState extends State<HomeScreen> {",
"_HomeScreenState extends State<HomeScreen> {

  String currentSessionFile = '';"
}

# ==============================
# ADD FUNCTIONS (SAFE APPEND)
# ==============================

if ($content -notmatch "appendToSession") {

$functions = @"

  Future<void> createSessionFile(String query) async {
    final dir = await getApplicationDocumentsDirectory();

    final folder = Directory(dir.path + "/NeuroLit");

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(folder.path + "/Session_" + DateTime.now().millisecondsSinceEpoch.toString() + ".txt");

    await file.writeAsString("SEARCH: " + query + "\n\n");

    currentSessionFile = file.path;
  }

  Future<void> appendToSession(String text) async {
    if (currentSessionFile.isEmpty) return;

    final file = File(currentSessionFile);

    if (!await file.exists()) return;

    await file.writeAsString("\n\n" + text, mode: FileMode.append);
  }

"@

$content = $content -replace "}\s*$", "$functions`n}"
}

# ==============================
# SAVE FILE
# ==============================

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ FUNCTIONS RESTORED"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"
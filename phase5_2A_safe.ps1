# ==============================
# PHASE 5.2A SAFE PATCH (SESSION CORE ONLY)
# ==============================

Write-Host "=== PHASE 5.2A SAFE PATCH ==="

$BackupDir = "_phase5_2A_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# READ FILE
# ==============================

$content = Get-Content $homeFile -Raw

# ==============================
# ADD IMPORTS (ONLY IF NOT PRESENT)
# ==============================

if ($content -notmatch "path_provider") {

$importBlock = @"

import 'dart:io';
import 'package:path_provider/path_provider.dart';

"@

$content = $content -replace "import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';`n$importBlock"
}

# ==============================
# ADD VARIABLE (SAFE INSERT)
# ==============================

if ($content -notmatch "currentSessionFile") {

$content = $content -replace "_HomeScreenState extends State<HomeScreen> {", "_HomeScreenState extends State<HomeScreen> {

  String currentSessionFile = '';"
}

# ==============================
# ADD FUNCTIONS (APPEND AT END OF CLASS)
# ==============================

if ($content -notmatch "createSessionFile") {

$functions = @"

  Future<void> createSessionFile(String query) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();

      final folder = Directory(dir.path + "/NeuroLit");

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final safeQuery = query.replaceAll(" ", "_");

      final fileName = "Session_" + safeQuery + "_" + now.millisecondsSinceEpoch.toString() + ".txt";

      final file = File(folder.path + "/" + fileName);

      await file.writeAsString("SEARCH: " + query + "\n\n");

      currentSessionFile = file.path;

    } catch (e) {
      print("Session creation failed: $e");
    }
  }

  Future<void> appendToSession(String text) async {
    try {
      if (currentSessionFile.isEmpty) return;

      final file = File(currentSessionFile);

      if (!await file.exists()) return;

      await file.writeAsString("\n\n" + text, mode: FileMode.append);

    } catch (e) {
      print("Append failed: $e");
    }
  }

"@

$content = $content -replace "}\s*$", "$functions`n}"
}

# ==============================
# SAVE FILE
# ==============================

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.2A APPLIED (SAFE)"
Write-Host ""
Write-Host "Next step:"
Write-Host "flutter run -d windows"
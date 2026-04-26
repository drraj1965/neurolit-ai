# ==============================
# PHASE 5.5 — CLICKABLE PUBMED LINKS
# ==============================

Write-Host "=== PHASE 5.5 CLICKABLE PUBMED LINKS ==="

$BackupDir = "_phase5_5_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"
$pubspecFile = "pubspec.yaml"

if (Test-Path $homeFile) {
    Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
}
if (Test-Path $pubspecFile) {
    Copy-Item $pubspecFile "$BackupDir/pubspec.yaml.bak"
}

Write-Host "Backup created."

# ------------------------------
# Ensure url_launcher dependency
# ------------------------------
$pubspec = Get-Content $pubspecFile -Raw

if ($pubspec -notmatch "(?m)^\s*url_launcher:") {
    $pubspec = $pubspec -replace "(?m)^dependencies:\s*$", "dependencies:`r`n  url_launcher: ^6.3.2"
    Set-Content $pubspecFile $pubspec -Encoding UTF8
    Write-Host "Added url_launcher to pubspec.yaml"
} else {
    Write-Host "url_launcher already present in pubspec.yaml"
}

# ------------------------------
# Patch home_screen.dart
# ------------------------------
$content = Get-Content $homeFile -Raw

# Add import if missing
if ($content -notmatch "package:url_launcher/url_launcher\.dart") {
    $content = $content -replace "import 'package:path_provider/path_provider.dart';", "import 'package:path_provider/path_provider.dart';`r`nimport 'package:url_launcher/url_launcher.dart';"
}

# Add helper method if missing
if ($content -notmatch "Future<void>\s+openPubMedLink\(") {
$helper = @"

  Future<void> openPubMedLink(String link) async {
    if (link.trim().isEmpty) return;

    final uri = Uri.parse(link);

    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open PubMed link")),
      );
    }
  }

"@

    $content = $content -replace "(\r?\n\s*// ==============================\r?\n\s*// UI)", "$helper`r`n  // ==============================`r`n  // UI"
}

# Replace plain selectable link with clickable + button row
$oldBlock = @"
              SelectableText(
                a.link,
                style: const TextStyle(color: Colors.blue),
              ),
"@

$newBlock = @"
              InkWell(
                onTap: () => openPubMedLink(a.link),
                child: Text(
                  a.link,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
"@

$content = $content.Replace($oldBlock, $newBlock)

# Add explicit Open in PubMed button in abstract modal if not already present
if ($content -notmatch 'Open in PubMed') {
    $content = $content -replace 'TextButton\(\s*onPressed: \(\) => Navigator\.pop\(context\),\s*child: const Text\("Close"\),\s*\)', @'
TextButton(
            onPressed: () => openPubMedLink(a.link),
            child: const Text("Open in PubMed"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
'@
}

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.5 PATCH APPLIED"
Write-Host ""
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $BackupDir\home_screen.dart.bak lib\screens\home_screen.dart -Force"
Write-Host "Copy-Item $BackupDir\pubspec.yaml.bak pubspec.yaml -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter pub get"
Write-Host "flutter run -d windows"
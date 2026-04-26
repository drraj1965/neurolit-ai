Write-Host "=== PHASE 6.8 — DUMMY PDF NAMING ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_8_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: File not found"
    exit
}

if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/fulltext_service.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# Insert helper function for filename sanitization
$helper = @'

String _safeFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.length > 120) {
    return cleaned.substring(0, 120);
  }
  return cleaned;
}

Future<void> _createDummyPdf(String path) async {
  final file = File(path);

  if (await file.exists()) return;

  final minimalPdf = [
    0x25,0x50,0x44,0x46,0x2D,0x31,0x2E,0x34,0x0A,
    0x25,0xE2,0xE3,0xCF,0xD3,0x0A,
    0x31,0x20,0x30,0x20,0x6F,0x62,0x6A,0x0A,
    0x3C,0x3C,0x2F,0x54,0x79,0x70,0x65,0x2F,0x43,0x61,0x74,0x61,0x6C,0x6F,0x67,0x3E,0x3E,0x0A,
    0x65,0x6E,0x64,0x6F,0x62,0x6A,0x0A,
    0x78,0x72,0x65,0x66,0x0A,
    0x30,0x20,0x31,0x0A,
    0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x20,0x36,0x35,0x35,0x33,0x35,0x20,0x66,0x20,0x0A,
    0x74,0x72,0x61,0x69,0x6C,0x65,0x72,0x0A,
    0x3C,0x3C,0x2F,0x52,0x6F,0x6F,0x74,0x20,0x31,0x20,0x30,0x20,0x52,0x3E,0x3E,0x0A,
    0x73,0x74,0x61,0x72,0x74,0x78,0x72,0x65,0x66,0x0A,
    0x30,0x0A,
    0x25,0x25,0x45,0x4F,0x46
  ];

  await file.writeAsBytes(minimalPdf);
}
'@

if ($content -notmatch "_safeFileName") {
    $content = $content -replace "class FullTextService \{", "class FullTextService {$helper"
    Write-Host "Helper functions inserted."
}

# Insert dummy PDF creation inside downloadFullText
$insertPattern = "await Clipboard.setData\(ClipboardData\(text: pdfUrl\)\);"

$insertCode = @'

    final safeTitle = _safeFileName(title);
    final dummyPdfPath = "${folder.path}/$safeTitle.pdf";

    await _createDummyPdf(dummyPdfPath);
'@

$content = $content -replace $insertPattern, "$insertPattern$insertCode"

Set-Content -Path $file -Value $content -Encoding UTF8

Write-Host "Dummy PDF logic inserted."

# Validation
$check = Get-Content $file -Raw

if ($check -match "_createDummyPdf" -and $check -match "_safeFileName") {
    Write-Host "✅ Validation passed."
} else {
    Write-Host "❌ Validation failed — restoring backup"
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit
}

Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"
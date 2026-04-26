Write-Host "=== PHASE 6.6 PDF ENGINE FIX (CLEAN) ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_6_pdf_engine_backup_v2"

if (!(Test-Path $file)) {
    Write-Host "ERROR: File not found"
    exit 1
}

# 🔁 BACKUP
if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/fulltext_service.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# 🔥 REMOVE ALL EXISTING _tryDownloadPdf FUNCTIONS
$pattern = "Future<String\?> _tryDownloadPdf[\s\S]*?\n\}"

$content = [regex]::Replace($content, $pattern, "")

Write-Host "Old _tryDownloadPdf removed."

# 🟢 NEW CLEAN FUNCTION
$newFunc = @"

Future<String?> _tryDownloadPdf(String url, String outputPath) async {
  try {
    final client = HttpClient()
      ..userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";

    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, "application/pdf");

    final response = await request.close();

    if (response.statusCode != 200) {
      client.close(force: true);
      return null;
    }

    final bytes = await consolidateHttpClientResponseBytes(response);
    client.close(force: true);

    final isPdf = bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    if (!isPdf) return null;

    final file = File(outputPath);
    await file.writeAsBytes(bytes);

    return file.path;
  } catch (_) {
    return null;
  }
}

"@

# 🔽 INSERT BEFORE LAST }
$lastBrace = $content.LastIndexOf("}")

if ($lastBrace -lt 0) {
    Write-Host "ERROR: Could not find class closing brace"
    exit 1
}

$newContent = $content.Substring(0, $lastBrace) + $newFunc + "`n}"

Set-Content -Path $file -Value $newContent -Encoding UTF8

Write-Host "New function inserted."

# ✅ VALIDATION
$check = Get-Content $file -Raw

$count = ([regex]::Matches($check, "_tryDownloadPdf")).Count

Write-Host "Function count: $count"

if ($count -ne 1) {
    Write-Host "ERROR: Duplicate functions detected"
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit 1
}

Write-Host "Validation passed."

# 🔍 BRACE CHECK
$open = ([regex]::Matches($check, '\{')).Count
$close = ([regex]::Matches($check, '\}')).Count

Write-Host "Braces: $open / $close"

if ($open -ne $close) {
    Write-Host "WARNING: mismatch"
} else {
    Write-Host "Braces OK"
}

Write-Host ""
Write-Host "Rollback:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"

Write-Host ""
Write-Host "Next:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"
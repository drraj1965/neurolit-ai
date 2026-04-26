Write-Host "=== PHASE 6.6 FINAL PDF ENGINE FIX ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_6_pdf_engine_backup"

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

# 🔍 FIND FUNCTION
$start = $content.IndexOf("Future<String?> _tryDownloadPdf")
$end = $content.IndexOf("}", $start)

if ($start -lt 0) {
    Write-Host "ERROR: _tryDownloadPdf not found"
    exit 1
}

# 🟢 NEW FUNCTION
$newFunc = @"
Future<String?> _tryDownloadPdf(String url, String outputPath) async {
  try {
    final client = HttpClient()
      ..userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";

    final request = await client.getUrl(Uri.parse(url));

    request.headers.set(HttpHeaders.acceptHeader, "application/pdf");

    final response = await request.close();

    if (response.statusCode != 200) {
      client.close(force: true);
      return null;
    }

    final bytes = await consolidateHttpClientResponseBytes(response);
    client.close(force: true);

    // 🔍 VALIDATE PDF SIGNATURE
    final isPdf = bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    if (!isPdf) return null;

    final file = File(outputPath);
    await file.writeAsBytes(bytes);

    return file.path;
  } catch (e) {
    return null;
  }
}
"@

# 🔁 REPLACE WHOLE FUNCTION SAFELY
$pattern = [regex]::Escape("Future<String?> _tryDownloadPdf")

$prefix = $content.Substring(0, $start)

# Find end of function by counting braces
$braceCount = 0
$index = $start

while ($index -lt $content.Length) {
    if ($content[$index] -eq '{') { $braceCount++ }
    if ($content[$index] -eq '}') { $braceCount-- }

    if ($braceCount -eq 0 -and $index -gt $start) {
        break
    }
    $index++
}

$suffix = $content.Substring($index + 1)

$newContent = $prefix + $newFunc + $suffix

Set-Content -Path $file -Value $newContent -Encoding UTF8

Write-Host "Function replaced."

# 🔍 VALIDATION
$check = Get-Content $file -Raw

if ($check -notmatch "Mozilla/5.0") {
    Write-Host "VALIDATION FAILED"
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit 1
}

Write-Host "Validation passed."

# 🔍 SYNTAX CHECK
$openCurlies = ([regex]::Matches($check, '\{')).Count
$closeCurlies = ([regex]::Matches($check, '\}')).Count

Write-Host "Curly braces: $openCurlies / $closeCurlies"

if ($openCurlies -ne $closeCurlies) {
    Write-Host "WARNING: mismatch detected"
} else {
    Write-Host "Braces OK"
}

Write-Host ""
Write-Host "Rollback:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"
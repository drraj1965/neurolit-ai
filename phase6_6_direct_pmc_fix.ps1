Write-Host "=== PHASE 6.6 DIRECT PMC PDF FIX ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_6_fix_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: File not found: $file"
    exit 1
}

# 🔁 BACKUP
if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/fulltext_service.dart.bak" -Force

Write-Host "Backup created."

# 🔍 LOAD FILE
$content = Get-Content $file -Raw

# 🔴 TARGET BLOCK (your current code)
$pattern = [regex]::Escape(@"
if (pmcId.isNotEmpty) {
      final directPdfUrl =
          "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/pdf/";

      final directResult = await _tryDownloadPdf(
        directPdfUrl,
        "${folder.path}/$pmid.pdf",
      );
      if (directResult != null) {
        return "PDF downloaded:\n$directResult";
      }

      final htmlUrl = "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/";
      final html = await _fetchText(htmlUrl);

      if (html != null && html.isNotEmpty) {
        final extractedPdfUrl = _extractPdfUrlFromHtml(html, pmcId);

        if (extractedPdfUrl != null) {
          final extractedResult = await _tryDownloadPdf(
            extractedPdfUrl,
            "${folder.path}/$pmid.pdf",
          );
          if (extractedResult != null) {
            return "PDF downloaded:\n$extractedResult";
          }
        }
      }
    }
"@)

# 🟢 NEW BLOCK (clean + reliable)
$replacement = @"
if (pmcId.isNotEmpty) {

  // 🔹 Attempt 1: direct PMC pdf endpoint
  final directPdfUrl =
      "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/pdf/";

  final directResult = await _tryDownloadPdf(
    directPdfUrl,
    "${folder.path}/$pmid.pdf",
  );
  if (directResult != null) {
    return "PDF downloaded:\n$directResult";
  }

  // 🔹 Attempt 2: main.pdf (MOST RELIABLE)
  final pmcPdfUrl =
      "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/pdf/main.pdf";

  final mainPdfResult = await _tryDownloadPdf(
    pmcPdfUrl,
    "${folder.path}/$pmid.pdf",
  );

  if (mainPdfResult != null) {
    return "PDF downloaded:\n$mainPdfResult";
  }
}
"@

# 🔁 REPLACE
if ($content -match $pattern) {
    $content = [regex]::Replace($content, $pattern, $replacement)
    Write-Host "PMC block replaced successfully."
} else {
    Write-Host "ERROR: Target block not found. No changes made."
    exit 1
}

# 💾 SAVE
Set-Content -Path $file -Value $content -Encoding UTF8

Write-Host "File updated."

# ✅ VALIDATION
$updated = Get-Content $file -Raw

$checks = @(
    "main.pdf",
    "_tryDownloadPdf",
    "pmcId"
)

$missing = @()
foreach ($c in $checks) {
    if ($updated -notmatch [regex]::Escape($c)) {
        $missing += $c
    }
}

if ($missing.Count -gt 0) {
    Write-Host "VALIDATION FAILED. Missing:"
    $missing | ForEach-Object { Write-Host " - $_" }

    Write-Host "Restoring backup..."
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit 1
}

Write-Host "Validation passed."

# 🔍 SYNTAX CHECK (basic)
$openCurlies = ([regex]::Matches($updated, '\{')).Count
$closeCurlies = ([regex]::Matches($updated, '\}')).Count
$openParens = ([regex]::Matches($updated, '\(')).Count
$closeParens = ([regex]::Matches($updated, '\)')).Count

Write-Host ""
Write-Host "Brace check:"
Write-Host "Curly: $openCurlies / $closeCurlies"
Write-Host "Paren: $openParens / $closeParens"

if ($openCurlies -ne $closeCurlies -or $openParens -ne $closeParens) {
    Write-Host "WARNING: mismatch detected"
} else {
    Write-Host "Braces look balanced."
}

# 🔁 ROLLBACK
Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"

Write-Host ""
Write-Host "Next:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"
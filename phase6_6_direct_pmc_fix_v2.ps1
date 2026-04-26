Write-Host "=== PHASE 6.6 DIRECT PMC FIX (ROBUST) ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_6_fix_backup_v2"

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

# 🔍 FIND START + END
$startIndex = $content.IndexOf("if (pmcId.isNotEmpty)")
$endIndex = $content.IndexOf('final file = File("${folder.path}/$pmid.txt")')

if ($startIndex -lt 0 -or $endIndex -lt 0) {
    Write-Host "ERROR: Could not locate block boundaries."
    exit 1
}

$before = $content.Substring(0, $startIndex)
$after = $content.Substring($endIndex)

# 🟢 NEW BLOCK
$newBlock = @"
if (pmcId.isNotEmpty) {

  // 🔹 Attempt 1: direct PMC endpoint
  final directPdfUrl =
      "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/pdf/";

  final directResult = await _tryDownloadPdf(
    directPdfUrl,
    "${folder.path}/$pmid.pdf",
  );
  if (directResult != null) {
    return "PDF downloaded:\n$directResult";
  }

  // 🔹 Attempt 2: MAIN PDF (MOST RELIABLE)
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

# 🔁 REBUILD FILE
$newContent = $before + $newBlock + $after

Set-Content -Path $file -Value $newContent -Encoding UTF8

Write-Host "Block replaced successfully."

# ✅ VALIDATION
$check = Get-Content $file -Raw

if ($check -notmatch "main.pdf") {
    Write-Host "VALIDATION FAILED"
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit 1
}

Write-Host "Validation passed."

# 🔍 SYNTAX CHECK
$openCurlies = ([regex]::Matches($check, '\{')).Count
$closeCurlies = ([regex]::Matches($check, '\}')).Count
$openParens = ([regex]::Matches($check, '\(')).Count
$closeParens = ([regex]::Matches($check, '\)')).Count

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
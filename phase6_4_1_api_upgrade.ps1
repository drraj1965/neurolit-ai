Write-Host "=== PHASE 6.4.1 — API UPGRADE (ESUMMARY) ==="

$file = "lib/services/api_service.dart"
$backup = "_phase6_4_1_backup"

# -------------------------
# BACKUP
# -------------------------
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/api_service.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 1 — ADD ESUMMARY CALL
# -------------------------

if ($content -notmatch "esummary.fcgi") {

$esummaryBlock = @"

    // STEP 2: Fetch metadata via eSummary
    final summaryResponse = await http.get(Uri.parse(
      'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=' + ids.join(',') + '&retmode=json'
    ));

    final summaryJson = jsonDecode(summaryResponse.body);

"@

$content = $content -replace "final ids = .*?;", '$0' + "`r`n" + $esummaryBlock

Write-Host "Inserted eSummary call."
}

# -------------------------
# STEP 2 — ENHANCE ARTICLE PARSING
# -------------------------

# Replace basic article creation block
$pattern = "Article\([\s\S]*?\)"

$newArticle = @"
Article(
  title: title,
  abstractText: abstractText,
  journal: journal,
  date: date,
  authors: authors,
  pmid: id,
  link: 'https://pubmed.ncbi.nlm.nih.gov/' + id + '/',

  publicationType: (summaryJson['result'][id]?['pubtype'] ?? []).join(', '),

  isFree: ((summaryJson['result'][id]?['articleids'] ?? [])
      .any((a) => a['idtype'] == 'pmc')),

  isPMC: ((summaryJson['result'][id]?['articleids'] ?? [])
      .any((a) => a['idtype'] == 'pmc')),
)
"@

$content = [regex]::Replace($content, $pattern, $newArticle)

Write-Host "Enhanced Article parsing."

# -------------------------
# VALIDATION
# -------------------------

if ($content -notmatch "esummary.fcgi") {
    Write-Host "❌ eSummary not inserted — rolling back"
    Copy-Item "$backup/api_service.dart.bak" $file -Force
    exit
}

if ($content -notmatch "publicationType") {
    Write-Host "❌ Article parsing failed — rolling back"
    Copy-Item "$backup/api_service.dart.bak" $file -Force
    exit
}

# -------------------------
# SAVE
# -------------------------

Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.4.1 PATCH SUCCESSFUL"
Write-Host ""
Write-Host "If something breaks, rollback using:"
Write-Host "Copy-Item $backup/api_service.dart.bak lib/services/api_service.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter run -d windows"
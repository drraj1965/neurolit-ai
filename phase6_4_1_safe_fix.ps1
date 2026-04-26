Write-Host "=== SAFE ESUMMARY PATCH (CONTROLLED) ==="

$file = "lib/services/api_service.dart"
$backup = "_phase6_4_1_safe_backup"

# Backup
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/api_service.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 1 — INSERT ESUMMARY FETCH (after ids list)
# -------------------------

if ($content -notmatch "esummary.fcgi") {

$content = $content -replace "final ids = .*?;",
@"
$0

// Fetch metadata from eSummary
final summaryResponse = await http.get(
  Uri.parse(
    'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=' + ids.join(',') + '&retmode=json'
  )
);

final summaryJson = jsonDecode(summaryResponse.body);
"@

Write-Host "Inserted eSummary fetch."
}

# -------------------------
# STEP 2 — MODIFY ARTICLE CREATION SAFELY
# -------------------------

# Instead of replacing whole Article block, we ADD fields inside it

$content = $content -replace "link: 'https://pubmed.ncbi.nlm.nih.gov/' \+ id \+ '/',",
@"
link: 'https://pubmed.ncbi.nlm.nih.gov/' + id + '/',

publicationType: (summaryJson['result'][id]?['pubtype'] ?? []).join(', '),

isFree: ((summaryJson['result'][id]?['articleids'] ?? [])
    .any((a) => a['idtype'] == 'pmc')),

isPMC: ((summaryJson['result'][id]?['articleids'] ?? [])
    .any((a) => a['idtype'] == 'pmc')),
"@

Write-Host "Enhanced Article fields safely."

# -------------------------
# VALIDATION
# -------------------------

if ($content -notmatch "summaryJson") {
    Write-Host "❌ Failed — rolling back"
    Copy-Item "$backup/api_service.dart.bak" $file -Force
    exit
}

# Save
Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ SAFE PATCH COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"
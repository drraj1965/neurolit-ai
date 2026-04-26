Write-Host "=== STEP 1: UPDATE ARTICLE MODEL ==="

$file = "lib/models/article.dart"
$backup = "_article_backup"

# Backup
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/article.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# Add new fields after link
if ($content -notmatch "isFree") {

$content = $content -replace "final String link;",
"final String link;

  final String publicationType;
  final bool isFree;
  final bool isPMC;"

Write-Host "Added new fields."
}

# Add constructor defaults
if ($content -notmatch "this.isFree") {

$content = $content -replace "required this.link,",
"required this.link,

    this.publicationType = '',
    this.isFree = false,
    this.isPMC = false,"

Write-Host "Added constructor defaults."
}

# Validate
if ($content -notmatch "isFree" -or $content -notmatch "isPMC") {
    Write-Host "❌ Patch failed — rolling back"
    Copy-Item "$backup/article.dart.bak" $file -Force
    exit
}

# Save
Set-Content $file $content -Encoding UTF8

Write-Host "✅ STEP 1 COMPLETE"
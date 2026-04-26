Write-Host "=== PHASE 6.1 STEP 2 (SAFE PATCH WITH VALIDATION) ==="

$backup = "_step2_backup"
$file = "lib/screens/home_screen.dart"

# -------------------------
# STEP 1: BACKUP
# -------------------------
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 2: ADD VARIABLE
# -------------------------
if ($content -notmatch "bool showSelectedOnly") {
    $content = $content -replace "Set<String> selectedPmids = \{\};", "Set<String> selectedPmids = {};`r`n  bool showSelectedOnly = false;"
    Write-Host "Added showSelectedOnly variable."
}

# -------------------------
# STEP 3: REPLACE pagedArticles
# -------------------------
if ($content -match "List<Article> get pagedArticles") {

    $newPaged = @"
List<Article> get pagedArticles {
  final source = showSelectedOnly
      ? articles.where((a) => selectedPmids.contains(a.pmid)).toList()
      : articles;

  final start = currentPage * pageSize;
  if (start >= source.length) return [];
  final end = (start + pageSize) > source.length
      ? source.length
      : (start + pageSize);

  return source.sublist(start, end);
}
"@

    $content = [regex]::Replace(
        $content,
        "List<Article> get pagedArticles \{[\s\S]*?\}",
        $newPaged
    )

    Write-Host "Updated pagedArticles."
}

# -------------------------
# STEP 4: REPLACE totalPages
# -------------------------
if ($content -match "int get totalPages") {

    $newTotal = @"
int get totalPages {
  final source = showSelectedOnly
      ? articles.where((a) => selectedPmids.contains(a.pmid)).toList()
      : articles;

  if (source.isEmpty) return 1;
  return ((source.length - 1) ~/ pageSize) + 1;
}
"@

    $content = [regex]::Replace(
        $content,
        "int get totalPages \{[\s\S]*?\}",
        $newTotal
    )

    Write-Host "Updated totalPages."
}

# -------------------------
# STEP 5: ADD TOGGLE BUTTON
# -------------------------
if ($content -notmatch "Show Selected Only") {

    $toggleBtn = @"

        const SizedBox(height: 6),

        ElevatedButton(
          onPressed: () {
            setState(() {
              showSelectedOnly = !showSelectedOnly;
              currentPage = 0;
            });
          },
          child: Text(
            showSelectedOnly ? "Show All Articles" : "Show Selected Only",
          ),
        ),
"@

    $content = $content -replace 'Generate AI Summary"\),', 'Generate AI Summary"),' + $toggleBtn

    Write-Host "Added toggle button."
}

# -------------------------
# STEP 6: VALIDATION
# -------------------------

$errors = @()

if ($content -notmatch "bool showSelectedOnly") {
    $errors += "Missing showSelectedOnly variable"
}

if ($content -notmatch "selectedPmids.contains\(a.pmid\)") {
    $errors += "Selection logic missing"
}

if ($content -match "\\\(") {
    $errors += "Invalid escaped parentheses detected"
}

if ($content -match "selected\.") {
    $errors += "Old 'selected' variable still exists"
}

if ($errors.Count -gt 0) {
    Write-Host "❌ PATCH FAILED VALIDATION"
    $errors | ForEach-Object { Write-Host $_ }

    Write-Host "Restoring backup..."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

# -------------------------
# STEP 7: SAVE FILE
# -------------------------

Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ STEP 2 PATCH SUCCESSFUL"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter run -d windows"
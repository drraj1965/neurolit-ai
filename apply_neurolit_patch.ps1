# ===============================
# NeuroLit Safe Patch Script v2
# ===============================

$projectPath = "C:\Users\drpha\Documents\Aster\neurolitApp\neurolitApp\neurolit_review_app"
$filePath = "$projectPath\lib\screens\home_screen.dart"

# --- STEP 1: BACKUP ---
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$projectPath\backup_home_screen_$timestamp.dart"

Copy-Item $filePath $backupPath -Force
Write-Host "Backup created: $backupPath" -ForegroundColor Green

# --- LOAD FILE ---
$content = Get-Content $filePath -Raw

# ===============================
# PATCH 1 — Add state variables
# ===============================
if ($content -notmatch "bool isUpdateMode") {
$content = $content -replace "int currentPage = 0;",
@"
int currentPage = 0;

bool isUpdateMode = false;
bool hasCollectionChanged = false;
SavedCollection? activeCollection;
"@
Write-Host "Added state variables" -ForegroundColor Cyan
}

# ===============================
# PATCH 2 — Fix setState block
# ===============================
$content = $content -replace "showSelectedOnly = true;\s+currentPage = 0;",
@"
showSelectedOnly = true;
  currentPage = 0;

  activeCollection = collection;
  isUpdateMode = false;
"@
Write-Host "Patched loadCollection state" -ForegroundColor Cyan

# ===============================
# PATCH 3 — Add Update Collection button
# ===============================
if ($content -notmatch "Update Collection") {

$updateButton = @"

const SizedBox(height: 6),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: activeCollection == null
        ? null
        : () {
            setState(() {
              isUpdateMode = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Update mode enabled")),
            );
          },
    child: const Text("Update Collection"),
  ),
),
"@

$content = $content -replace "child: const Text\(""Load Collections""\),\s*\),",
"child: const Text(""Load Collections""),`n  ),$updateButton"

Write-Host "Added Update Collection button" -ForegroundColor Cyan
}

# ===============================
# PATCH 4 — Add Save Updated button
# ===============================
if ($content -notmatch "Save Updated Collection") {

$saveButton = @"

const SizedBox(height: 6),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: (isUpdateMode && hasCollectionChanged)
        ? updateCurrentCollection
        : null,
    child: const Text("Save Updated Collection"),
  ),
),
"@

$content = $content -replace "Update Collection""\),\s*\),",
"Update Collection""),`n  ),$saveButton"

Write-Host "Added Save Updated button" -ForegroundColor Cyan
}

# ===============================
# PATCH 5 — Update search logic
# ===============================
$content = $content -replace "if \(isUpdateMode\) \{",
@"
if (isUpdateMode) {
  hasCollectionChanged = true;

  result.sort((a, b) => b.date.compareTo(a.date));
"@

Write-Host "Patched search merge logic" -ForegroundColor Cyan

# ===============================
# PATCH 6 — Add update function
# ===============================
if ($content -notmatch "updateCurrentCollection") {

$updateFunction = @"

Future<void> updateCurrentCollection() async {
  if (activeCollection == null) return;

  final updatedArticles = selectedArticlesGlobal.values.toList();

  await collectionService.saveCollection(
    name: activeCollection!.name,
    articles: updatedArticles,
  );

  setState(() {
    isUpdateMode = false;
    hasCollectionChanged = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Collection updated")),
  );
}
"@

$content += $updateFunction

Write-Host "Added updateCurrentCollection function" -ForegroundColor Cyan
}

# ===============================
# SAVE FILE
# ===============================
Set-Content $filePath $content -Encoding UTF8
Write-Host "File patched successfully" -ForegroundColor Green

# ===============================
# VALIDATION
# ===============================
Write-Host "Running flutter analyze..." -ForegroundColor Yellow
cd $projectPath
flutter analyze

if ($LASTEXITCODE -ne 0) {
    Write-Host "Errors found. Rolling back..." -ForegroundColor Red
    Copy-Item $backupPath $filePath -Force
    Write-Host "Rollback complete." -ForegroundColor Red
} else {
    Write-Host "Patch successful and verified!" -ForegroundColor Green
}
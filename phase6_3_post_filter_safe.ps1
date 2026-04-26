Write-Host "=== PHASE 6.3 POST FILTER (SAFE PATCH) ==="

$file = "lib/screens/home_screen.dart"
$backup = "_phase6_3_backup"

# -------------------------
# BACKUP
# -------------------------
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 1: ADD VARIABLES
# -------------------------
if ($content -notmatch "postFilterTextAvailability") {

    $content = $content -replace "String outputMode = ""review"";",
@"
String outputMode = "review";

String postFilterTextAvailability = 'any';
String postFilterArticleType = 'any';
"@

    Write-Host "Added post-filter variables."
}

# -------------------------
# STEP 2: MODIFY pagedArticles
# -------------------------

$pattern = "List<Article> get pagedArticles \{[\s\S]*?\}"

$newBlock = @"
List<Article> get pagedArticles {

  final base = showSelectedOnly
      ? articles.where((a) => selectedPmids.contains(a.pmid)).toList()
      : articles;

  final filtered = base.where((a) {

    bool matchText = true;
    bool matchType = true;

    if (postFilterTextAvailability == 'abstract') {
      matchText = a.abstractText.trim().isNotEmpty;
    } else if (postFilterTextAvailability == 'free_full_text') {
      matchText = a.link.toLowerCase().contains('pmc');
    }

    if (postFilterArticleType == 'review') {
      matchType = a.journal.toLowerCase().contains('review');
    }

    return matchText && matchType;

  }).toList();

  final start = currentPage * pageSize;
  if (start >= filtered.length) return [];

  final end = (start + pageSize) > filtered.length
      ? filtered.length
      : (start + pageSize);

  return filtered.sublist(start, end);
}
"@

$content = [regex]::Replace($content, $pattern, $newBlock)

Write-Host "Updated pagedArticles."

# -------------------------
# STEP 3: MODIFY totalPages
# -------------------------

$pattern2 = "int get totalPages \{[\s\S]*?\}"

$newTotal = @"
int get totalPages {

  final base = showSelectedOnly
      ? articles.where((a) => selectedPmids.contains(a.pmid)).toList()
      : articles;

  final filtered = base.where((a) {

    bool matchText = true;
    bool matchType = true;

    if (postFilterTextAvailability == 'abstract') {
      matchText = a.abstractText.trim().isNotEmpty;
    } else if (postFilterTextAvailability == 'free_full_text') {
      matchText = a.link.toLowerCase().contains('pmc');
    }

    if (postFilterArticleType == 'review') {
      matchType = a.journal.toLowerCase().contains('review');
    }

    return matchText && matchType;

  }).toList();

  if (filtered.isEmpty) return 1;

  return ((filtered.length - 1) ~/ pageSize) + 1;
}
"@

$content = [regex]::Replace($content, $pattern2, $newTotal)

Write-Host "Updated totalPages."

# -------------------------
# STEP 4: ADD UI FILTER
# -------------------------

if ($content -notmatch "Filter \(Results\)") {

$insertUI = @"

const SizedBox(height: 8),

DropdownButtonFormField<String>(
  value: postFilterTextAvailability,
  decoration: const InputDecoration(labelText: "Filter (Results)"),
  items: const [
    DropdownMenuItem(value: "any", child: Text("All")),
    DropdownMenuItem(value: "abstract", child: Text("Abstract available")),
    DropdownMenuItem(value: "free_full_text", child: Text("Free full text")),
  ],
  onChanged: (v) {
    if (v == null) return;
    setState(() {
      postFilterTextAvailability = v;
      currentPage = 0;
    });
  },
),
"@

$content = $content -replace "TextField\([\s\S]*?onSubmitted: \(_\) => search\(\),\n\s*\),", '$0' + $insertUI

Write-Host "Added UI filter dropdown."
}

# -------------------------
# VALIDATION
# -------------------------

if ($content -match "\\\(") {
    Write-Host "❌ Syntax corruption detected. Rolling back."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

# -------------------------
# SAVE
# -------------------------

Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.3 PATCH SUCCESSFUL"
Write-Host "Run:"
Write-Host "flutter run -d windows"
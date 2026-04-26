Write-Host "=== PHASE 7.1 — TOPIC SYSTEM ==="

$file = "lib/screens/home_screen.dart"
$backupDir = "_phase7_1_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: home_screen.dart not found"
    exit
}

if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/home_screen.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# ----------------------------------------
# STEP 1 — Add variables
# ----------------------------------------

$varInsert = @"

  // 🔹 Phase 7.1 — Topic system
  String? currentTopic;
  bool isRelatedMode = false;

"@

$content = $content -replace "class _HomeScreenState extends State<HomeScreen> \{", "class _HomeScreenState extends State<HomeScreen> {$varInsert"

Write-Host "Added topic variables."

# ----------------------------------------
# STEP 2 — Add topic generator
# ----------------------------------------

$funcInsert = @"

String _generateTopicName(String input) {
  final words = input
      .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .take(6)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .toList();

  return words.join('_');
}

"@

$content = $content -replace "Widget build\(BuildContext context\) \{", "$funcInsert`nWidget build(BuildContext context) {"

Write-Host "Added topic generator."

# ----------------------------------------
# STEP 3 — Inject topic logic into search
# ----------------------------------------

$searchPattern = "Future<void> performSearch\(\) async \{"

$topicLogic = @"

    // 🔹 Topic logic
    if (!isRelatedMode || currentTopic == null) {
      currentTopic = _generateTopicName(controller.text);
    }

"@

$content = $content -replace $searchPattern, "$searchPattern$topicLogic"

Write-Host "Injected topic logic."

# ----------------------------------------
# STEP 4 — Add checkbox UI
# ----------------------------------------

$uiInsert = @"

Row(
  children: [
    Checkbox(
      value: isRelatedMode,
      onChanged: (v) {
        setState(() {
          isRelatedMode = v ?? false;
          if (!isRelatedMode) currentTopic = null;
        });
      },
    ),
    const Text("Related searches"),
    const SizedBox(width: 16),
    if (currentTopic != null)
      Text("Topic: $currentTopic",
          style: const TextStyle(fontWeight: FontWeight.bold)),
  ],
),

"@

# Insert above search button (safe anchor)
$content = $content -replace "ElevatedButton\(", "$uiInsert`nElevatedButton("

Write-Host "Added UI checkbox."

# ----------------------------------------
# VALIDATION
# ----------------------------------------

$check = $content

if ($check -match "currentTopic" -and $check -match "Related searches") {
    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "✅ Validation passed."
} else {
    Write-Host "❌ Validation failed — restoring backup"
    Copy-Item "$backupDir/home_screen.dart.bak" $file -Force
    exit
}

Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backupDir/home_screen.dart.bak`" `"$file`" -Force"
Write-Host ""

Write-Host "Next:"
Write-Host "flutter run -d windows"
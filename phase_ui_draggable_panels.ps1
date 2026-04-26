$ErrorActionPreference = "Stop"

Write-Host "=== UI DRAGGABLE PANELS PATCH ===" -ForegroundColor Cyan

$root = Get-Location
$file = Join-Path $root "lib/screens/home_screen.dart"

if (!(Test-Path $file)) {
  throw "Could not find lib/screens/home_screen.dart"
}

$backupDir = Join-Path $root "_ui_drag_backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backupFile = Join-Path $backupDir "home_screen.dart.bak"
Copy-Item $file $backupFile -Force
Write-Host "Backup created: $backupFile" -ForegroundColor Green

$content = Get-Content $file -Raw

# 1) Add width state variables
$old1 = "  int currentPage = 0;
  final int pageSize = 10;"
$new1 = "  int currentPage = 0;
  final int pageSize = 10;

  double filterPanelWidth = 240;
  double topPanelWidth = 240;"
if ($content.Contains($old1)) {
  $content = $content.Replace($old1, $new1)
} elseif ($content.Contains("double filterPanelWidth")) {
  Write-Host "Width variables already present." -ForegroundColor Yellow
} else {
  throw "Could not find insertion point for panel width variables."
}

# 2) Make filter panel width dynamic
$old2 = "      width: 240,"
$new2 = "      width: filterPanelWidth,"
if ($content.Contains($old2)) {
  $content = $content.Replace($old2, $new2)
} elseif ($content.Contains("width: filterPanelWidth")) {
  Write-Host "Filter panel width already dynamic." -ForegroundColor Yellow
} else {
  throw "Could not find filter panel width line."
}

# 3) Replace the 'content' row block
$patternContent = [regex]::Escape(@"
    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 240,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTopSection(),
            buildSessionPanel(),   // 👈 move here
          ],
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: buildArticlesList(),
    ),
  ],
),
    );
"@)

$replacementContent = @"
    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: topPanelWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTopSection(),
                  buildSessionPanel(),
                ],
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  topPanelWidth =
                      (topPanelWidth + details.delta.dx).clamp(180.0, 500.0).toDouble();
                });
              },
              child: Container(
                width: 10,
                height: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: buildArticlesList(),
          ),
        ],
      ),
    );
"@

if ([regex]::IsMatch($content, $patternContent, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
  $content = [regex]::Replace(
    $content,
    $patternContent,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacementContent },
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
} elseif ($content.Contains("width: topPanelWidth")) {
  Write-Host "Middle panel drag block already present." -ForegroundColor Yellow
} else {
  throw "Could not find the content row block to replace."
}

# 4) Replace the wide-screen body row block
$patternBody = [regex]::Escape(@"
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filters,
                Expanded(child: content),
              ],
            )
          : content,
"@)

$replacementBody = @"
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filters,
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        filterPanelWidth =
                            (filterPanelWidth + details.delta.dx).clamp(180.0, 420.0).toDouble();
                      });
                    },
                    child: Container(
                      width: 10,
                      height: double.infinity,
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
"@

if ([regex]::IsMatch($content, $patternBody, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
  $content = [regex]::Replace(
    $content,
    $patternBody,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacementBody },
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
} elseif ($content.Contains("filterPanelWidth =")) {
  Write-Host "Outer drag block may already be present." -ForegroundColor Yellow
} else {
  throw "Could not find the body row block to replace."
}

Set-Content -Path $file -Value $content -Encoding UTF8

# 5) Validation
$check1 = Select-String -Path $file -Pattern "double filterPanelWidth = 240;"
$check2 = Select-String -Path $file -Pattern "double topPanelWidth = 240;"
$check3 = Select-String -Path $file -Pattern "width: filterPanelWidth"
$check4 = Select-String -Path $file -Pattern "width: topPanelWidth"
$check5 = Select-String -Path $file -Pattern "SystemMouseCursors.resizeColumn"

if ($check1 -and $check2 -and $check3 -and $check4 -and $check5) {
  Write-Host "Patch applied and validation passed." -ForegroundColor Green
  Write-Host ""
  Write-Host "Rollback command:" -ForegroundColor Yellow
  Write-Host "Copy-Item `"$backupFile`" `"$file`" -Force"
} else {
  Copy-Item $backupFile $file -Force
  throw "Validation failed. Original file restored from backup."
}
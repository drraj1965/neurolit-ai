Write-Host "=== PHASE 6.4.3 — MORE PREVIEW + RICH MODAL ==="

$file = "lib/screens/home_screen.dart"
$backup = "_phase6_4_3_backup"

if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 1 — replace openAbstract()
# -------------------------
$openAbstractPattern = "void openAbstract\(Article a\) \{[\s\S]*?\n  \}"

$openAbstractReplacement = @'
void openAbstract(Article a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          a.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.authors,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  a.journal + " • " + a.date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "PMID: " + a.pmid,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                buildArticleBadges(a),
                if (a.publicationType.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Publication type: " + a.publicationType,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  "Abstract",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  a.abstractText,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => openPubMedLink(a.link),
                  child: Text(
                    a.link,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => appendToSession(buildAbstractBlock(a)),
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: a.abstractText));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Abstract copied")),
              );
            },
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () => openPubMedLink(a.link),
            child: const Text("Open in PubMed"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
'@

$newContent = [regex]::Replace($content, $openAbstractPattern, $openAbstractReplacement)

if ($newContent -eq $content) {
    Write-Host "❌ Could not replace openAbstract(). Restoring backup."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

$content = $newContent

# -------------------------
# STEP 2 — add More... line under snippet in buildArticlesList()
# -------------------------
if ($content -notmatch 'child: const Text\("More\.\.\."\)') {
    $snippetOld = @'
                          Text(
                            previewSnippet(a.abstractText),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
'@

    $snippetNew = @'
                          Text(
                            previewSnippet(a.abstractText),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => openAbstract(a),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text("More..."),
                            ),
                          ),
                          const SizedBox(height: 4),
'@

    $content = $content.Replace($snippetOld, $snippetNew)
}

# -------------------------
# VALIDATION
# -------------------------
if ($content -notmatch 'Publication type: ') {
    Write-Host "❌ Rich modal content missing. Restoring backup."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

if ($content -notmatch 'child: const Text\("More\.\.\."\)') {
    Write-Host "❌ More... preview link missing. Restoring backup."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.4.3 APPLIED"
Write-Host ""
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $backup/home_screen.dart.bak lib/screens/home_screen.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter run -d windows"
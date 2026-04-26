Write-Host "=== PHASE 6.4.2 — REPLACE buildArticlesList() ==="

$file = "lib/screens/home_screen.dart"
$backup = "_phase6_4_2_replace_list_backup"

if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

$pattern = "Widget buildArticlesList\(\) \{[\s\S]*?\n  \}"

$replacement = @'
Widget buildArticlesList() {
    return Expanded(
      child: ListView.builder(
        itemCount: pagedArticles.length,
        itemBuilder: (context, index) {
          final a = pagedArticles[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: InkWell(
              onTap: () => openAbstract(a),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: selectedPmids.contains(a.pmid),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedPmids.add(a.pmid);
                          } else {
                            selectedPmids.remove(a.pmid);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.authors,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.journal + " • " + a.date,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "PMID: " + a.pmid,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          buildArticleBadges(a),
                          const SizedBox(height: 8),
                          Text(
                            previewSnippet(a.abstractText),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => openPubMedLink(a.link),
                            child: Text(
                              a.link,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
'@

$newContent = [regex]::Replace($content, $pattern, $replacement)

if ($newContent -eq $content) {
    Write-Host "❌ Could not find buildArticlesList(). Restoring backup."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

Set-Content $file $newContent -Encoding UTF8

Write-Host ""
Write-Host "✅ buildArticlesList() replaced successfully"
Write-Host ""
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $backup/home_screen.dart.bak lib/screens/home_screen.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter run -d windows"
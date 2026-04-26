$root = 'C:\Users\drpha\Documents\Aster\neurolitApp\neurolitApp-April23\neurolit_review_app'
$backup = 'C:\Users\drpha\Documents\Aster\neurolitApp\neurolitApp-April23\neurolit_review_app\backup\20260426_180328'
Get-ChildItem -Path $backup -Recurse -File | ForEach-Object {
  $relative = $_.FullName.Substring($backup.Length + 1)
  $destination = Join-Path $root $relative
  New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
  Copy-Item $_.FullName $destination -Force
}
Write-Host 'Update system backup restored from C:\Users\drpha\Documents\Aster\neurolitApp\neurolitApp-April23\neurolit_review_app\backup\20260426_180328'

$resp = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/ilanlar' -UseBasicParsing
Write-Output "Status: $($resp.StatusCode)"

$cards = [regex]::Matches($resp.Content, '(?s)<div class="marketplace-card">.*?</div>\s*</div>')
Write-Output "Found $($cards.Count) cards on /ilanlar."

$imgMatches = [regex]::Matches($resp.Content, 'src="([^"]+)"')
foreach ($m in $imgMatches) {
  Write-Output "IMG SRC: $($m.Groups[1].Value)"
}

Write-Output "`n=== Checking Detail Page for Kaş Panorama ==="
$detail = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/ilan/1ca5af5c-3f37-4a49-8c6a-0220d588e467' -UseBasicParsing
Write-Output "Detail Status: $($detail.StatusCode)"
$detailImgs = [regex]::Matches($detail.Content, 'src="([^"]+)"')
foreach ($m in $detailImgs) {
  Write-Output "Detail IMG: $($m.Groups[1].Value)"
}

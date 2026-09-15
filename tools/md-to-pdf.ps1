<#
.SYNOPSIS
  Render a Markdown file to PDF using headless Chrome (no Python/pandoc needed on this machine).

  .\tools\md-to-pdf.ps1 -Markdown .\HAOS-INSTALL.md -Pdf "$env:USERPROFILE\Downloads\HAOS-INSTALL.pdf"

  Builds a throwaway HTML page that embeds the Markdown and renders it with marked.js (loaded from
  cdnjs, so it needs internet), then prints that page to PDF with Chrome. Letter size, print CSS
  tuned for a step-by-step guide read on a phone or paper.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Markdown,
    [Parameter(Mandatory)] [string] $Pdf,
    [string] $Title
)

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw "No Chrome or Edge found." }

$Markdown = (Resolve-Path $Markdown).Path
if (-not $Title) { $Title = [IO.Path]::GetFileNameWithoutExtension($Markdown) }
$md = [IO.File]::ReadAllText($Markdown, [Text.Encoding]::UTF8) -replace '</script', '<\/script'

$html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>$Title</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js"></script>
<style>
  @page { size: Letter; margin: 0.7in 0.7in 0.8in; }
  body { font: 11pt/1.45 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #111; max-width: 100%; }
  h1 { font-size: 20pt; margin: 0 0 4pt; }
  h2 { font-size: 14pt; margin: 18pt 0 6pt; padding-top: 6pt; border-top: 1.5px solid #222; page-break-after: avoid; }
  h3 { font-size: 12pt; margin: 12pt 0 4pt; page-break-after: avoid; }
  p, li { orphans: 3; widows: 3; }
  ol, ul { padding-left: 1.4em; }
  li { margin: 3pt 0; }
  li > ul, li > ol { margin-top: 2pt; }
  code { font: 9.5pt/1.3 Consolas, "Courier New", monospace; background: #f0f0f0; padding: 0 3px; border-radius: 3px; }
  pre { background: #f0f0f0; border: 1px solid #ccc; border-radius: 4px; padding: 8px 10px; margin: 6pt 0; page-break-inside: avoid; }
  pre code { background: none; padding: 0; white-space: pre-wrap; word-break: break-all; }
  table { border-collapse: collapse; width: 100%; margin: 8pt 0; font-size: 10pt; page-break-inside: auto; }
  tr { page-break-inside: avoid; }
  th, td { border: 1px solid #bbb; padding: 4pt 6pt; vertical-align: top; text-align: left; }
  th { background: #e8e8e8; }
  hr { border: 0; border-top: 1px solid #bbb; margin: 10pt 0; }
  strong { font-weight: 700; }
  a { color: #0645ad; text-decoration: none; word-break: break-all; }
</style></head>
<body>
<script type="text/plain" id="md">$md</script>
<div id="out"></div>
<script>
  document.getElementById('out').innerHTML = marked.parse(document.getElementById('md').textContent);
</script>
</body></html>
"@

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("md2pdf-" + [guid]::NewGuid().ToString('N') + ".html")
[IO.File]::WriteAllText($tmp, $html, [Text.UTF8Encoding]::new($false))

$Pdf = [IO.Path]::GetFullPath($Pdf)
$args = @(
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    '--no-pdf-header-footer', '--virtual-time-budget=15000',
    "--print-to-pdf=$Pdf", ('file:///' + ($tmp -replace '\\', '/'))
)
& $chrome @args 2>$null | Out-Null
Remove-Item $tmp -ErrorAction SilentlyContinue

if (Test-Path $Pdf) { Write-Host "Wrote $Pdf ($([math]::Round((Get-Item $Pdf).Length / 1KB)) KB)" }
else { throw "Chrome did not produce $Pdf" }

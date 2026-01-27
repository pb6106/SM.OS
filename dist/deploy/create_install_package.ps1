# create_install_package.ps1
# Generates a single Lua file `install_package.lua` that embeds project files
# for transferring to an OpenComputers machine. Excludes test and deploy folders by default.
#
# Usage: run from the repository root in PowerShell:
#   .\deploy\create_install_package.ps1

Param(
  [string]$OutFile = 'install_package.lua'
)

$excludeDirs = @('tests','deploy','archive_','\.git','\.vs')

Write-Host "Scanning project files..."
$files = Get-ChildItem -Recurse -File | Where-Object {
    $p = $_.FullName
    $keep = $true
    foreach ($e in $excludeDirs) {
        if ($p -match $e) { $keep = $false; break }
    }
    $keep
}

Write-Host "Found $($files.Count) files to package"

$out = @()
$out += '-- install_package.lua (auto-generated)'
$out += 'return {'

foreach ($f in $files) {
    $rel = $f.FullName.Substring((Get-Location).Path.Length + 1) -replace '\\','/'
    $content = Get-Content -Raw -Path $f.FullName
    # Use Lua long brackets to avoid escaping issues
    $out += ('[' + '"' + $rel + '"' + '] = [===[')
    $out += $content
    $out += ']===],'
}

$out += '}'

Write-Host "Writing package to $OutFile"
$out -join "`n" | Out-File -FilePath $OutFile -Encoding UTF8
Write-Host "Package created: $OutFile"

$ErrorActionPreference = "Stop"

$sdkDir = "C:\Users\amiel\AppData\Local\Android\Sdk"
$tempZip = "C:\Users\amiel\AppData\Local\Temp\cmdline-tools.zip"
$tempExtract = "C:\Users\amiel\AppData\Local\Temp\cmdline-tools-extract"

Write-Host "Creating SDK directory..."
New-Item -ItemType Directory -Force -Path $sdkDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempExtract | Out-Null

Write-Host "Downloading commandlinetools..."
curl.exe -L -o $tempZip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip

Write-Host "Extracting commandlinetools..."
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

$targetLatest = Join-Path $sdkDir "cmdline-tools\latest"
New-Item -ItemType Directory -Force -Path $targetLatest | Out-Null
Copy-Item -Path (Join-Path $tempExtract "cmdline-tools\*") -Destination $targetLatest -Recurse -Force

Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Command-line tools installed at: $targetLatest"
$sdkManager = Join-Path $targetLatest "bin\sdkmanager.bat"
Write-Host "sdkmanager exists: $(Test-Path $sdkManager)"

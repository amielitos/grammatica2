$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.2.13-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$sdkDir = "C:\Users\amiel\AppData\Local\Android\Sdk"
$sdkManager = "$sdkDir\cmdline-tools\latest\bin\sdkmanager.bat"

Write-Host "Installing platforms;android-36 and build tools..."
& $sdkManager --sdk_root=$sdkDir "platforms;android-36" "build-tools;36.0.0" "build-tools;35.0.0" "build-tools;28.0.3"

Write-Host "Writing accepted licenses..."
$licenseDir = Join-Path $sdkDir "licenses"
New-Item -ItemType Directory -Force -Path $licenseDir | Out-Null

$androidSdkLicense = @"
89337d0c0b186dd337a55c47e2014d96802e4567
24333f8a63b1d7f2e05de944470e83447682b92d
d56f5187479451eabf01fb78712b965f324874e4
"@

$androidSdkPreviewLicense = @"
84831b9409646a918e30573bab4c9c91346d8abd
504667f4c0de7af1a06de9f4b1727b84351f2910
"@

$androidSdkArmDpmLicense = @"
e9acab5b5fbb560a72cfaecce234608016095613
"@

$googleGviLicense = @"
601085b94cd77f0b54ff86406957099fed807233
"@

Set-Content -Path (Join-Path $licenseDir "android-sdk-license") -Value $androidSdkLicense
Set-Content -Path (Join-Path $licenseDir "android-sdk-preview-license") -Value $androidSdkPreviewLicense
Set-Content -Path (Join-Path $licenseDir "android-sdk-arm-dpm-license") -Value $androidSdkArmDpmLicense
Set-Content -Path (Join-Path $licenseDir "google-gvi-license") -Value $googleGviLicense

Write-Host "Done setting up SDK 36 and licenses."

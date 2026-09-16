$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.2.13-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$sdkDir = "C:\Users\amiel\AppData\Local\Android\Sdk"
$sdkManager = "$sdkDir\cmdline-tools\latest\bin\sdkmanager.bat"

Write-Host "Accepting licenses..."
$yesProcess = [System.Diagnostics.Process]::Start([System.Diagnostics.ProcessStartInfo]@{
    FileName = "cmd.exe"
    Arguments = "/c echo y | `"$sdkManager`" --sdk_root=`"$sdkDir`" --licenses"
    UseShellExecute = $false
    RedirectStandardOutput = $true
    RedirectStandardError = $true
})
$yesProcess.WaitForExit()

Write-Host "Installing platform-tools, platforms;android-35, build-tools;35.0.0..."
& $sdkManager --sdk_root=$sdkDir "platform-tools" "platforms;android-35" "build-tools;35.0.0"

Write-Host "SDK components installed successfully."

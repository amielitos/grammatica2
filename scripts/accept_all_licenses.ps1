$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.2.13-hotspot"
$env:Path = "C:\Program Files\Git\cmd;$env:JAVA_HOME\bin;$env:Path"

$sdkDir = "C:\Users\amiel\AppData\Local\Android\Sdk"
$sdkManager = "$sdkDir\cmdline-tools\latest\bin\sdkmanager.bat"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $sdkManager
$psi.Arguments = "--sdk_root=`"$sdkDir`" --licenses"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::Start($psi)

for ($i = 0; $i -lt 30; $i++) {
    $process.StandardInput.WriteLine("y")
    Start-Sleep -Milliseconds 100
}
$process.StandardInput.Flush()
$process.StandardInput.Close()

$output = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()

Write-Host "Output: $output"

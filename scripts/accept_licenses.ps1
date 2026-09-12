$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "flutter.bat"
$psi.Arguments = "doctor --android-licenses"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::Start($psi)

for ($i = 0; $i -lt 15; $i++) {
    $process.StandardInput.WriteLine("y")
}
$process.StandardInput.Flush()
$process.StandardInput.Close()

$output = $process.StandardOutput.ReadToEnd()
$errorOut = $process.StandardError.ReadToEnd()
$process.WaitForExit()

Write-Host "Output: $output"
Write-Host "Error: $errorOut"

# Convenience script to build Flutter Web with .env variables embedded
Write-Host "Building Flutter Web with environment variables from .env..." -ForegroundColor Cyan
flutter build web --dart-define-from-file=.env
if ($LASTEXITCODE -eq 0) {
    Write-Host "Build complete! You can deploy now by running: firebase deploy --only hosting" -ForegroundColor Green
} else {
    Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}

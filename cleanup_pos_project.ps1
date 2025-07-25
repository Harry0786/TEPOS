# PowerShell script to cleanup TEPOS POS project
# Usage: .\cleanup_pos_project.ps1

Write-Host "🧹 Cleaning up TEPOS POS project..." -ForegroundColor Green

# Navigate to project root (if not already there)
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

# Clean Flutter build artifacts
Write-Host "📦 Cleaning Flutter build files..." -ForegroundColor Yellow
Set-Location "point_of_scale"
flutter clean

# Remove any remaining build artifacts that might exist
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\app\.cxx" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue

# Clean Android build files
Write-Host "🤖 Cleaning Android build files..." -ForegroundColor Yellow
Set-Location "android"
if (Test-Path ".\gradlew.bat") {
    .\gradlew.bat clean
}
Set-Location ".."

# Return to project root
Set-Location ".."

# Remove redundant documentation files
Write-Host "📄 Removing redundant documentation..." -ForegroundColor Yellow
$redundantDocs = @(
    "ASYNC_CONVERSION_SUMMARY.md",
    "FREEZING_FIXES_SUMMARY.md", 
    "REALTIME_SYNC_IMPROVEMENTS.md",
    "point_of_scale\BACKEND_LOAD_OPTIMIZATION.md",
    "point_of_scale\DELETE_ORDER_FIXES.md",
    "point_of_scale\ESTIMATE_SENDING_GUIDE.md",
    "point_of_scale\PAYMENT_BREAKDOWN_IMPLEMENTATION.md",
    "point_of_scale\PERFORMANCE_FIXES.md",
    "point_of_scale\STABILITY_FIXES.md",
    "point_of_scale\WHATSAPP_INTEGRATION_GUIDE.md",
    "pos_backend\REPORTS_API_DOCUMENTATION.md"
)

foreach ($doc in $redundantDocs) {
    Remove-Item -Path $doc -Force -ErrorAction SilentlyContinue
    if (Test-Path $doc) {
        Write-Host "❌ Failed to remove: $doc" -ForegroundColor Red
    } else {
        Write-Host "✅ Removed: $doc" -ForegroundColor Green
    }
}

# Remove generated files
Write-Host "🔧 Removing generated files..." -ForegroundColor Yellow
$generatedFiles = @(
    "point_of_scale\icon_generator_app.dart",
    "point_of_scale\icon_generator.dart",
    "point_of_scale\icon_generator.html",
    "point_of_scale\test_delete_fix.dart",
    "point_of_scale\test_optimization.dart",
    "point_of_scale\test_payment_dialog.dart",
    "point_of_scale\test_pdf.dart",
    "point_of_scale\test_stability.dart"
)

foreach ($file in $generatedFiles) {
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    if (Test-Path $file) {
        Write-Host "❌ Failed to remove: $file" -ForegroundColor Red
    } else {
        Write-Host "✅ Removed: $file" -ForegroundColor Green
    }
}

# Optional: Remove IDE files (uncomment if desired)
# Write-Host "💻 Removing IDE files..." -ForegroundColor Yellow
# Remove-Item -Path ".idea" -Recurse -Force -ErrorAction SilentlyContinue
# Remove-Item -Path ".vscode" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host "💡 Run 'flutter pub get' in point_of_scale/ to restore dependencies" -ForegroundColor Cyan

# Restore Flutter dependencies
Write-Host "📦 Restoring Flutter dependencies..." -ForegroundColor Yellow
Set-Location "point_of_scale"
flutter pub get
Set-Location ".."

Write-Host "🎉 Project cleanup and restoration complete!" -ForegroundColor Green

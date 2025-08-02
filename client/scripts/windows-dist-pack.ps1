# ================== Configurable Section ==================
# Directory containing the built executable(s)
$SrcDir = "build/windows/x64/runner/Release"
# Output directory for the zip file
$DistDir = "build/windows/dist"
# Version number (must be provided as the first command-line argument)
if ($args.Count -lt 1 -or [string]::IsNullOrWhiteSpace($args[0])) {
    Write-Host "Usage: pwsh ./windows-dist-pack.ps1 <version>" -ForegroundColor Yellow
    exit 1
}
$Version = $args[0]
# Name of the output zip file
$ZipName = "borneo-app-$Version-windows-x64.zip"
# Additional files to include (relative to project root)
$ExtraFiles = @(
    Join-Path ".." "LICENSE"
    Join-Path ".." "README.md"
)
# ================== End Config ============================

# Create output directory if it does not exist
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Force -Path $DistDir | Out-Null }

# Full path for the output zip file
$ZipPath = Join-Path $DistDir $ZipName

# Remove existing zip file if present to ensure clean overwrite
if (Test-Path $ZipPath) { 
    Remove-Item $ZipPath -Force
    Write-Host "Removed existing zip file: $ZipPath" -ForegroundColor Yellow
}

# Use current working directory as the project root
$ProjectRoot = Get-Location

# Step 1: Compress the contents of the Release directory (without the Release folder itself)
$SrcDirContents = Join-Path $SrcDir "*"
Compress-Archive -Path $SrcDirContents -DestinationPath $ZipPath -Force

# Step 2: Add extra files to the root of the zip
foreach ($file in $ExtraFiles) {
    $fullPath = Join-Path $ProjectRoot $file
    if (Test-Path $fullPath) {
        Compress-Archive -Path $fullPath -DestinationPath $ZipPath -Update
    } else {
        Write-Warning "File not found: $file"
    }
}

Write-Host "Packaging complete: $ZipPath"

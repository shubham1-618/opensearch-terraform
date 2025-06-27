# PowerShell script to prepare Lambda packages with dependencies
Write-Host "Preparing Lambda packages with dependencies..."

# Prepare IAM Mapper Lambda
Write-Host "Preparing IAM Mapper Lambda..."
$iamMapperDir = "lambda/iam_mapper"
$iamMapperPackageDir = "$iamMapperDir/package"

# Create package directory if it doesn't exist
if (-not (Test-Path $iamMapperPackageDir)) {
    New-Item -ItemType Directory -Path $iamMapperPackageDir -Force | Out-Null
}

# Install dependencies into the package directory
pip install -r "$iamMapperDir/requirements.txt" -t $iamMapperPackageDir

# Copy the Lambda code to the package directory
Copy-Item "$iamMapperDir/index.py" -Destination $iamMapperPackageDir

# Prepare Snapshot Lambda
Write-Host "Preparing Snapshot Lambda..."
$snapshotDir = "lambda/snapshot"
$snapshotPackageDir = "$snapshotDir/package"

# Create package directory if it doesn't exist
if (-not (Test-Path $snapshotPackageDir)) {
    New-Item -ItemType Directory -Path $snapshotPackageDir -Force | Out-Null
}

# Install dependencies into the package directory
pip install -r "$snapshotDir/requirements.txt" -t $snapshotPackageDir

# Copy the Lambda code to the package directory
Copy-Item "$snapshotDir/index.py" -Destination $snapshotPackageDir

Write-Host "Lambda packages prepared successfully!" 
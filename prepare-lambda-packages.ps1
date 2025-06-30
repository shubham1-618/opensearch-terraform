# PowerShell script to prepare Lambda packages with dependencies
Write-Host "Preparing Lambda packages with dependencies..."

# Create the output directory for Lambda zip files
$outputDir = "terraform/modules/lambda/files"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

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

# Create the zip file for Terraform
Compress-Archive -Path "$iamMapperPackageDir/*" -DestinationPath "$outputDir/opensearch-iam-user-mapper.zip" -Force

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

# Create the zip file for Terraform
Compress-Archive -Path "$snapshotPackageDir/*" -DestinationPath "$outputDir/opensearch-snapshot-lambda.zip" -Force

# Prepare Role Mapper Lambda
Write-Host "Preparing Role Mapper Lambda..."
$roleMapperDir = "lambda/role_mapper"
$roleMapperPackageDir = "$roleMapperDir/package"

# Create package directory if it doesn't exist
if (-not (Test-Path $roleMapperDir)) {
    New-Item -ItemType Directory -Path $roleMapperDir -Force | Out-Null
}

# Create package directory if it doesn't exist
if (-not (Test-Path $roleMapperPackageDir)) {
    New-Item -ItemType Directory -Path $roleMapperPackageDir -Force | Out-Null
}

# Install dependencies into the package directory
pip install -r "$roleMapperDir/requirements.txt" -t $roleMapperPackageDir

# Copy the Lambda code to the package directory
Copy-Item "$roleMapperDir/index.py" -Destination $roleMapperPackageDir

# Create the zip file for Terraform
Compress-Archive -Path "$roleMapperPackageDir/*" -DestinationPath "$outputDir/opensearch-role-mapper.zip" -Force

Write-Host "Lambda packages prepared successfully!" 
param(
    [string]$EnvFile  = ".env",
    [string]$YamlFile = "C:\Users\nsouther\source\JumpStart Practice Projects\Eval Demo - Open Hands\config\openhands-dev-container.yaml",
    [string]$ResourceGroup = "brownfield-evals-experiment"
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1. Validate input files
# ------------------------------------------------------------

if (-not (Test-Path $EnvFile)) {
    throw "Environment file not found: $EnvFile"
}

if (-not (Test-Path $YamlFile)) {
    throw "YAML template not found: $YamlFile"
}

# ------------------------------------------------------------
# 2. Load .env values
#
# Supports:
#   KEY=value
#   KEY="value"
#   KEY='value'
#   # comments
#
# Split only on the FIRST '=' because secrets may contain '='.
# ------------------------------------------------------------

$envValues = @{}

Get-Content $EnvFile | ForEach-Object {

    $line = $_.Trim()

    # Ignore blank lines and comments
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
        return
    }

    $parts = $line -split "=", 2

    if ($parts.Count -ne 2) {
        Write-Warning "Ignoring malformed .env line."
        return
    }

    $key   = $parts[0].Trim()
    $value = $parts[1].Trim()

    # Remove matching surrounding quotes
    if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    $envValues[$key] = $value
}

Write-Host "Loaded $($envValues.Count) values from $EnvFile" -ForegroundColor Green

# ------------------------------------------------------------
# 3. Read YAML template
# ------------------------------------------------------------

$yaml = Get-Content $YamlFile -Raw

# ------------------------------------------------------------
# 4. Find ${VARIABLE_NAME} placeholders and replace them
# ------------------------------------------------------------

$placeholderPattern = '\$\{([A-Za-z_][A-Za-z0-9_]*)\}'

$regexMatches = [regex]::Matches($yaml, $placeholderPattern)

foreach ($match in $regexMatches) {

    $placeholder = $match.Value
    $key = $match.Groups[1].Value

    if (-not $envValues.ContainsKey($key)) {
        throw "YAML references '$key', but it was not found in $EnvFile"
    }

    $value = $envValues[$key]

    # Escape '$' so Regex.Replace does not interpret it as
    # a replacement expression.
    $safeValue = $value.Replace('$', '$$')

    $yaml = $yaml.Replace($placeholder, $safeValue)
}

# ------------------------------------------------------------
# 5. Make sure we didn't miss any placeholders
# ------------------------------------------------------------

$remaining = [regex]::Matches($yaml, $placeholderPattern)

if ($remaining.Count -gt 0) {

    $names = $remaining |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique

    throw "Unresolved YAML placeholders: $($names -join ', ')"
}

# ------------------------------------------------------------
# 6. Create temporary deployment YAML
# ------------------------------------------------------------

$tempYaml = Join-Path $env:TEMP "aci-deploy-$([guid]::NewGuid().ToString('N')).yaml"

try {

    $yaml | Set-Content `
        -Path $tempYaml `
        -Encoding utf8

    Write-Host "Generated temporary deployment YAML." -ForegroundColor Green

    # --------------------------------------------------------
    # 7. Verify Azure subscription before deployment
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Current Azure context:" -ForegroundColor Cyan

    az account show `
        --query "{Subscription:name, SubscriptionId:id, Tenant:tenantId}" `
        -o table

    # --------------------------------------------------------
    # 8. Deploy ACI
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Deploying Azure Container Instance..." -ForegroundColor Cyan

    az container create `
        --resource-group $ResourceGroup `
        --file $tempYaml

    if ($LASTEXITCODE -ne 0) {
        throw "az container create failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "ACI deployment submitted successfully." -ForegroundColor Green
}
finally {

    # --------------------------------------------------------
    # 9. Delete YAML containing expanded secrets
    # --------------------------------------------------------

    if (Test-Path $tempYaml) {
        Remove-Item $tempYaml -Force
        Write-Host "Temporary deployment YAML deleted." -ForegroundColor DarkGray
    }
}
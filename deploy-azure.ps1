param(
    [string]$AzCliPath = 'C:\Users\zzz45\Documents\Codex\2026-11-03\cj\work\azure-cli\bin\az.cmd',
    [string]$ResourceGroupName = 'rg-test-a-20261103',
    [string]$Location = 'koreacentral',
    [string]$PlanName = 'test-a-free-20261103',
    [ValidateSet('F1')]
    [string]$Sku = 'F1',
    [string]$WebAppName = 'test-a-jangseungun-20261103',
    [ValidateSet('PYTHON:3.12')]
    [string]$PythonRuntime = 'PYTHON:3.12',
    [ValidateRange(1, 65535)]
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $AzCliPath -PathType Leaf)) {
    throw "Azure CLI executable not found: $AzCliPath"
}

function Invoke-Az {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & $AzCliPath @Arguments --only-show-errors
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Azure CLI command failed with exit code $exitCode."
    }
}

function Invoke-AzJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & $AzCliPath @Arguments --only-show-errors --output json
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Azure CLI query failed with exit code $exitCode."
    }
    if (-not $output) {
        throw 'Azure CLI returned no JSON for a resource query.'
    }

    return ($output -join [Environment]::NewLine | ConvertFrom-Json -ErrorAction Stop)
}

function Invoke-AzText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & $AzCliPath @Arguments --only-show-errors --output tsv
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Azure CLI context query failed with exit code $exitCode."
    }

    $value = ($output -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Azure CLI returned no value for a required resource scope.'
    }
    return $value
}

function Get-ArmResource {
    param([Parameter(Mandatory = $true)][string]$Url)

    $output = & $AzCliPath rest --method get --url $Url --only-show-errors --output json 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $diagnostic = ($output | ForEach-Object { $_.ToString() }) -join ' '
        if ($diagnostic -match '(?i)\bResourceNotFound\b|\bStatusCode:\s*404\b|\b404\s+Not Found\b') {
            return $null
        }
        throw "Azure ARM resource GET failed with exit code $exitCode."
    }
    if (-not $output) {
        throw 'Azure ARM resource GET returned no JSON.'
    }

    return ($output -join [Environment]::NewLine | ConvertFrom-Json -ErrorAction Stop)
}

function Normalize-Location {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value -replace '\s', '').ToLowerInvariant()
}

function Assert-FreeLinuxPlan {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$ExpectedLocation
    )

    if ($Plan.sku.name -ne 'F1' -or $Plan.sku.tier -ne 'Free') {
        throw "Refusing to use plan SKU '$($Plan.sku.name)' / tier '$($Plan.sku.tier)'; only free F1 is allowed."
    }
    if ($Plan.properties.reserved -ne $true -or $Plan.kind -notmatch '(?i)(^|,)\s*linux\s*(,|$)') {
        throw 'Refusing to use a Windows App Service plan; a Linux plan is required.'
    }
    if ((Normalize-Location $Plan.location) -ne (Normalize-Location $ExpectedLocation)) {
        throw "Existing plan is in '$($Plan.location)', not '$ExpectedLocation'."
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "test-a-azure-$([guid]::NewGuid().ToString('N'))"

try {
    $subscriptionId = Invoke-AzText @('account', 'show', '--query', 'id')
    if ($subscriptionId -notmatch '^[0-9a-fA-F-]{36}$') {
        throw 'Azure CLI did not return a valid subscription ID.'
    }

    $groupExists = Invoke-AzJson @(
        'group', 'exists',
        '--name', $ResourceGroupName
    )
    if ($groupExists -ne $true -and $groupExists -ne 'true') {
        Write-Host "Creating resource group $ResourceGroupName in $Location."
        Invoke-Az @(
            'group', 'create',
            '--name', $ResourceGroupName,
            '--location', $Location,
            '--output', 'none'
        )
    }

    $resourceScope = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web"
    $planUrl = "$resourceScope/serverfarms/$PlanName?api-version=2023-12-01"
    $plan = Get-ArmResource -Url $planUrl
    if ($null -eq $plan) {
        Write-Host "Creating Linux App Service plan $PlanName with free F1 SKU."
        Invoke-Az @(
            'appservice', 'plan', 'create',
            '--name', $PlanName,
            '--resource-group', $ResourceGroupName,
            '--location', $Location,
            '--sku', $Sku,
            '--is-linux',
            '--output', 'none'
        )
        $plan = Get-ArmResource -Url $planUrl
        if ($null -eq $plan) {
            throw "App Service plan '$PlanName' was not found after creation."
        }
    }
    Assert-FreeLinuxPlan -Plan $plan -ExpectedLocation $Location

    $appUrl = "$resourceScope/sites/$WebAppName?api-version=2023-12-01"
    $app = Get-ArmResource -Url $appUrl
    if ($null -eq $app) {
        Write-Host "Creating Python 3.12 web app $WebAppName on the F1 plan."
        Invoke-Az @(
            'webapp', 'create',
            '--name', $WebAppName,
            '--resource-group', $ResourceGroupName,
            '--plan', $PlanName,
            '--runtime', $PythonRuntime,
            '--output', 'none'
        )
        $app = Get-ArmResource -Url $appUrl
        if ($null -eq $app) {
            throw "Web app '$WebAppName' was not found after creation."
        }
    }
    if ($app.properties.serverFarmId -ne $plan.id) {
        throw 'Existing web app is attached to a different App Service plan; refusing to change it.'
    }
    if ((Normalize-Location $app.location) -ne (Normalize-Location $Location)) {
        throw "Existing web app is in '$($app.location)', not '$Location'."
    }
    if ($app.properties.siteConfig.linuxFxVersion -ne 'PYTHON|3.12') {
        throw "Existing web app runtime is '$($app.properties.siteConfig.linuxFxVersion)', not PYTHON|3.12."
    }

    Write-Host 'Setting the app startup command and port.'
    Invoke-Az @(
        'webapp', 'config', 'set',
        '--resource-group', $ResourceGroupName,
        '--name', $WebAppName,
        '--startup-file', 'python main.py',
        '--output', 'none'
    )
    Invoke-Az @(
        'webapp', 'config', 'appsettings', 'set',
        '--resource-group', $ResourceGroupName,
        '--name', $WebAppName,
        '--settings', "PORT=$Port", 'SCM_DO_BUILD_DURING_DEPLOYMENT=true',
        '--output', 'none'
    )

    $appFiles = @('main.py', 'recommend.py', 'places.json', 'index.html', 'app.js', 'styles.css')
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    foreach ($file in $appFiles) {
        $source = Join-Path $PSScriptRoot $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required application file not found: $file"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $tempRoot $file)
    }

    $zipPath = Join-Path ([IO.Path]::GetTempPath()) "test-a-azure-$([guid]::NewGuid().ToString('N')).zip"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $tempRoot,
            $zipPath,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )
        Write-Host 'Deploying application ZIP.'
        Invoke-Az @(
            'webapp', 'deploy',
            '--resource-group', $ResourceGroupName,
            '--name', $WebAppName,
            '--src-path', $zipPath,
            '--type', 'zip',
            '--clean', 'true',
            '--output', 'none'
        )
    }
    finally {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
    }

    $url = "https://$WebAppName.azurewebsites.net"
    Write-Host "Waiting for HTTPS checks at $url."
    $lastCheckError = $null
    $verified = $false
    for ($attempt = 1; $attempt -le 18; $attempt++) {
        try {
            $page = Invoke-WebRequest -Uri "$url/" -UseBasicParsing -TimeoutSec 20
            if ($page.StatusCode -ne 200 -or
                $page.Content -notmatch '<title>안녕하세요 장승운</title>' -or
                $page.Content -notmatch '<h1>안녕하세요 장승운</h1>') {
                throw 'The deployed page did not return the expected title and heading.'
            }

            $api = Invoke-WebRequest -Uri "$url/api/places" -UseBasicParsing -TimeoutSec 20
            $places = @($api.Content | ConvertFrom-Json -ErrorAction Stop)
            if ($api.StatusCode -ne 200 -or $places.Count -ne 10) {
                throw "The deployed places API returned $($places.Count) entries; expected 10."
            }

            $verified = $true
            break
        }
        catch {
            $lastCheckError = $_.Exception.Message
            if ($attempt -lt 18) {
                Start-Sleep -Seconds 10
            }
        }
    }
    if (-not $verified) {
        throw "HTTPS verification failed after deployment: $lastCheckError"
    }

    Write-Host 'Verified: exact page title and heading, plus 10 API places.'
    Write-Output $url
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

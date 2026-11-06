# AzureConnectedMachineDscv3

DSC resource for managing Azure Arc for Servers agent configuration.

This repository ships two implementations:

- A DSC v3 command resource: `Microsoft.Azure.Arc/AgentConfiguration` (in `dsc_resources`)
- A class-based PowerShell DSC resource: `AzureArcAgentConfiguration` in the `AzureConnectedMachineDscv3` module (in `AzureConnectedMachineDscv3`)

Documentation:

- [DSC v3 resource parameters](docs/azure_arc_agent-parameters.md)
- [DSC v3 operation examples](docs/azure_arc_agent-operations-examples.md)
- [PowerShell module usage](docs/AzureConnectedMachineDsc-powershell-module.md)

## Prerequisites

- Windows PowerShell 7 (`pwsh`) available in `PATH`
- Azure Arc agent installed (`azcmagent` command available)
- Administrator session for `set` operations (resource requires elevated security context)

## Install DSC v3

### Stable

```powershell
winget install --id Microsoft.DSC --exact --source winget
```

### Preview (optional)

```powershell
winget install --id Microsoft.DSC.Preview --exact --source winget
```

### Verify installation

```powershell
dsc --version
```

## Make the resource discoverable

This repository keeps the resource files in `dsc_resources`.

You can use one of two methods:

### Method 1 (recommended): set `DSC_RESOURCE_PATH`

```powershell
$repoRoot = "D:\Git\AzureConnectedMachineDsc"
$env:DSC_RESOURCE_PATH = Join-Path $repoRoot 'dsc_resources'

# Optional: persist for future sessions
[System.Environment]::SetEnvironmentVariable('DSC_RESOURCE_PATH', $env:DSC_RESOURCE_PATH, 'User')
```

### Method 2: copy resource files to DSC root folder

```powershell
$repoRoot = "D:\Git\AzureConnectedMachineDsc"
$resourceSource = Join-Path $repoRoot 'dsc_resources\*'
$dscRoot = Split-Path (Get-Command dsc -ErrorAction Stop).Source -Parent

Copy-Item -Path $resourceSource -Destination $dscRoot -Recurse -Force
```

## Quick validation

```powershell
# List resources and confirm the custom type is found
dsc resource list | Select-String 'Microsoft.Azure.Arc/AgentConfiguration'

# Get current state
'{}' | dsc resource get -r Microsoft.Azure.Arc/AgentConfiguration -f - | ConvertFrom-Json
```

## Use the PowerShell module

The `AzureConnectedMachineDscv3` module exposes the class-based `AzureArcAgentConfiguration` DSC resource for Windows PowerShell 5.1, PowerShell 7 (`Invoke-DscResource`), and the DSC v3 `Microsoft.DSC/PowerShell` adapter.

```powershell
# Install: copy the module to a PSModulePath location
$repoRoot = "D:\Git\AzureConnectedMachineDscV3"
Copy-Item -Path (Join-Path $repoRoot 'AzureConnectedMachineDscv3') `
    -Destination (Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\AzureConnectedMachineDscv3') `
    -Recurse -Force

# Verify discovery
Get-DscResource -Name AzureArcAgentConfiguration -Module AzureConnectedMachineDscv3

# Read current state
Invoke-DscResource -Name AzureArcAgentConfiguration -ModuleName AzureConnectedMachineDscv3 `
    -Method Get -Property @{ IsSingleInstance = 'Yes' }
```

See [PowerShell module usage](docs/AzureConnectedMachineDsc-powershell-module.md) for the full property reference and examples, and [dsc_config_example/ArcAgentConfiguration.ps1](dsc_config_example/ArcAgentConfiguration.ps1) for a MOF-based configuration example.

Existing configurations using `AzureConnectedMachineDsc` must be updated to use `AzureConnectedMachineDscv3`, including DSC v3 adapter resource types. The DSC resource name remains `AzureArcAgentConfiguration`.

## Run tests

```powershell
Set-Location D:\Git\AzureConnectedMachineDsc\dsc_resources\tests
$env:DSC_RESOURCE_PATH = "D:\Git\AzureConnectedMachineDsc\dsc_resources"
Invoke-Pester -Path .\azure_arc_agent.tests.ps1 -Output Detailed
```

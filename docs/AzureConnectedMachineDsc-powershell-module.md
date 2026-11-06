# AzureConnectedMachineDscv3 PowerShell module

This document describes how to install and use the class-based PowerShell DSC resource shipped in this repository:

- Module: `AzureConnectedMachineDscv3` (folder `AzureConnectedMachineDscv3`)
- DSC resource: `AzureArcAgentConfiguration`

The resource manages the local Azure Arc for Servers agent (`azcmagent`) configuration. It is the PowerShell counterpart of the DSC v3 command resource `Microsoft.Azure.Arc/AgentConfiguration` (see [azure_arc_agent-parameters.md](./azure_arc_agent-parameters.md)).

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Azure Arc agent installed (`azcmagent` command available in `PATH`)
- Elevated (Administrator) session for `Set` operations

## Install the module

### Install from the PowerShell Gallery

```powershell
Install-Module -Name AzureConnectedMachineDscv3
```

### Install from a local checkout

Copy the module folder to a location listed in `$env:PSModulePath`. The path below is shared by Windows PowerShell 5.1 and PowerShell 7:

```powershell
$repoRoot = "D:\Git\AzureConnectedMachineDscV3"
$destination = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\AzureConnectedMachineDscv3'

Copy-Item -Path (Join-Path $repoRoot 'AzureConnectedMachineDscv3') -Destination $destination -Recurse -Force
```

Verify that the resource is discoverable:

```powershell
Get-DscResource -Name AzureArcAgentConfiguration -Module AzureConnectedMachineDscv3
```

## Resource properties

| Property | Type | Qualifier | Allowed values | Notes |
|---|---|---|---|---|
| IsSingleInstance | string | Key | Yes | Singleton key. The resource configures the machine-wide agent, so only one instance is supported. |
| IncomingConnectionsEnabled | boolean or null | Write | true, false, null | Maps to azcmagent config key incomingconnections.enabled. |
| GuestConfigurationEnabled | boolean or null | Write | true, false, null | Maps to azcmagent config key guestconfiguration.enabled. |
| ExtensionsEnabled | boolean or null | Write | true, false, null | Maps to azcmagent config key extensions.enabled. |
| ExtensionAllowlist | string[] | Write | list of extension names | Maps to azcmagent config key extensions.allowlist. Empty list is allowed. |
| ExtensionBlocklist | string[] | Write | list of extension names | Maps to azcmagent config key extensions.blocklist. Empty list is allowed. |
| ConfigMode | ArcConfigMode or null | Write | Monitor, Full | Maps to azcmagent config key config.mode. |
| ProxyUrl | string | Write | any string | Maps to azcmagent config key proxy.url. |
| AgentInstalled | boolean | Read | true, false | Reports whether the azcmagent executable was found. Not configurable. |

## Behavior notes

- Only properties you set (non-null) are compared and enforced; unset properties are left unchanged.
- `ExtensionAllowlist` and `ExtensionBlocklist` are normalized before comparison (trimmed, deduplicated, sorted), so item order does not matter.
- Setting `ConfigMode = 'Full'` transitions the agent through `monitor` before applying `full`, as required by azcmagent.
- `Test` returns false when the azcmagent executable is not found.
- `Set` throws when the azcmagent executable is not found. Install the Azure Connected Machine agent first.

## Use with Invoke-DscResource (PowerShell 7)

Requires the `PSDesiredStateConfiguration` module (v2.x) on PowerShell 7:

```powershell
Install-Module -Name PSDesiredStateConfiguration -RequiredVersion 2.0.7 -Scope CurrentUser

$property = @{
    IsSingleInstance           = 'Yes'
    GuestConfigurationEnabled  = $true
    ExtensionsEnabled          = $true
    ExtensionAllowlist         = @('Microsoft.Azure.Monitor/AzureMonitorWindowsAgent')
    ConfigMode                 = 'Full'
}

# Read current state
Invoke-DscResource -Name AzureArcAgentConfiguration -ModuleName AzureConnectedMachineDscv3 `
    -Method Get -Property @{ IsSingleInstance = 'Yes' }

# Check for drift
Invoke-DscResource -Name AzureArcAgentConfiguration -ModuleName AzureConnectedMachineDscv3 `
    -Method Test -Property $property

# Apply desired state (elevated session)
Invoke-DscResource -Name AzureArcAgentConfiguration -ModuleName AzureConnectedMachineDscv3 `
    -Method Set -Property $property
```

## Use with a Configuration and MOF (Windows PowerShell 5.1)

A complete example is available in [dsc_config_example/ArcAgentConfiguration.ps1](../dsc_config_example/ArcAgentConfiguration.ps1):

```powershell
Configuration ArcAgentConfiguration
{
    Import-DscResource -ModuleName 'AzureConnectedMachineDscv3'

    Node 'localhost'
    {
        AzureArcAgentConfiguration 'ArcAgent'
        {
            IsSingleInstance           = 'Yes'
            IncomingConnectionsEnabled = $true
            GuestConfigurationEnabled  = $true
            ExtensionsEnabled          = $true
            ExtensionAllowlist         = @('Microsoft.Azure.Monitor/AzureMonitorWindowsAgent')
            ExtensionBlocklist         = @()
            ConfigMode                 = 'Full'
            ProxyUrl                   = ''
        }
    }
}

# Compile the configuration into a MOF document:
ArcAgentConfiguration -OutputPath .\ArcAgentConfiguration

# Apply it (elevated):
Start-DscConfiguration -Path .\ArcAgentConfiguration -Wait -Verbose -Force

# Test / Get current state:
Test-DscConfiguration -Path .\ArcAgentConfiguration
Get-DscConfiguration
```

## Use with DSC v3 through the PowerShell adapter

When the module is installed in a `$env:PSModulePath` location, DSC v3 can use it through the `Microsoft.DSC/PowerShell` adapter. The adapted resource type is `AzureConnectedMachineDscv3/AzureArcAgentConfiguration`:

```powershell
dsc resource list --adapter Microsoft.DSC/PowerShell AzureConnectedMachineDscv3/AzureArcAgentConfiguration
```

Example configuration document:

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Azure Arc agent (PowerShell class resource)
    type: Microsoft.DSC/PowerShell
    properties:
      resources:
        - name: ArcAgent
          type: AzureConnectedMachineDscv3/AzureArcAgentConfiguration
          properties:
            IsSingleInstance: 'Yes'
            GuestConfigurationEnabled: true
            ExtensionsEnabled: true
            ExtensionAllowlist:
              - Microsoft.Azure.Monitor/AzureMonitorWindowsAgent
            ConfigMode: Full
```

```powershell
dsc config get --file .\arc-agent-powershell.dsc.yaml
dsc config test --file .\arc-agent-powershell.dsc.yaml
dsc config set --file .\arc-agent-powershell.dsc.yaml   # elevated session
```

> Note: if you only need DSC v3, consider the native command resource `Microsoft.Azure.Arc/AgentConfiguration` documented in [azure_arc_agent-parameters.md](./azure_arc_agent-parameters.md) and [azure_arc_agent-operations-examples.md](./azure_arc_agent-operations-examples.md).

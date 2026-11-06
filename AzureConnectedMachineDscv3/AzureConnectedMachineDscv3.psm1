# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Enums

enum Ensure
{
    Absent
    Present
}

enum ArcConfigMode
{
    Monitor
    Full
}

#endregion Enums

#region Helper functions

# Maps class property names to the azcmagent configuration property names.
$script:PropertyMap = @{
    IncomingConnectionsEnabled = 'incomingconnections.enabled'
    GuestConfigurationEnabled  = 'guestconfiguration.enabled'
    ExtensionsEnabled          = 'extensions.enabled'
    ExtensionAllowlist         = 'extensions.allowlist'
    ExtensionBlocklist         = 'extensions.blocklist'
    ConfigMode                 = 'config.mode'
    ProxyUrl                   = 'proxy.url'
}

<#
.SYNOPSIS
Resolves the azcmagent executable path from PATH.
#>
function Find-AzcmAgentCommand
{
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $command = Get-Command -Name 'azcmagent' -ErrorAction SilentlyContinue
    if ($null -eq $command)
    {
        return $null
    }

    return $command.Source
}

<#
.SYNOPSIS
Normalizes list-like values to a trimmed, deduplicated, sorted string array.
#>
function ConvertTo-NormalizedStringList
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param
    (
        [Parameter()]
        [AllowNull()]
        [object]
        $Value
    )

    if ($null -eq $Value)
    {
        return @()
    }

    $items = @()

    if ($Value -is [string])
    {
        $stringValue = $Value.Trim()

        # azcmagent can return lists in bracket notation, e.g.
        # [Microsoft.Azure.Monitor/AzureMonitorWindowsAgent] or []
        if ($stringValue -match '^\[(.*)\]$')
        {
            $stringValue = $Matches[1]
        }

        if (-not [string]::IsNullOrWhiteSpace($stringValue))
        {
            $items = $stringValue -split ','
        }
    }
    elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
    {
        foreach ($item in $Value)
        {
            if ($item -is [string])
            {
                $itemString = $item.Trim()
                if ($itemString -match '^\[(.*)\]$')
                {
                    $itemString = $Matches[1]
                }

                if (-not [string]::IsNullOrWhiteSpace($itemString))
                {
                    $items += ($itemString -split ',')
                }
            }
            elseif ($null -ne $item)
            {
                $items += [string] $item
            }
        }
    }
    else
    {
        $items = @([string] $Value)
    }

    $normalizedItems = @(
        $items |
            ForEach-Object { $_.Trim().Trim("'").Trim('"') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )

    return , $normalizedItems
}

<#
.SYNOPSIS
Converts a value to a normalized nullable boolean.
#>
function ConvertTo-NormalizedBoolean
{
    [CmdletBinding()]
    [OutputType([System.Nullable[bool]])]
    param
    (
        [Parameter()]
        [AllowNull()]
        [object]
        $Value
    )

    if ($null -eq $Value)
    {
        return $null
    }

    if ($Value -is [bool])
    {
        return $Value
    }

    $candidate = [string] $Value
    if ([string]::IsNullOrWhiteSpace($candidate))
    {
        return $null
    }

    $parsed = $false
    if ([bool]::TryParse($candidate, [ref] $parsed))
    {
        return $parsed
    }

    throw "Invalid boolean value '$candidate'."
}

<#
.SYNOPSIS
Normalizes and validates the config mode value.
#>
function ConvertTo-NormalizedConfigMode
{
    [CmdletBinding()]
    [OutputType([System.Nullable[ArcConfigMode]])]
    param
    (
        [Parameter()]
        [AllowNull()]
        [object]
        $Value
    )

    if ($null -eq $Value)
    {
        return $null
    }

    if ($Value -is [ArcConfigMode])
    {
        return $Value
    }

    $mode = ([string] $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($mode))
    {
        return $null
    }

    $parsed = [ArcConfigMode] 0
    if ([System.Enum]::TryParse([ArcConfigMode], $mode, $true, [ref] $parsed))
    {
        return $parsed
    }

    throw "Invalid ConfigMode value '$Value'. Supported values are 'Monitor' and 'Full'."
}

<#
.SYNOPSIS
Formats a value into azcmagent config set argument text.
#>
function Join-ConfigValue
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter()]
        [AllowNull()]
        [object]
        $Value
    )

    if ($Value -is [bool])
    {
        return $Value.ToString().ToLowerInvariant()
    }

    if ($Value -is [ArcConfigMode])
    {
        return $Value.ToString().ToLowerInvariant()
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
    {
        return (($Value | ForEach-Object { [string] $_ }) -join ',')
    }

    return [string] $Value
}

<#
.SYNOPSIS
Invokes azcmagent with the provided arguments and returns trimmed output.
#>
function Invoke-AzcmAgent
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $AgentPath,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Arguments,

        [Parameter()]
        [switch]
        $IgnoreExitCode
    )

    if ([string]::IsNullOrWhiteSpace($AgentPath))
    {
        throw 'The azcmagent executable was not found. Install the Azure Connected Machine agent first.'
    }

    $output = & $AgentPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string] $_ }) -join [Environment]::NewLine

    if (-not $IgnoreExitCode -and $exitCode -ne 0)
    {
        throw "azcmagent $($Arguments -join ' ') failed with exit code $exitCode. $text".Trim()
    }

    return $text.Trim()
}

<#
.SYNOPSIS
Reads a single azcmagent configuration property value.
#>
function Get-ConfigPropertyValue
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $AgentPath,

        [Parameter(Mandatory = $true)]
        [string]
        $PropertyName
    )

    $rawValue = Invoke-AzcmAgent -AgentPath $AgentPath -Arguments @('config', 'get', $PropertyName)
    if ([string]::IsNullOrWhiteSpace($rawValue))
    {
        return $null
    }

    return $rawValue
}

<#
.SYNOPSIS
Compares two list-like values for logical equality.
#>
function Test-StringListEquality
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [AllowNull()]
        [object]
        $Left,

        [Parameter()]
        [AllowNull()]
        [object]
        $Right
    )

    $leftValues = @(ConvertTo-NormalizedStringList -Value $Left)
    $rightValues = @(ConvertTo-NormalizedStringList -Value $Right)

    if ($leftValues.Count -ne $rightValues.Count)
    {
        return $false
    }

    return $null -eq (Compare-Object -ReferenceObject $leftValues -DifferenceObject $rightValues)
}

#endregion Helper functions

#region DSC resource class

[DscResource()]
class AzureArcAgentConfiguration
{
    # Singleton key. This resource configures the machine-wide Azure Arc agent,
    # so only a single instance is supported.
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [string]
    $IsSingleInstance

    [DscProperty()]
    [Nullable[bool]]
    $IncomingConnectionsEnabled

    [DscProperty()]
    [Nullable[bool]]
    $GuestConfigurationEnabled

    [DscProperty()]
    [Nullable[bool]]
    $ExtensionsEnabled

    [DscProperty()]
    [string[]]
    $ExtensionAllowlist

    [DscProperty()]
    [string[]]
    $ExtensionBlocklist

    [DscProperty()]
    [Nullable[ArcConfigMode]]
    $ConfigMode

    [DscProperty()]
    [string]
    $ProxyUrl

    # Read-only: reports whether the azcmagent executable was found.
    [DscProperty(NotConfigurable)]
    [bool]
    $AgentInstalled

    <#
        Returns the current state of the Azure Arc agent configuration.
    #>
    [AzureArcAgentConfiguration] Get()
    {
        $currentState = [AzureArcAgentConfiguration]::new()
        $currentState.IsSingleInstance = 'Yes'

        $agentPath = Find-AzcmAgentCommand
        if ([string]::IsNullOrWhiteSpace($agentPath))
        {
            $currentState.AgentInstalled = $false
            return $currentState
        }

        $currentState.AgentInstalled = $true
        $currentState.IncomingConnectionsEnabled = ConvertTo-NormalizedBoolean -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'incomingconnections.enabled')
        $currentState.GuestConfigurationEnabled = ConvertTo-NormalizedBoolean -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'guestconfiguration.enabled')
        $currentState.ExtensionsEnabled = ConvertTo-NormalizedBoolean -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'extensions.enabled')
        $currentState.ExtensionAllowlist = ConvertTo-NormalizedStringList -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'extensions.allowlist')
        $currentState.ExtensionBlocklist = ConvertTo-NormalizedStringList -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'extensions.blocklist')
        $currentState.ConfigMode = ConvertTo-NormalizedConfigMode -Value (
            Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'config.mode')
        $currentState.ProxyUrl = Get-ConfigPropertyValue -AgentPath $agentPath -PropertyName 'proxy.url'

        return $currentState
    }

    <#
        Determines whether the current state matches the desired state.
    #>
    [bool] Test()
    {
        $currentState = $this.Get()

        if (-not $currentState.AgentInstalled)
        {
            return $false
        }

        foreach ($property in $this.GetConfiguredProperties().Keys)
        {
            if ($property -in @('ExtensionAllowlist', 'ExtensionBlocklist'))
            {
                if (-not (Test-StringListEquality -Left $currentState.$property -Right $this.$property))
                {
                    return $false
                }

                continue
            }

            if ($currentState.$property -cne $this.$property)
            {
                return $false
            }
        }

        return $true
    }

    <#
        Applies the desired state to the Azure Arc agent configuration.
    #>
    [void] Set()
    {
        $agentPath = Find-AzcmAgentCommand
        if ([string]::IsNullOrWhiteSpace($agentPath))
        {
            throw 'The azcmagent executable was not found. Install the Azure Connected Machine agent first.'
        }

        $currentState = $this.Get()

        foreach ($property in $this.GetConfiguredProperties().Keys)
        {
            $currentValue = $currentState.$property
            $desiredValue = $this.$property
            $propertyName = $script:PropertyMap[$property]

            $needsUpdate = $false
            if ($property -in @('ExtensionAllowlist', 'ExtensionBlocklist'))
            {
                $needsUpdate = -not (Test-StringListEquality -Left $currentValue -Right $desiredValue)
            }
            else
            {
                $needsUpdate = $currentValue -cne $desiredValue
            }

            if (-not $needsUpdate)
            {
                continue
            }

            if ($property -eq 'ConfigMode' -and $desiredValue -eq [ArcConfigMode]::Full)
            {
                # azcmagent requires transitioning through 'monitor' before 'full'.
                $this.SetConfigProperty($agentPath, $propertyName, 'monitor')
                $this.SetConfigProperty($agentPath, $propertyName, 'full')
            }
            else
            {
                $this.SetConfigProperty($agentPath, $propertyName, $desiredValue)
            }
        }
    }

    #region Private helpers

    <#
        Returns a hashtable of the configurable properties the user has set
        (non-null), keyed by property name.
    #>
    hidden [hashtable] GetConfiguredProperties()
    {
        $configured = @{}

        foreach ($property in $script:PropertyMap.Keys)
        {
            $value = $this.$property
            if ($null -ne $value)
            {
                $configured[$property] = $value
            }
        }

        return $configured
    }

    hidden [void] SetConfigProperty([string] $AgentPath, [string] $PropertyName, [object] $Value)
    {
        $valueText = Join-ConfigValue -Value $Value
        $null = Invoke-AzcmAgent -AgentPath $AgentPath -Arguments @('config', 'set', $PropertyName, $valueText)
    }

    #endregion Private helpers
}

#endregion DSC resource class

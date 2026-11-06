# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Example configuration that applies desired Azure Arc agent settings.

    .DESCRIPTION
        Uses the class-based AzureArcAgentConfiguration DSC resource to configure
        the local azcmagent settings. Run in an elevated session.
#>

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
# ArcAgentConfiguration -OutputPath .\ArcAgentConfiguration
#
# Apply it (elevated):
# Start-DscConfiguration -Path .\ArcAgentConfiguration -Wait -Verbose -Force
#
# Test / Get current state:
# Test-DscConfiguration -Path .\ArcAgentConfiguration
# Get-DscConfiguration

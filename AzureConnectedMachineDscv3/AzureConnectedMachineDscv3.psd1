#
# Module manifest for module 'AzureConnectedMachineDscv3'
#
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'AzureConnectedMachineDscv3.psm1'

    # Version number of this module.
    ModuleVersion        = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID                 = 'f0a2c1e4-6b3d-4a2f-9c1a-8d7e5b4c3a21'

    # Author of this module
    Author               = 'Michal Machniak'

    # Company or vendor of this module
    CompanyName          = 'Michal Machniak'

    # Copyright statement for this module
    Copyright            = '(c) Michal Machniak. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'Class-based PowerShell DSC resource for managing Azure Arc for Servers (azcmagent) local agent configuration.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '5.1'

    # DSC resources to export from this module
    DscResourcesToExport = @('AzureArcAgentConfiguration')

    # Functions to export from this module
    FunctionsToExport    = @()

    # Cmdlets to export from this module
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module
    AliasesToExport      = @()

    # Private data to pass to the module specified in RootModule
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DSC', 'Azure', 'Arc', 'azcmagent', 'ConnectedMachine', 'Windows')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/mimachniak/AzureConnectedMachineDscV3/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/mimachniak/AzureConnectedMachineDscV3'

            # ReleaseNotes of this module
            ReleaseNotes = '
            v.1.0.0
            - Initial class-based DSC resource for Azure Arc agent configuration.
            '
        }
    }
}

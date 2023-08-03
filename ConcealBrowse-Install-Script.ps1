#Requires -RunAsAdministrator
# Modifying the HKLM registry hive requires administrative privileges
#Requires -version 5
# At least Get-ItemPropertyValue requires powershell v5

<#
.NOTES
  Version:  2.4
  Authors:  Daniel Capor, Jason Shiffer @ Conceal, Inc.

.SYNOPSIS
Add the ConcealBrowse Extension to supported browsers on Windows while preserving existing browser ExtensionSettings. 
Supported browsers: Chrome, Edge, and Brave.

.DESCRIPTION
This script checks the local machine registry key for browser ExtensionSettings. If there is existing data it's 
evaluated for validity, and if valid, is modified to include ConcealBrowse as configured by this script. If the data is 
missing or invalid, ConcealBrowse is set as the only ExtensionSettings entry. Additional data is collected and provided 
to the Conceal dashboard to correlate browser profiles to devices and users in your organization.

.PARAMETER CompanyID
Required. GUID Type. The SiteID and CompanyID are used to authenticate the ConcealBrowse extension eliminating the need 
for user login.

.PARAMETER SiteID
Required. GUID Type. See CompanyID

.PARAMETER ForceEnable
Switch Type. (Default) "not defined or $false" users can disable the ConcealBrowse extension. 
When switch is included or "$true" users cannot disable the ConcealBrowse extension.

.PARAMETER NoToolbarPin
Switch Type. (Default) "not defined or $false" ConcealBrowse is pinned to the browser toolbar when enabled. 
When switch is included or "$true" ConcealBrowse starts hidden in the extensions menu, the user can pin it to the browser toolbar.

.PARAMETER UserId
Optional. String Type. UserId should represent the primary user of a device. By default it is queried from running 
windows explorer.exe sessions, first returned user is set. If no session is runninng, this parameter is null. A userId 
may be provided manually as a parameter.

.PARAMETER HostId
Optional. String Type. HostId should represent the hostname of a device. By default it is queried from system TCP/IP DNS 
HostId may be provided manually as a parameter.

.PARAMETER AssetId
Optional. String Type. AssetId should represent a Globally Unique ID (GUID) of a device. By default it is queried from 
the Microsoft Cryptography registry entry. An AssetId may be provided manually as a parameter, it must be a GUID.

.PARAMETER IncognitoAndGuestMode
Switch Type. (Default) "not defined or $false" no change. "Disable" Incognito/InPrivate Mode and Guest Mode are disabled. 
"Enable" Incognito/InPrivate Mode and Guest mode configurations are set to not configured which is enabled. 
This parameter may be used during installation and uninstallation and affects all supported browsers.

.PARAMETER Uninstall
Switch Type. (Default) "not defined or $false" no action taken. When switch is included or "$true", script will 
remove ConcealBrowse entry from ExtensionSettings.

.EXAMPLE
Install ConcealBrowse extension with defaults. Users can disable the extension. ConcealBrowse is pinned to the 
toolbar when enabled. Incognito/InPrivate and Guest modes are not configured.
PS> .\Install-ConcealBrowse.ps1 -CompanyId <CompanyID from dashboard.conceal.io> -SiteID <SiteID from dashboard.conceal.io>

.EXAMPLE
Install ConcealBrowse extension with maximum protection. Users cannot disable the extension. The extension 
is pinned to the browser toolbar. Incognito/InPrivate and Guest Mode are disabled
PS> .\Install-ConcealBrowse.ps1 -CompanyId <CompanyID from dashboard.conceal.io> -SiteID <SiteID from dashboard.conceal.io>
    -ForceEnable -IncognitoAndGuestMode Disabled

.EXAMPLE
Uninstall ConcealBrowse extension, specifically removing the entry from ExtensionSettings if it exists and 
removing the extension's Registry key where SiteID and CompanyID are stored.
PS> .\Install-ConcealBrowse.ps1 -Uninstall

#>
#----------------------------------------------------[Parameters]-----------------------------------------------------

[CmdletBinding(DefaultParameterSetName='Installation')]
Param(
    [Parameter(ParameterSetName='Installation')]
        $CompanyID = "Paste your CompanyID here", # Required, provide as a parameter (see examples) or set here in the quotes
    [Parameter(ParameterSetName='Installation')]
        $SiteID = "Paste your SiteID here", # Required, provide as a parameter (see examples) or set here in the quotes
    [Parameter(ParameterSetName='Installation')]
        [Switch]$ForceEnable = $false,
    [Parameter(ParameterSetName='Installation')]
        [Switch]$NoToolbarPin = $false,
    [Parameter(ParameterSetName='Installation')]
        [String]$UserId = "Insert value here to override",
    [Parameter(ParameterSetName='Installation')]
        [String]$HostId = "Insert value here to override",
    [Parameter(ParameterSetName='Installation')]
        [String]$AssetId = "Insert value here to override",

    [Parameter(ParameterSetName='Uninstallation')]
        [Switch]$Uninstall,

    [ValidateSet("Disabled","Enabled")]
        [String]$IncognitoAndGuestMode = "", # Optional, provide as a parameter or type Disabled or Enabled in the quotes

    [Parameter(DontShow)]
        [ValidatePattern('^[a-zA-Z]{32}$')]
        [String]$overrideExtensionId
)

#----------------------------------------------------[Declarations]-----------------------------------------------------

$update_url = "https://clients2.google.com/service/update2/crx"

If ($true -eq $ForceEnable) {
    $installation_mode = "force_installed"
} Else {
    $installation_mode = "normal_installed"
}
If ($true -eq $NoToolbarPin) {
    $toolbar_pin = "default_unpinned"
    $edgeToolbar_state = "default_hidden"
} Else {
    $toolbar_pin = "force_pinned"
    $edgeToolbar_state = "force_shown"
}

$chromeRegistryPath = 'SOFTWARE\Policies\Google\Chrome'
$chromeObjectConcealBrowse = [PSCustomObject]@{
    installation_mode = $installation_mode
    toolbar_pin = $toolbar_pin
    update_url = $update_url
}
$edgeRegistryPath = 'SOFTWARE\Policies\Microsoft\Edge'
$edgeObjectConcealBrowse = [PSCustomObject]@{
    installation_mode = $installation_mode
    toolbar_state = $edgeToolbar_state
    update_url = $update_url
}
$braveRegistryPath = 'SOFTWARE\Policies\BraveSoftware\Brave'
$braveObjectConcealBrowse = $chromeObjectConcealBrowse

If ($overrideExtensionId) {
    $extensionID = $overrideExtensionId
} Else {
    $extensionID = 'jmdpihfpelphmllgmamebdbelmobjfpg'
}

#---------------------------------------------------[Functions]---------------------------------------------------------

<#
.SYNOPSIS
Get the current ExtensionSettings value from the registry. Test it for validity. If its invalid or 
does not exist, return an empty PSObject.

.PARAMETER browserName
String Type, Mandatory. Friendly name of the browser being checked

.PARAMETER registryPath
String Type, Mandatory. Registry path for the given browser, everything after HKLM
    
.OUTPUTS
PSObject. Returns a PSObject for use by Set and Remove functions.

#>
function Get-ExtensionSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$browserName,
        [Parameter(Mandatory)]
        [String]$registryPath
    )
    $extensionSettings = New-Object -TypeName PSObject
    try{
        # Try to get the ExtensionSettings value
        $extensionSettingsCurrentValue = Get-ItemPropertyValue -Path HKLM:\$registryPath -Name ExtensionSettings `
            -ErrorAction Stop

        try {
            # Test if value is not null and properly formatted, if so use it for final settings
            if ($extensionSettingsCurrentValue -notmatch "{") { throw }
            $extensionSettings = ConvertFrom-Json $extensionSettingsCurrentValue -ErrorAction Stop
            Write-Host "INFO: $browserName ExtensionSettings value is properly formatted as JSON, preserving settings"
        } catch {
            Write-Host "INFO: $browserName ExtensionSettings value is NOT properly formatted as JSON"
        }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Host "INFO: $browserName registry key and ExtensionSettings value do not exist"
    }
    catch {
        Write-Host "INFO: $browserName ExtensionSettings registry value does not exist"
    }
    finally {
        $extensionSettings # output/return
    }
}

<#
.SYNOPSIS
Checks if there is already a machineId stored in a given browser extension settings. If there is, then return it, 
if not then generate a new GUID.
.PARAMETER registryPath
String Type, Mandatory. Registry path for the given browser, everything after HKLM
#>
function Get-MachineID {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
            [String]$registryPath
    )

    try {
        $machineId = Get-ItemPropertyValue -Path HKLM:\$registryPath\3rdparty\extensions\$extensionID\Policy `
            -Name MachineId -ErrorAction Stop
        Write-Host "INFO: Using existing MachineID: $machineId"
    } catch {
        Write-Host "INFO: MachineID is not yet defined"
    }

    if (!$machineId) {
        try {
            $machineId = (Get-WmiObject Win32_NetworkAdapter -Filter "netenabled = true" | Select-Object Guid -First 1).guid.trim('{}')
            Write-Host "INFO: Using first network adapter GUID as MachineID: $machineId"
        } catch {
            Write-Host "ERROR when attempting to use first network adapter GUID as MachineID"
        }
    }

    if (!$machineId) {
        $machineId = New-Guid
        Write-Host "INFO: Generating a new GUID to use as MachineID: $machineId"
    }

    $machineId
}

<#
.SYNOPSIS
Creates an AssetInfo Object, if an option is not provided then defaults to commonly understood values. See header for 
parameter information.
.PARAMETER userId
.PARAMETER hostId
.PARAMETER assetId
#>

function New-AssetInfo {
    # If userID has not been overridden, try to get it from the system, if that fails set to "undefined"
    If ("Insert value here to override" -eq $userId) {
        try { 
            $userid = (Get-WmiObject -Class Win32_NetworkLoginProfile | `
                Sort-Object -Property LastLogon -Descending | `
                Select-Object -first 1).name.split("\")[1]
        }
        Catch {
            Write-Host "WARNING: Unable to get username from lastlogon information, setting to undefined"
            $userId = "undefined"
        }
    }

    # If hostID has not been overridden, try to get it from the system, if that fails set to "undefined"
    If ("Insert value here to override" -eq $hostId) {
        try { 
            $hostId = [System.Net.Dns]::GetHostName()
        }
        Catch {
            Write-Host "WARNING: Unable to get hostname, setting to undefined"
            $hostId = "undefined"
        }
    }

    # If AssetID has not been overridden, try to get it from the system, if that fails set to "undefined"
    If ("Insert value here to override" -eq $assetId) {
        try { 
            $assetId = Get-ItemPropertyValue -Path HKLM:\Software\Microsoft\Cryptography -Name MachineGuid -ErrorAction stop
        }
        Catch {
            Write-Host "WARNING: Unable to get assetid, setting to undefined"
            $assetId = "undefined"
        }
    }

    [PSCustomObject]@{
        userId = $userId
        hostId = $hostId
        assetId = $assetId
    }
}

<#
.SYNOPSIS
Set the registry values for the given browser based on script parameters

.PARAMETER browserName
String Type, Mandatory. Friendly name of the browser being checked

.PARAMETER registryPath
String Type, Mandatory. Registry path for the given browser, everything after HKLM

.PARAMETER extensionSettings
String Type, Mandatory. ExtensionSettings variable, should be JSON populated with current registry value.

.PARAMETER browserObject
PSCustomObject Type, Mandatory. Object containing settings derived for the given browser based on script parameters.

#>
function Set-RegistryValues {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
            [String]$browserName,
        [Parameter(Mandatory)]
            [String]$registryPath,
        [Parameter(Mandatory)]
            [PSObject]$extensionSettings,
        [Parameter(Mandatory)]
            [PSCustomObject]$browserObject
    )
    try {
        # Add/overwrite the ConcealBrowse ExtensionSettings and write it to the registry.
        $extensionSettings | Add-Member -MemberType NoteProperty -Name $extensionID -Value $browserObject -Force
        [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\$registryPath", "ExtensionSettings", `
            "$($extensionSettings | ConvertTo-Json -Compress)")
        Write-Host "SUCCESS: Added the ConcealBrowse extension to $browserName"
    } catch {
        "ERROR when trying to set $browserName ExtensionSettings"
    }

    try {
        # Write the SiteID, CompanyID, MachineID and assetInfo to the registry
        $policyPathConcealBrowse = "HKEY_LOCAL_MACHINE\$registryPath\3rdparty\extensions\$extensionID\Policy"
        [microsoft.win32.registry]::SetValue($policyPathConcealBrowse, "InstallSiteId", $SiteID)
        [microsoft.win32.registry]::SetValue($policyPathConcealBrowse, "InstallCompanyId", $CompanyID)
        [microsoft.win32.registry]::SetValue($policyPathConcealBrowse, "MachineId", $MachineID)
        [microsoft.win32.registry]::SetValue($policyPathConcealBrowse, "AssetInfo", "$($AssetInfo | ConvertTo-Json -Compress)")

        Write-Host "SUCCESS: ConcealBrowse values written to $policyPathConcealBrowse :"
        Write-Host " InstallSiteId: $SiteID"
        Write-Host " InstallCompanyId: $CompanyID"
        Write-Host " MachineId: $MachineID"
        Write-Host " AssetInfo: $($AssetInfo | ConvertTo-Json -Compress)"
    } catch {
        Write-Host "ERROR when attempting to set SiteID, CompanyID, MachineID, and AssetInfo for $browserName"
    }
}

<#
.SYNOPSIS
Set browser Incognito/InPrivate and Guest Mode depending on value of $IncognitoAndGuestMode

.PARAMETER browserName
String Type, Mandatory. Friendly name of the browser being checked

.PARAMETER registryPath
String Type, Mandatory. Registry path for the given browser, everything after HKLM

#>
function Set-IncognitoAndGuest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$browserName,
        [Parameter(Mandatory)]
        [String]$registryPath
    )
    try {
        # What the hell Microsoft, and I bet you aren't the only one who will rebrand Incognito and muck with the registry
        if ("Edge" -eq $browserName) { $incognitoName = "InPrivateModeAvailability" }
            else { $incognitoName = "IncognitoModeAvailability" }

        # Disable given browser Incognito/InPrivate and Guest Mode if set to "Disabled"
        if ("Disabled" -eq $IncognitoAndGuestMode) {
            [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\$registryPath", $incognitoName, 1)
            [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\$registryPath", "BrowserGuestModeEnabled", 0)
            Write-Host "SUCCESS: Disabled $browserName $incognitoName and Guest Modes"
        }
        elseif ("Enabled" -eq $IncognitoAndGuestMode) {
            Remove-ItemProperty -Path HKLM:\$registryPath -Name $incognitoName -Force -ErrorAction Ignore | Out-Null
            Remove-ItemProperty -Path HKLM:\$registryPath -Name BrowserGuestModeEnabled -Force -ErrorAction Ignore | Out-Null
            Write-Host "SUCCESS: Reset $browserName $incognitoName and Guest Modes to not configured (Enabled)"
        }
    } catch {
        "ERROR when attempting to set $incognitoName and Guest Mode for $browserName"
    }
}

<#
.SYNOPSIS
Remove ConcealBrowse extension from given browser by removing its extension id from the ExtensionSettings value 
and deleting its extensions key from the registry.

.PARAMETER browserName
String Type, Mandatory. Friendly name of the browser being checked

.PARAMETER registryPath
String Type, Mandatory. Registry path for the given browser, everything after HKLM

.PARAMETER extensionSettings
String Type, Mandatory. ExtensionSettings variable, should be JSON populated with current registry value.

#>
function Remove-ConcealBrowseExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
            [String]$browserName,
        [Parameter(Mandatory)]
            [String]$registryPath,
        [Parameter(Mandatory)]
            [PSObject]$extensionSettings
    )
    try {
        # Remove ConcealBrowse extension from given browser ExtensionSettings
        $extensionSettings.PSObject.Properties.Remove($extensionID)
        if (-not "$extensionSettings") {
            Remove-ItemProperty -Path HKLM:\$registryPath -Name ExtensionSettings -Force -ErrorAction Stop | Out-Null
        } else {
            [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\$registryPath", "ExtensionSettings", `
            "$($extensionSettings | ConvertTo-Json -Compress)")
        }

        # Remove ConcealBrowse extensions key
        Remove-Item -Path HKLM:\$registryPath\3rdparty\extensions\$extensionID -Recurse -Force -ErrorAction Stop | Out-Null

        Write-Host "SUCCESS: The $browserName ConcealBrowse Extension has been uninstalled."
    } catch {
        "INFO: The $browserName ConcealBrowse Extension is not installed."
    }
}

#----------------------------------------------------[Script]-----------------------------------------------------------

$chromeExtensionSettings =  Get-ExtensionSettings -browserName "Chrome" -registryPath $chromeRegistryPath
$edgeExtensionSettings =    Get-ExtensionSettings -browserName "Edge"   -registryPath $edgeRegistryPath
$braveExtensionSettings =   Get-ExtensionSettings -browserName "Brave"  -registryPath $braveRegistryPath

if ($Uninstall) {
    Remove-ConcealBrowseExtension -browserName "Chrome" -extensionSettings $chromeExtensionSettings -registryPath $chromeRegistryPath
    Remove-ConcealBrowseExtension -browserName "Edge"   -extensionSettings $edgeExtensionSettings   -registryPath $edgeRegistryPath
    Remove-ConcealBrowseExtension -browserName "Brave"  -extensionSettings $braveExtensionSettings  -registryPath $braveRegistryPath
}
else {
    # Use Chrome as the tracking config for the generated MachineID
    $MachineId = Get-MachineID -registryPath $chromeRegistryPath

    # Currently defaulting to generated data but has optional args as well
    $AssetInfo = New-AssetInfo

    try {
        $CompanyID = [GUID]$CompanyID
        $SiteID = [GUID]$SiteID
    }
    catch {
        throw "ERROR: SiteID and CompanyID are both required, please provide as a parameter or set in the script."
    }

    try {
        $MachineID = [GUID]$MachineID
    }
    catch {
        throw "ERROR: MachineID is not a GUID, this should not happen."
    }

    Set-RegistryValues -browserName "Chrome" -registryPath $chromeRegistryPath  -extensionSettings $chromeExtensionSettings `
        -browserObject $chromeObjectConcealBrowse
    Set-RegistryValues -browserName "Edge"   -registryPath $edgeRegistryPath    -extensionSettings $edgeExtensionSettings `
        -browserObject $edgeObjectConcealBrowse
    Set-RegistryValues -browserName "Brave"  -registryPath $braveRegistryPath   -extensionSettings $braveExtensionSettings `
        -browserObject $braveObjectConcealBrowse
}

Set-IncognitoAndGuest -browserName "Chrome" -registryPath $chromeRegistryPath
Set-IncognitoAndGuest -browserName "Edge"   -registryPath $edgeRegistryPath
Set-IncognitoAndGuest -browserName "Brave"  -registryPath $braveRegistryPath

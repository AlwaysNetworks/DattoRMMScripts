<#
.SYNOPSIS
    This script is the wrapper script to install ConcealBrowse
    A copy of this script is the component in Datto RMM
    The script downloads the actual script you want to run from Github
    Then executes it with the parameters passed in from Datto RMM
.OUTPUTS
    The Write-Host commands within the ConcealBrowse-Install-Script.ps1 script
.NOTES
    Version:        1.0
    Author:         Nick Shaw
    Creation Date:  2023-08-07
    Purpose/Change: Initial script development
#>

$script = 'ConcealBrowse-Install-Script.ps1'

$hash = "C590BED7BCB6616B5D11A05B44F6856E5A074559A25F4BE2A7AC7B3064565F09"

$Params = @{
    SiteID       = $env:SiteID
    NoToolbar    = if ($env:NoToolbar -eq 'true') {$true} else {$false}
    ForceEnable  = if ($env:ForceEnable -eq 'true') {$true} else {$false}
    CompanyID    = $env:CompanyID
}


# Nothing below here usually needs to be changed

$repo = 'https://raw.githubusercontent.com/AlwaysNetworks/DattoRMMScripts/main/'

Invoke-WebRequest -Uri "$repo$script" -OutFile "./script.ps1"

if ((Get-FileHash -Path "./script.ps1" -Algorithm SHA256).Hash -ne $hash) {
    Write-Host "Hash mismatch, exiting"
    exit 1
}

Invoke-Expression ". ./script.ps1 @Params"
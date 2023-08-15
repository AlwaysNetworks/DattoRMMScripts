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

$script = 'Hudu-Device-Audit.ps1'

$hash = "34E8BE71C970C2F60A632B1233B47B22B94D87762605846FDA0620A049C055DE"

$Params = @{
    HuduAPIKey       = $env:HuduAPIKey
    HuduBaseDomain   = "https://docs.alwaysnetworks.co.uk"
    CompanyName      = $env:HuduCompanyName
}


# Nothing below here usually needs to be changed

$repo = 'https://raw.githubusercontent.com/AlwaysNetworks/DattoRMMScripts/main/'

Invoke-WebRequest -Uri "$repo$script" -OutFile "./script.ps1"

if ((Get-FileHash -Path "./script.ps1" -Algorithm SHA256).Hash -ne $hash) {
    Write-Host "Hash mismatch, exiting"
    exit 1
}

Write-Host "Hash matches. Executing script..."

Invoke-Expression "pwsh ./script.ps1 @Params"
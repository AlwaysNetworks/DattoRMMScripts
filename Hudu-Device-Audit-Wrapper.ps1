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

$hash = "4349CFB29CB4542C0AE53F1C3E2841110BE1F4A81BBB7C5EE8B960D6866D7722"

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

Invoke-Expression ". ./script.ps1 @Params"
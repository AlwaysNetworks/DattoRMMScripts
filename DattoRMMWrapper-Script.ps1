<#
.SYNOPSIS
    This script is the wrapper script
    A version of this should be the component in Datto RMM
    The script downloads the actual script you want to run from Github
    Then executes it.DESCRIPTION
.OUTPUTS
    None
.NOTES
    Version:        1.0
    Author:         Nick Shaw
    Creation Date:  2023-07-23
    Purpose/Change: Initial script development
#>

# Do not edit this bit
$wc = New-Object System.Net.WebClient
$wc.Headers.Add('Accept','application/vnd.github.v3.raw')

# Set this URL to the script you want to run
$wc.DownloadString('https://raw.githubusercontent.com/AlwaysNetworks/DattoRMMScripts/main/RDGClientTransport-Script.ps1') | Invoke-Expression

# Cal the function in your other script here - for example:
Set-RDGClientTransport
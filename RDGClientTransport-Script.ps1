# Add a DWORD called RDGClientTransport with a value of 1 to "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client" if it doesn't exist
# This will enable the use of the Remote Desktop Gateway (RDG) protocol for RDP connections
# This is useful for connecting to RDS VMs that are behind an RDG


function Set-RDGClientTransport {
    <#
    .SYNOPSIS
        Adds a DWORD called RDGClientTransport with a value of 1 to "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client" if it doesn't exist
    .DESCRIPTION
        This function adds a DWORD called RDGClientTransport with a value of 1 to "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client" if it doesn't exist
        It is used to enable the use of the Remote Desktop Gateway (RDG) protocol for RDP connections
    .OUTPUTS
        None
    .NOTES
        Version:        1.0
        Author:         Nick Shaw
        Creation Date:  2023-07-23
        Purpose/Change: Initial script development
    .EXAMPLE
        Set-RDGClientTransport
    #>
    $regPath = "HKCU:\Software\Microsoft\Terminal Server Client"
    $regName = "RDGClientTransport"
    $regValue = 1
    if (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
        Write-Host "Created registry path $regPath"
    }
    if (!(Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
        Write-Host "Created registry value $regName with value $regValue"
    } else {
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force | Out-Null
        Write-Host "Updated registry value $regName with value $regValue"
    }
}
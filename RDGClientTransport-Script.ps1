# Add a DWORD called RDGClientTransport with a value of 1 to "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client" if it doesn't exist
# This will enable the use of the Remote Desktop Gateway (RDG) protocol for RDP connections
# This is useful for connecting to RDS VMs that are behind an RDG

$regPath = "HKCU:\Software\Microsoft\Terminal Server Client"
$regName = "RDGClientTransport"
$regValue = 1
if (!(Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
if (!(Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
} else {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force | Out-Null
}

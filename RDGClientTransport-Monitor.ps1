# Check if "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client\RDGClientTransport" is 1
# If it is, then exit with a 0 error code and a Datto RMM status of OK
# else, exit with non 0 error code and a Datto RMM status message of "Fail"

$regPath = "HKCU:\Software\Microsoft\Terminal Server Client"
$regName = "RDGClientTransport"
$regValue = 1
if (!(Test-Path $regPath)) {
    write-host '<-Start Result->'
    write-host "Path not found"
    write-host '<-End Result->' 
    exit 1
}
if (!(Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    write-host '<-Start Result->'
    write-host "RDGClientTransport not found"
    write-host '<-End Result->' 
    exit 1
}
if ((Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).RDGClientTransport -eq $regValue) {
    write-host '<-Start Result->'
    write-host "RDGClientTransport is 1"
    write-host '<-End Result->' 
    exit 0
} else {
    write-host '<-Start Result->'
    write-host "RDGClientTransport is not 1"
    write-host '<-End Result->' 
    exit 1
}
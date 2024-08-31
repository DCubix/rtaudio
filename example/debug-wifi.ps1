$ip = "192.168.100.234"

# Check if the device is reachable, if the string has tcp and open on it
$nmapOutput = nmap -p 37000-44000 $ip | Select-String "tcp" | Select-String "open"
$ports = $nmapOutput -split "`n" | ForEach-Object { ($_ -replace '(\d+)/.*', '$1') }

# if nmap output is empty, the device is not reachable
if ($ports.Count -eq 0) {
    Write-Host "Device is not reachable." -ForegroundColor Red
    exit
}

# extract the port number from the nmap output eg.: 40035/tcp open     unknown
$port = ""
if ($ports.Count -gt 1) {
    $port = $ports[0]
} else {
    $port = $ports
}

Write-Host "ADB port found: " -ForegroundColor Green -NoNewline
Write-Host "$port" -ForegroundColor Cyan

# connect adb
$adbOutput = adb connect "${ip}:${port}"
Write-Host $adbOutput -ForegroundColor Blue

. "$PSScriptRoot\common.ps1"
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item $Tools -ItemType Directory -Force | Out-Null
New-Item (Join-Path $Root 'lib') -ItemType Directory -Force | Out-Null

function Receive-Artifact {
    param([string]$Url, [string]$Destination, [string]$Algorithm, [string]$Checksum)
    if ((Test-Path $Destination) -and
            (Get-FileHash $Destination -Algorithm $Algorithm).Hash -eq $Checksum) { return }
    $partial = "$Destination.download"
    try {
        Write-Host "Downloading $(Split-Path $Destination -Leaf)..."
        Invoke-Checked 'curl.exe' @('--fail', '--location', '--silent', '--show-error',
            '--retry', '2', '--connect-timeout', '20', '--max-time', '600', '--output', $partial, $Url)
        if ((Get-FileHash $partial -Algorithm $Algorithm).Hash -ne $Checksum) {
            throw "Checksum mismatch: $Url"
        }
        Move-Item $partial $Destination -Force
    } finally {
        if (Test-Path $partial) { Remove-Item $partial }
    }
}

function Expand-Tool {
    param([string]$Archive, [string]$Target)
    if (Test-Path $Target) { return }
    $extract = "$Target.extract"
    if (Test-Path $extract) { throw "Incomplete extraction at $extract. Inspect and remove it before retrying." }
    Expand-Archive -LiteralPath $Archive -DestinationPath $extract
    $directories = @(Get-ChildItem $extract -Directory)
    if ($directories.Count -ne 1) { throw "Unexpected archive layout: $Archive" }
    Move-Item $directories[0].FullName $Target
    Remove-Item $extract
}

Write-Host 'Downloading Java dependencies (no Maven/Gradle)...'
$hashes = @()
foreach ($dependency in Get-Dependencies) {
    $filename = "$($dependency.artifact)-$($dependency.version).jar"
    $groupPath = $dependency.group.Replace('.', '/')
    $url = "https://repo.maven.apache.org/maven2/$groupPath/$($dependency.artifact)/$($dependency.version)/$filename"
    $sha1 = ((Invoke-WebRequest -UseBasicParsing "$url.sha1").Content.Trim() -split '\s+')[0]
    Receive-Artifact $url (Join-Path $Root "lib\$filename") 'SHA1' $sha1
    $hashes += "$((Get-FileHash (Join-Path $Root "lib\$filename") -Algorithm SHA256).Hash.ToLower())  $filename"
}
$hashes | Set-Content (Join-Path $Root 'lib\checksums.sha256') -Encoding ASCII

Write-Host 'Preparing portable JDK 8, Node 14 and Tomcat 9...'
$jdkZip = Join-Path $Tools 'jdk8.zip'
if (!(Test-Path $JavaHome)) {
    Receive-Artifact 'https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u504-b01/OpenJDK8U-jdk_x64_windows_hotspot_8u504b01.zip' `
        $jdkZip 'SHA256' 'ea43d46ede95b51e44a12c66711706cddc762e0a766c54bccea18954e902b2aa'
    Expand-Tool $jdkZip $JavaHome
}
if (!(Test-Path $NodeHome)) {
    $nodeFile = 'node-v14.21.3-win-x64.zip'
    $nodeSums = (Invoke-WebRequest -UseBasicParsing 'https://nodejs.org/dist/v14.21.3/SHASUMS256.txt').Content
    $nodeLine = @($nodeSums -split "`n" | Where-Object { $_ -match " $([regex]::Escape($nodeFile))\s*$" })
    if ($nodeLine.Count -ne 1) { throw 'Cannot resolve Node checksum' }
    Receive-Artifact "https://nodejs.org/dist/v14.21.3/$nodeFile" (Join-Path $Tools 'node14.zip') 'SHA256' (($nodeLine[0] -split '\s+')[0])
    Expand-Tool (Join-Path $Tools 'node14.zip') $NodeHome
}
if (!(Test-Path $TomcatHome)) {
    $tomcatUrl = 'https://repo.maven.apache.org/maven2/org/apache/tomcat/tomcat/9.0.118/tomcat-9.0.118-windows-x64.zip'
    $tomcatHash = ((Invoke-WebRequest -UseBasicParsing "$tomcatUrl.sha512").Content.Trim() -split '\s+')[0]
    Receive-Artifact $tomcatUrl (Join-Path $Tools 'tomcat9.zip') 'SHA512' $tomcatHash
    Expand-Tool (Join-Path $Tools 'tomcat9.zip') $TomcatHome
}
Assert-Toolchain
Push-Location (Join-Path $Root 'frontend')
try {
    if (Test-Path 'package-lock.json') {
        Invoke-Checked "$NodeHome\npm.cmd" @('ci', '--no-audit', '--no-fund')
    } else {
        Invoke-Checked "$NodeHome\npm.cmd" @('install', '--no-audit', '--no-fund', '--loglevel=info',
            '--fetch-retries=2', '--fetch-retry-mintimeout=1000', '--fetch-retry-maxtimeout=20000')
    }
} finally { Pop-Location }
Write-Host 'Setup complete. Next: build.bat, test.bat, start-local.bat'

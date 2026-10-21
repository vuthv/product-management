Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Tools = Join-Path $Root '.tools'
$Local = Join-Path $Root '.local'
$JavaHome = Join-Path $Tools 'jdk8'
$NodeHome = Join-Path $Tools 'node14'
$TomcatHome = Join-Path $Tools 'tomcat9'
$TomcatBase = Join-Path $Local 'tomcat'
$PgData = Join-Path $Local 'pgdata'
$PgPort = 55432
$HttpPort = 18080
$AppUrl = "http://127.0.0.1:$HttpPort/product-management"

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)" }
}

function Assert-Toolchain {
    foreach ($path in @("$JavaHome\bin\javac.exe", "$NodeHome\node.exe", "$TomcatHome\bin\bootstrap.jar")) {
        if (!(Test-Path $path)) { throw "Missing $path. Run setup.bat first." }
    }
    $env:JAVA_HOME = $JavaHome
    $env:Path = "$JavaHome\bin;$NodeHome;$env:Path"
}

function Get-Dependencies {
    $dependencies = Get-Content (Join-Path $Root 'dependencies.json') -Raw | ConvertFrom-Json
    return $dependencies
}

function Get-ClassPath {
    param([string[]]$Scopes)
    $paths = foreach ($dependency in Get-Dependencies) {
        if ($dependency.scope -in $Scopes) {
            $path = Join-Path $Root "lib\$($dependency.artifact)-$($dependency.version).jar"
            if (!(Test-Path $path)) { throw "Missing dependency $path. Run setup.bat." }
            $path
        }
    }
    return $paths -join ';'
}

function Get-PgBin {
    param([string]$Requested)
    if ($Requested) { $path = $Requested }
    elseif ($env:PG_BIN) { $path = $env:PG_BIN }
    else { $path = 'C:\Program Files\PostgreSQL\18\bin' }
    foreach ($tool in @('pg_ctl.exe', 'initdb.exe', 'psql.exe')) {
        if (!(Test-Path (Join-Path $path $tool))) {
            throw "Missing PostgreSQL binaries. Pass -PgBin '...\bin' or set PG_BIN."
        }
    }
    return $path
}

function Assert-FreePort {
    param([int]$Port)
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
    try { $listener.Start() }
    catch { throw "Local port $Port is already occupied; no existing service was changed." }
    finally { $listener.Stop() }
}

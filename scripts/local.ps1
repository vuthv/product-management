param(
    [ValidateSet('Start', 'Stop')][string]$Action = 'Start',
    [string]$PgBin
)
. "$PSScriptRoot\common.ps1"
Assert-Toolchain
$pg = Get-PgBin $PgBin
$pidFile = Join-Path $Local 'tomcat-process.json'

if ($Action -eq 'Stop') {
    if (Test-Path $pidFile) {
        $owned = Get-Content $pidFile -Raw | ConvertFrom-Json
        $process = Get-Process -Id $owned.id -ErrorAction SilentlyContinue
        if ($process) {
            if ($process.StartTime.ToUniversalTime().Ticks.ToString() -ne $owned.startedAt) {
                throw 'Stored Tomcat PID has been reused. Refusing to stop a different process.'
            }
            Stop-Process -Id $owned.id
            $process.WaitForExit(15000) | Out-Null
        }
        Remove-Item $pidFile
    }
    if (Test-Path "$PgData\postmaster.pid") {
        Invoke-Checked "$pg\pg_ctl.exe" @('-D', $PgData, '-w', '-m', 'fast', 'stop')
    }
    Write-Host 'Local demo stopped; database files are preserved.'
    exit 0
}

if (!(Test-Path "$Root\dist\product-management.war")) { throw 'Run build.bat first.' }
if (Test-Path $pidFile) { throw 'Local instance already started. Run stop-local.bat before starting again.' }
Assert-FreePort $HttpPort
if (!(Test-Path "$PgData\postmaster.pid")) { Assert-FreePort $PgPort }
New-Item $Local -ItemType Directory -Force | Out-Null
$stdinPath = Join-Path $Local 'empty-stdin.txt'
if (!(Test-Path $stdinPath)) { New-Item $stdinPath -ItemType File | Out-Null }
$passwordPath = Join-Path $Local 'db-password.txt'
if (!(Test-Path $passwordPath)) {
    if (Test-Path $PgData) { throw 'Existing cluster has no matching password file. Refusing to replace credentials.' }
    $random = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($random) } finally { $rng.Dispose() }
    [Convert]::ToBase64String($random) | Set-Content $passwordPath -Encoding ASCII
}
$password = (Get-Content $passwordPath -Raw).Trim()
if (!(Test-Path "$PgData\PG_VERSION")) {
    Invoke-Checked "$pg\initdb.exe" @('-D', $PgData, '-U', 'product_app', '--encoding=UTF8',
        '--locale=C', '--auth=scram-sha-256', "--pwfile=$passwordPath")
    Add-Content "$PgData\postgresql.conf" "`nlisten_addresses = '127.0.0.1'`nport = $PgPort"
}
if (!(Test-Path "$PgData\postmaster.pid")) {
    $pgArguments = @('-D', "`"$PgData`"", '-l', "`"$Local\postgres.log`"", '-w', 'start')
    $pgLauncher = Start-Process -FilePath "$pg\pg_ctl.exe" -ArgumentList $pgArguments `
        -RedirectStandardInput $stdinPath -RedirectStandardOutput "$Local\pgctl-start.log" `
        -RedirectStandardError "$Local\pgctl-start-error.log" -PassThru
    # Retain the handle so Windows PowerShell 5 can read the exit code.
    $null = $pgLauncher.Handle
    $pgLauncher.WaitForExit()
    $pgLauncher.Refresh()
    if ($pgLauncher.ExitCode -ne 0) { throw "PostgreSQL start failed. Inspect $Local\pgctl-start-error.log" }
}
$env:PGPASSWORD = $password
try {
    $query = & "$pg\psql.exe" -h 127.0.0.1 -p $PgPort -U product_app -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='productdb'"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the isolated database' }
    if ($query -ne '1') {
        Invoke-Checked "$pg\psql.exe" @('-h', '127.0.0.1', '-p', "$PgPort", '-U', 'product_app',
            '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-c', 'CREATE DATABASE productdb')
    }
    $table = & "$pg\psql.exe" -h 127.0.0.1 -p $PgPort -U product_app -d productdb -Atc "SELECT to_regclass('public.product') IS NOT NULL"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the isolated schema' }
    if ($table -ne 't') {
        Invoke-Checked "$pg\psql.exe" @('-h', '127.0.0.1', '-p', "$PgPort", '-U', 'product_app',
            '-d', 'productdb', '-v', 'ON_ERROR_STOP=1', '-f', "$Root\db\schema.sql")
    }
} finally { Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue }

New-Item "$TomcatBase\conf", "$TomcatBase\logs", "$TomcatBase\temp",
    "$TomcatBase\work", "$TomcatBase\webapps" -ItemType Directory -Force | Out-Null
Copy-Item "$TomcatHome\conf\web.xml" "$TomcatBase\conf\web.xml" -Force
Copy-Item "$TomcatHome\conf\catalina.properties" "$TomcatBase\conf\catalina.properties" -Force
Copy-Item "$TomcatHome\conf\logging.properties" "$TomcatBase\conf\logging.properties" -Force
Copy-Item "$Root\config\server.xml" "$TomcatBase\conf\server.xml" -Force
Copy-Item "$Root\dist\product-management.war" "$TomcatBase\webapps\product-management.war" -Force
$env:DB_URL = "jdbc:postgresql://127.0.0.1:$PgPort/productdb"
$env:DB_USERNAME = 'product_app'
$env:DB_PASSWORD = $password
try {
    $arguments = @("-Dcatalina.home=`"$TomcatHome`"", "-Dcatalina.base=`"$TomcatBase`"",
        "-Djava.io.tmpdir=`"$TomcatBase\temp`"", '-Dfile.encoding=UTF-8',
        "-Djava.util.logging.config.file=`"$TomcatBase\conf\logging.properties`"",
        '-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager',
        '-cp', "`"$TomcatHome\bin\bootstrap.jar;$TomcatHome\bin\tomcat-juli.jar`"",
        'org.apache.catalina.startup.Bootstrap', 'start')
    $process = Start-Process -FilePath "$JavaHome\bin\java.exe" -ArgumentList $arguments `
        -RedirectStandardInput $stdinPath -RedirectStandardOutput "$TomcatBase\logs\console.log" `
        -RedirectStandardError "$TomcatBase\logs\stderr.log" -PassThru
    @{id=$process.Id; startedAt=$process.StartTime.ToUniversalTime().Ticks.ToString()} |
        ConvertTo-Json | Set-Content $pidFile -Encoding ASCII
} finally {
    Remove-Item Env:\DB_PASSWORD, Env:\DB_USERNAME, Env:\DB_URL -ErrorAction SilentlyContinue
}
Write-Host "Starting $AppUrl ... (Tomcat PID $($process.Id))"
for ($i = 0; $i -lt 60; $i++) {
    if ($process.HasExited) { throw "Tomcat exited. Inspect $TomcatBase\logs\stderr.log" }
    try {
        $response = Invoke-WebRequest -UseBasicParsing "$AppUrl/api/products?size=1" -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            Write-Host "Ready: $AppUrl/"
            exit 0
        }
    } catch [System.Net.WebException] {
        if ($i -eq 59) { throw "Readiness failed. Inspect $TomcatBase\logs\product-management.log and stderr.log" }
    }
    Start-Sleep -Seconds 1
}
throw 'Readiness failed'

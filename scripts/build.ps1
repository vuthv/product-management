. "$PSScriptRoot\common.ps1"
Assert-Toolchain
$stage = Join-Path $Root '.build\war'
$frontendOut = Join-Path $Root '.build\frontend'
$runtimeClasspath = Get-ClassPath @('runtime', 'provided')
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item "$stage\WEB-INF\classes", "$stage\WEB-INF\lib", (Join-Path $Root 'dist') -ItemType Directory -Force | Out-Null
$sources = @(Get-ChildItem (Join-Path $Root 'src') -Filter '*.java' -Recurse | Select-Object -ExpandProperty FullName)
Write-Host 'Compiling Java 8 with javac...'
Invoke-Checked "$JavaHome\bin\javac.exe" (@('-encoding', 'UTF-8', '-source', '8', '-target', '8',
    '-parameters', '-cp', $runtimeClasspath, '-d', "$stage\WEB-INF\classes") + $sources)
Copy-Item "$Root\resources\*" "$stage\WEB-INF\classes" -Recurse
Copy-Item "$Root\webapp\*" $stage -Recurse -Force
foreach ($dependency in Get-Dependencies) {
    if ($dependency.scope -eq 'runtime') {
        Copy-Item "$Root\lib\$($dependency.artifact)-$($dependency.version).jar" "$stage\WEB-INF\lib"
    }
}
Write-Host 'Building Angular into static resources...'
Push-Location "$Root\frontend"
try {
    Invoke-Checked "$NodeHome\npm.cmd" @('run', 'build')
} finally { Pop-Location }
Copy-Item $frontendOut "$stage\static" -Recurse
Write-Host 'Packaging WAR with jar...'
Invoke-Checked "$JavaHome\bin\jar.exe" @('cf', "$Root\dist\product-management.war", '-C', $stage, '.')
Write-Host "Built: $Root\dist\product-management.war"

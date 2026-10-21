param([Parameter(Mandatory=$true)][string]$TomcatBase)
$requestedBase = $TomcatBase
. "$PSScriptRoot\common.ps1"
$target = (Resolve-Path $requestedBase).Path
if (!(Test-Path "$target\conf\server.xml") -or !(Test-Path "$target\webapps")) {
    throw 'Target is not a Tomcat base directory.'
}
$war = "$target\webapps\product-management.war"
if ((Test-Path $war) -or (Test-Path "$target\webapps\product-management")) {
    throw 'A deployment already exists. Stop Tomcat and archive/remove that specific application yourself before deploying.'
}
if (!(Test-Path "$Root\dist\product-management.war")) { throw 'Run build.bat first.' }
Copy-Item "$Root\dist\product-management.war" $war
Write-Host "Deployed $war"
Write-Host 'Configure DB_URL/DB_USERNAME/DB_PASSWORD or conf\product-db.properties before starting Tomcat.'

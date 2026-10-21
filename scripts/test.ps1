. "$PSScriptRoot\common.ps1"
Assert-Toolchain
$classes = Join-Path $Root '.build\war\WEB-INF\classes'
if (!(Test-Path "$classes\com\example\product\controller\ProductController.class")) {
    throw 'Build first: build.bat'
}
$testClasses = Join-Path $Root '.build\test-classes'
New-Item $testClasses -ItemType Directory -Force | Out-Null
$classpath = "$classes;$(Get-ClassPath @('runtime', 'provided', 'test'))"
$sources = @(Get-ChildItem "$Root\test" -Filter '*.java' -Recurse | Select-Object -ExpandProperty FullName)
Invoke-Checked "$JavaHome\bin\javac.exe" (@('-encoding', 'UTF-8', '-cp', $classpath, '-d', $testClasses) + $sources)
New-Item "$Root\.build\test-logs" -ItemType Directory -Force | Out-Null
Invoke-Checked "$JavaHome\bin\java.exe" @("-Dcatalina.base=$Root\.build\test-logs", '-cp',
    "$testClasses;$classpath", 'org.junit.runner.JUnitCore', 'com.example.product.ProductApiTest')

. "$PSScriptRoot\common.ps1"
if (!(Test-Path "$Local\tomcat-process.json")) { throw 'Start the isolated demo using start-local.bat first.' }
$script:checks = 0
$created = New-Object 'System.Collections.Generic.List[long]'

function Assert-Result {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAILED: $Message" }
    $script:checks++
    Write-Host "PASS: $Message"
}

function Send-Request {
    param([string]$Method, [string]$Path, [string]$Body, [int]$Expected = 200,
          [string]$ContentType = 'application/json')
    $request = [System.Net.HttpWebRequest]::Create("$AppUrl$Path")
    $request.Method = $Method
    $request.Accept = 'application/json'
    $request.Timeout = 10000
    if ($Body) {
        $request.ContentType = $ContentType
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    try { $response = $request.GetResponse() }
    catch [System.Net.WebException] {
        if (!$_.Exception.Response) { throw }
        $response = $_.Exception.Response
    }
    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream(), [System.Text.Encoding]::UTF8)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        Assert-Result ([int]$response.StatusCode -eq $Expected) "$Method $Path -> HTTP $Expected"
        $bodyObject = $text | ConvertFrom-Json
        $keys = @($bodyObject.PSObject.Properties.Name | Sort-Object) -join ','
        Assert-Result ($keys -eq 'code,data,message') 'Exact code/message/data envelope'
        Assert-Result (($Expected -lt 400 -and $bodyObject.code -eq 0) -or
            ($Expected -ge 400 -and $bodyObject.code -eq $Expected)) 'Envelope code agrees with HTTP result'
        return $bodyObject
    } finally { $response.Close() }
}

$token = "Smoke-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
$baseline = (Send-Request GET '/api/products?size=1').data.total
try {
    foreach ($item in @(
        @{name="$token Keyboard"; description='Test product'; price=20.25},
        @{name="$token Mouse"; description='Test product'; price=10.50},
        @{name="$token %_"; description='Literal wildcard product'; price=0}
    )) {
        $product = (Send-Request POST '/api/products' ($item | ConvertTo-Json -Compress) 201).data
        $created.Add([long]$product.id)
        Assert-Result ([decimal]$product.price -eq [decimal]$item.price) 'Exact monetary value round-trips'
        Assert-Result ($product.createdAt -match 'Z$') 'Timestamp is ISO-8601 UTC'
    }
    $id = $created[0]
    Assert-Result ((Send-Request GET "/api/products/$id").data.name -eq "$token Keyboard") 'GET by ID reads persisted product'
    $updated = (Send-Request PUT "/api/products/$id" (@{
        name="$token Keyboard updated"; description='Edited'; price=21.75
    } | ConvertTo-Json -Compress)).data
    Assert-Result ($updated.name -eq "$token Keyboard updated" -and [decimal]$updated.price -eq 21.75) 'PUT updates editable fields'
    $name = [Uri]::EscapeDataString($token)
    $page1 = (Send-Request GET "/api/products?name=$name&page=1&size=1").data
    $page2 = (Send-Request GET "/api/products?name=$name&page=2&size=1").data
    Assert-Result ($page1.total -eq 3 -and $page1.totalPages -eq 3 -and $page1.items.Count -eq 1) 'COUNT and first-page shape'
    Assert-Result ($page2.page -eq 2 -and $page2.items[0].id -ne $page1.items[0].id) 'Stable paging returns distinct rows'
    $empty = (Send-Request GET "/api/products?name=$name&page=999&size=1").data
    Assert-Result ($empty.total -eq 3 -and $empty.items.Count -eq 0) 'Beyond-last page preserves total'
    Assert-Result ((Send-Request GET "/api/products?name=$name&minPrice=15&maxPrice=25").data.total -eq 1) 'Combined name and range filters'
    Assert-Result ((Send-Request GET "/api/products?name=$name&price=0").data.total -eq 1) 'Exact zero price filter'
    Assert-Result ((Send-Request GET "/api/products?name=$name&maxPrice=15").data.total -eq 2) 'Max-only price filter'
    Assert-Result ((Send-Request GET "/api/products?name=$name&minPrice=15").data.total -eq 1) 'Min-only price filter'
    $literal = [Uri]::EscapeDataString("$token %_")
    Assert-Result ((Send-Request GET "/api/products?name=$literal").data.total -eq 1) 'Search treats percent and underscore as literal characters'
    $injection = [Uri]::EscapeDataString("' OR 1=1 --")
    Assert-Result ((Send-Request GET "/api/products?name=$injection").data.total -eq 0) 'SQL injection text is bound as data'

    Send-Request POST '/api/products' '{"name":"  ","price":1}' 400 | Out-Null
    Send-Request POST '/api/products' '{"name":"Invalid","price":-1}' 400 | Out-Null
    Send-Request POST '/api/products' '{"name":"Invalid","price":1.001}' 400 | Out-Null
    Send-Request POST '/api/products' '{"name":"Invalid","price":10000000000}' 400 | Out-Null
    Send-Request POST '/api/products' '{"name":"Invalid"}' 400 | Out-Null
    Send-Request POST '/api/products' '{bad' 400 | Out-Null
    Send-Request POST '/api/products' 'null' 400 | Out-Null
    Send-Request POST '/api/products' '{"name":"Invalid","price":1,"id":4}' 400 | Out-Null
    Send-Request POST '/api/products' 'wrong media type' 415 'text/plain' | Out-Null
    foreach ($query in @('page=0', 'size=101', 'size=0', 'page=abc', 'price=oops',
        'minPrice=10&maxPrice=1', 'price=1&minPrice=1')) {
        Send-Request GET "/api/products?$query" '' 400 | Out-Null
    }
    Send-Request GET '/api/products/abc' '' 400 | Out-Null
    Send-Request DELETE '/api/products/0' '' 400 | Out-Null
    Send-Request GET '/api/products/9223372036854775807' '' 404 | Out-Null
    Send-Request PUT '/api/products/9223372036854775807' '{"name":"Missing","price":1}' 404 | Out-Null
    Send-Request DELETE '/api/products/9223372036854775807' '' 404 | Out-Null
    Send-Request GET '/api/missing' '' 404 | Out-Null
    Send-Request PATCH "/api/products/$id" '' 405 | Out-Null
    foreach ($productId in @($created.ToArray())) {
        $deleted = Send-Request DELETE "/api/products/$productId"
        Assert-Result ($null -eq $deleted.data) 'DELETE returns null data with JSON envelope'
        $created.Remove($productId) | Out-Null
        Send-Request GET "/api/products/$productId" '' 404 | Out-Null
    }
    Assert-Result ((Send-Request GET '/api/products?size=1').data.total -eq $baseline) 'Smoke fixtures removed; original data preserved'
    $index = Invoke-WebRequest -UseBasicParsing "$AppUrl/"
    Assert-Result ($index.StatusCode -eq 200 -and $index.Content -match '<app-root>') 'Angular index served by Spring'
    $main = [regex]::Match($index.Content, 'src="(main\.[^"]+\.js)"')
    Assert-Result $main.Success 'Production JavaScript bundle referenced'
    $js = Invoke-WebRequest -UseBasicParsing "$AppUrl/static/$($main.Groups[1].Value)"
    Assert-Result ($js.StatusCode -eq 200 -and $js.Content.Length -gt 1000) 'mvc:resources serves compiled Angular JavaScript'
    $log = Get-Content "$TomcatBase\logs\product-management.log" -Encoding UTF8 -Raw
    Assert-Result ($log.Contains($token) -and $log.Contains('ProductController')) 'Business operations recorded in application log'
    Write-Host "`nSmoke suite passed: $script:checks assertions."
} finally {
    foreach ($productId in $created) {
        Send-Request DELETE "/api/products/$productId" | Out-Null
    }
}

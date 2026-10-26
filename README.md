# Product Management - Spring MVC non-Boot

Project demo độc lập tại `E:\product-management`, tham khảo cách chia controller /
service / mapper, Spring XML và Angular NgModule của WebPOS. Không phụ thuộc
database, code nghiệp vụ, JAR riêng hay công cụ build của WebPOS.

## Công nghệ và phạm vi

| Thành phần | Phiên bản |
| --- | --- |
| Java | Temurin JDK 8u504 (portable) |
| Spring MVC / JDBC / TX | 5.3.39, cấu hình XML, không Spring Boot |
| MyBatis / MyBatis-Spring | 3.5.19 / 2.1.2 |
| Database | PostgreSQL 18 local, JDBC 42.7.7 |
| Pool | HikariCP 4.0.3 |
| JSON | Jackson 2.18.3, Java Time |
| Logging | SLF4J 2.0.17 + Log4j2 2.24.3 |
| Frontend | Angular 12.2.17, CLI 12.2.18, TypeScript 4.3.5 |
| Node / npm | 14.21.3 / 6.x (portable, không sửa Node toàn máy) |
| Servlet container | Tomcat 9.0.118, `javax.servlet` 4.0 |

**Chỉ dành cho học tập/local.** Spring 5, Angular 12 và Node 14 là các dòng legacy,
không coi bộ dependency này là baseline production đã được kiểm tra bảo mật.
Demo không có đăng nhập/phân quyền. Tomcat và PostgreSQL demo chỉ bind
`127.0.0.1`. Không mở ra Internet hoặc dùng dữ liệu thật. Không dùng Tomcat 10+
vì đã chuyển từ `javax.*` sang `jakarta.*`.

Không có Maven, Gradle hoặc Ant. Java được compile trực tiếp bằng `javac`, đóng
gói bằng `jar`. npm/Angular CLI chỉ build frontend, theo yêu cầu Angular.

## Chạy nhanh trên Windows

Cần Internet cho lần setup đầu, Windows PowerShell 5.1, `curl.exe`, và PostgreSQL
đã cài (cần `bin\initdb.exe`, `bin\pg_ctl.exe`, `bin\psql.exe`; không cần dùng
service/database PostgreSQL đang có).

```powershell
Set-Location E:\product-management
.\setup.bat
.\build.bat
.\test.bat
.\start-local.bat
.\smoke-test.bat
Start-Process http://127.0.0.1:18080/product-management/
```

Nếu PostgreSQL không ở `C:\Program Files\PostgreSQL\18\bin`:

```powershell
.\start-local.bat -PgBin "C:\Program Files\PostgreSQL\17\bin"
```

Dừng cả Tomcat và PostgreSQL demo:

```powershell
.\stop-local.bat
```

- `setup.bat` tải JAR từ Maven Central bằng HTTP, **không chạy Maven**.
  Danh sách dependency và scope được quản lý thủ công trong
  [dependencies.json](./dependencies.json), không tự resolve transitive dependency.
  SHA-1 do repository cung cấp được kiểm tra cho từng JAR; SHA-256 của bộ tải về
  lưu ở `lib\checksums.sha256`. Tool portable dùng SHA-256/SHA-512.
- Lần đầu, `start-local.bat` tạo cluster hoàn toàn mới tại `.local\pgdata`,
  cổng `55432`, DB `productdb`, user `product_app`; khởi tạo
  [schema.sql](./db/schema.sql) và 12 sản phẩm mẫu **chỉ trong cluster đó**.
- Mật khẩu ngẫu nhiên được lưu riêng ở `.local\db-password.txt` để khởi động lại.
  `.local` bị ignore; không chia sẻ/commit thư mục này. Role trong cluster
  demo có quyền quản trị để đơn giản hóa init; với DB tự quản lý hãy dùng role
  chỉ có quyền cần thiết.
- Nếu cổng `18080` hoặc `55432` đang có dịch vụ khác, script báo lỗi thay vì
  dừng hay ghi đè dịch vụ đó. Các cổng demo được cố định trong
  [common.ps1](./scripts/common.ps1) và [server.xml](./src/config/server.xml).
- `start-local.bat` copy WAR vào `.local\tomcat\webapps`, kiểm tra API thực sự
  trả HTTP 200 rồi mới báo `Ready`. Không đăng ký Windows service.
- Khi sửa source: dừng demo, chạy lại `build.bat`, `test.bat`, rồi start.
  Dữ liệu được giữ khi dừng/khởi động lại, không tự xóa hoặc reset bảng.
- Nếu startup lỗi, xem `.local\tomcat\logs\stderr.log`,
  `.local\tomcat\logs\product-management.log` và `.local\postgres.log`,
  sau đó chạy `stop-local.bat` trước khi thử lại.

## Cấu trúc và luồng xử lý

```text
src/main/java/com/example/product/
  controller/     REST mappings, log thao tác sau transaction thành công
  service/        validation, transaction và nghiệp vụ CRUD
  mapper/         interface MyBatis
  model/          Product, ProductInput, ProductFilter
  common/         ApiResponse, PageResult
  exception/      global advice và exception nghiệp vụ
src/resources/
  mappers/ProductMapper.xml
  log4j2.xml
src/webapp/WEB-INF/
  web.xml
  applicationContext.xml
  dispatcher-servlet.xml
src/config/
  server.xml
  db.properties.template
frontend/         Angular source, test, package-lock
db/schema.sql
scripts/          PowerShell build/setup/test/local/deploy
test/             JUnit + Spring MockMvc
dist/product-management.war
```

Browser → Angular `ProductService` → `/api/products` → controller → service
transaction → MyBatis mapper/XML → HikariCP → PostgreSQL → JSON envelope → UI.

`web.xml` khai báo `ContextLoaderListener`, UTF-8 filter và `DispatcherServlet`.
Root context chứa datasource, `SqlSessionFactoryBean`, mapper scan và transaction
manager; child MVC context chứa controller/advice và Jackson.
Không auto-migrate khi Spring khởi động. Chỉ script local init chạy schema trên
cluster riêng.

`<mvc:resources mapping="/static/**" location="/static/"/>` phục vụ Angular.
`/` forward tới `/static/index.html`; base href tương đối `./static/` giúp WAR
hoạt động với context path tùy tên WAR. API URL được tính tương đối với base URI,
không hard-code host/port trong production frontend. Demo một trang không có
Angular Router nên không có vấn đề F5 trên route con.

## API contract

Base URL: `http://127.0.0.1:18080/product-management`

| Method | Path | HTTP thành công | Ý nghĩa |
| --- | --- | --- | --- |
| GET | `/api/products/{id}` | 200 | Chi tiết sản phẩm |
| POST | `/api/products` | 201 + `Location` | Thêm sản phẩm |
| PUT | `/api/products/{id}` | 200 | Thay thế toàn bộ trường được sửa |
| DELETE | `/api/products/{id}` | 200 | Xóa cứng; `data: null` |
| GET | `/api/products` | 200 | Danh sách, filter, phân trang |

POST và PUT yêu cầu `Content-Type: application/json`:

```json
{"name":"Mechanical Keyboard","description":"Compact keyboard","price":89.90}
```

`name` bắt buộc, trim, 1–255 ký tự và không có control character.
`description` tùy chọn, tối đa 1000 ký tự. `price` bắt buộc, từ 0 đến
9999999999.99; không làm tròn input có quá 2 chữ số thập phân có nghĩa.
Backend dùng `BigDecimal`, PostgreSQL dùng `NUMERIC(12,2)`.
Không đặt tên tiền tệ vì requirement không quy định currency.
Không chấp nhận các field lạ, ví dụ `id` trong POST/PUT. PUT không phải PATCH.
`id`, timestamps được server quản lý. Timestamp trả ISO-8601 UTC.

Thành công:

```json
{
  "code": 0,
  "message": "Product created",
  "data": {
    "id": 13,
    "name": "Mechanical Keyboard",
    "description": "Compact keyboard",
    "price": 89.90,
    "createdAt": "2026-10-21T03:00:00Z",
    "updatedAt": "2026-10-21T03:00:00Z"
  }
}
```

Danh sách: `GET /api/products?name=mouse&minPrice=0&maxPrice=100&page=1&size=10`

```json
{
  "code": 0,
  "message": "OK",
  "data": {
    "items": [],
    "total": 0,
    "page": 1,
    "size": 10,
    "totalPages": 0
  }
}
```

- `name`: tìm chứa chuỗi, không phân biệt hoa/thường (`ILIKE`); `%`, `_` trong
  input được coi là ký tự thường, không mở rộng thành wildcard.
- `price`: so sánh giá chính xác; hoặc `minPrice`/`maxPrice` là khoảng **bao gồm**
  hai đầu. Không được kết hợp `price` với min/max; khoảng ngược trả 400.
- Không truyền filter → lấy tất cả; `page` mặc định 1, `size` mặc định 10,
  giới hạn 1–100. Sắp xếp cố định `id DESC`; trang vượt cuối trả `items: []`
  nhưng giữ `total`.
- MyBatis dùng `<sql>`, `<include>`, `<where>`, `<if>` và `#{...}` cho mọi giá trị;
  COUNT và SELECT dùng chung filter. Transaction read-only REPEATABLE_READ giữ
  count/items trong cùng snapshot.
- Không có unique constraint tên: tên trùng được phép theo requirement hiện tại.
  Update dùng last-write-wins; không có optimistic lock hay chức năng authentication.

Lỗi cũng có đúng 3 field; dùng HTTP status thật, không trả HTTP 200 giả:

```json
{"code":400,"message":"Invalid input","data":{"name":"Name is required"}}
```

| HTTP/code | Trường hợp |
| --- | --- |
| 400 | Input, query, ID, JSON không hợp lệ |
| 404 | Sản phẩm hoặc endpoint không tồn tại |
| 405 / 415 | Sai HTTP method / Content-Type |
| 409 | Vi phạm constraint DB |
| 503 | Lỗi truy cập DB |
| 500 | Lỗi không dự kiến; không lộ stack trace ra client |

Client nên gửi `Accept: application/json`. Lỗi trước khi app được deploy/khởi động,
request bị Tomcat từ chối hoặc lỗi mạng không nằm trong Spring advice.

## Logging và exception

SLF4J gọi Log4j2, không dùng Log4j 1.x. Log console và rolling UTF-8 file:
`.local\tomcat\logs\product-management.log`.

- Thành công sau service transaction: `Tạo sản phẩm mới tên XYZ (ID ...)`,
  `Cập nhật sản phẩm ID ...`, `Xóa sản phẩm ID ...`.
- Validation/not-found/protocol lỗi client: WARN, không in raw request body.
- Lỗi DB và lỗi không dự kiến: ERROR kèm exception/stack trace ở log server.
- Không đưa credential, request body hay stack trace vào response.

## Kiểm thử

```powershell
.\test.bat                    # JUnitCore, MockMvc, validation, mapper dynamic SQL
.\start-local.bat
.\smoke-test.bat              # API thật + PostgreSQL + static Angular resources
.\stop-local.bat
```

JUnit dùng mapper in-memory để kiểm tra API/service, **không chứng minh DB chạy**.
Smoke suite mới kiểm tra SQL PostgreSQL thật, wildcard escaping, phân trang,
CRUD, JSON lỗi và resource mapping. Smoke tự tạo sản phẩm có token riêng và
xóa chúng trong `finally`; không reset dữ liệu khác.

Frontend unit test (cần Chrome, hoặc set `CHROME_BIN` tới Chromium phù hợp):

```powershell
$env:Path = "E:\product-management\.tools\node14;$env:Path"
Set-Location E:\product-management\frontend
& ..\.tools\node14\npm.cmd test
```

Chạy UI dev riêng (cần start backend trước):

```powershell
& ..\.tools\node14\npm.cmd start
```

Dev proxy `/api` → local Tomcat `/product-management/api`, không thêm CORS
vào backend. Build production không dùng proxy.

## Deploy vào Tomcat 9 khác do bạn quản lý

Tạo DB riêng và chạy [schema.sql](./db/schema.sql) một lần bằng `psql`; đây không
phải migration idempotent. Không chạy lên DB WebPOS hay DB dùng chung.

Copy [db.properties.template](./src/config/db.properties.template) thành
`TOMCAT_BASE\conf\product-db.properties` rồi sửa giá trị, hoặc truyền biến môi
trường `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` vào process Tomcat. Không có mật khẩu
mặc định/fallback. Không commit file cấu hình thật.

```powershell
.\build.bat
.\deploy.bat -TomcatBase "E:\my-tomcat9"
```

Script chỉ copy `dist\product-management.war`, không start/stop Tomcat đích và
không ghi đè deployment đã có. Chỉ định đúng CATALINA_BASE được bạn cho phép sử
dụng. Servlet API có scope `provided`, JUnit/Spring Test có scope `test`; không
đóng gói các JAR đó vào WAR.

Build stage ở `.build\war`: `WEB-INF\classes` chứa Java/resource,
`WEB-INF\lib` chứa runtime JAR, `static` chứa bundle Angular. WAR dùng được
trực tiếp trên Tomcat 9 + Java 8 với cấu hình DB tương ứng.

## Kết quả kiểm chứng tại máy local (2026-10-21)

| Check | Lệnh/thao tác | Kết quả |
| --- | --- | --- |
| Build đầy đủ | `.\build.bat` từ project root | PASS; Angular production + WAR khoảng 13.5 MiB |
| Backend | `.\test.bat` từ project root | 21 JUnit/MockMvc tests PASS |
| Frontend | `npm.cmd test` từ `frontend`, dùng Node portable + ChromeHeadless | 16 tests PASS |
| Integration | `.\start-local.bat`, `.\smoke-test.bat` | 160 assertions PASS với PostgreSQL 18 thật |
| Browser | UI trên WAR đã deploy | Thêm, sửa, xóa, filter tên + khoảng giá, phân trang, reload PASS |
| Responsive | Browser ở 1440px và 390px | Không tràn ngang toàn trang |
| Logging | Đọc application log dưới dạng UTF-8 | Có log tạo/sửa/xóa tiếng Việt; không có ERROR trong smoke run |
| WAR scope | Kiểm tra bằng `jar tf` | 22 runtime JAR; không đóng gói servlet API, JUnit hoặc Spring Test |
| Restart | Stop → start → GET → stop | Launcher trả lại terminal; 12 sản phẩm mẫu được giữ nguyên |

Các lỗi DB/constraint/500 được mô phỏng trong JUnit để kiểm tra envelope và
logging; chưa chủ động làm hỏng hay tắt DB trong lúc chạy request thật.
Đây không phải kiểm thử tải, kiểm thử concurrency hay kiểm toán bảo mật.

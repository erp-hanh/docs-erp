# ADR-0003: Multi-tenant-ready bằng shared database và cột company_id

**Status:** Accepted (2026-08-10)

## Context

Ở thời điểm quyết, hệ thống có **đúng một** khách hàng: doanh nghiệp cơ khí và cảng
đang đặt hàng xây dựng. Nhưng mô hình kinh doanh dự kiến là bán lại cho các doanh
nghiệp cùng ngành, nên khách thứ hai là chuyện "khi nào", không phải "có hay không".
Không ai biết khi nào, và không ai muốn trả trước toàn bộ chi phí của một hệ
multi-tenant thật cho một khách duy nhất.

Điểm mấu chốt là tính bất đối xứng của chi phí. Thêm cột `company_id` vào một schema
**trống** là gõ thêm một dòng mỗi migration. Thêm `company_id` vào một hệ đã chạy hai
năm với dữ liệu thật là: một migration khóa bảng, một lượt rà toàn bộ repository để
thêm điều kiện lọc, và một khoảng thời gian mà việc bỏ sót một câu query đồng nghĩa
với rò dữ liệu giữa hai công ty. Khoản thứ hai đắt hơn khoản thứ nhất nhiều bậc, và
rủi ro của nó không nằm ở tiền.

Hạ tầng lúc đó là một PostgreSQL, không có đội vận hành database, không có công cụ
điều phối migration trên nhiều database.

## Decision

**Mọi bảng trừ các nhóm được miễn tường minh đều mang cột `company_id UUID NOT NULL`;
hệ thống vận hành single-tenant trên một database dùng chung; chưa làm
database-per-tenant.**

Nói cách khác: trả trước phần rẻ (cột và điều kiện lọc), hoãn phần đắt (tách hạ tầng)
cho tới khi có khách hàng thật đòi nó.

Phạm vi:

- Quyết định này chốt **cấu trúc dữ liệu**, không chốt cách vận hành. Chạy hai bản
  triển khai riêng cho hai khách hàng vẫn đúng với ADR này.
- Cách ly giữa tenant nằm ở **tầng ứng dụng** — mọi query mang `company_id = $n` —
  chứ không ở tầng database. Row Level Security chưa được bật.
- Ba nhóm bảng miễn trừ và danh sách miễn quy tắc đặt tên được liệt kê ngay trong ADR
  này, ở mục dưới.

## Alternatives

**Database-per-tenant** — loại. Nó cho cách ly mạnh nhất và cho phép backup/restore
theo từng khách, nhưng chi phí vận hành và migration nhân theo số khách: mỗi lần đổi
schema là N lần chạy migration cần theo dõi, mỗi khách là một chuỗi kết nối và một
lịch backup. Với N = 1 thì toàn bộ chi phí đó là chi phí thuần, đổi lấy một khả năng
chưa có ai cần. Và quan trọng: chọn nó **sau** vẫn khả thi — cột `company_id` chính
là thứ cho phép tách dữ liệu ra theo từng khách khi cần; chọn nó trước rồi muốn gộp
lại thì khó hơn nhiều.

**Schema-per-tenant** — loại. Nó hứa hẹn nằm giữa hai phương án trên nhưng thực tế
mang phần dở của cả hai: vẫn phải chạy migration N lần, vẫn dùng chung một instance
nên không cách ly được tài nguyên, cộng thêm việc mọi connection phải đặt đúng
`search_path` và mọi sai sót ở chỗ đó đều im lặng. Số lượng đối tượng schema cũng
tăng tuyến tính theo số khách, làm chậm chính các công cụ quản trị database.

**Không chuẩn bị gì, làm single-tenant thuần** — loại. Đây là phương án rẻ nhất hôm
nay và là khoản nợ đắt nhất đã nhận diện được ở mục Context: thêm `company_id` vào một
hệ thống đã có dữ liệu là việc đắt và rủi ro, và nó rơi vào đúng lúc dự án đang gấp vì
vừa có khách hàng mới.

## Bốn danh sách miễn trừ

Bốn danh sách dưới đây là **nguồn sự thật** cho R-02, R-06, R-08, R-09, R-17 và R-18.
`04-conventions/C-DB-database.md` chỉ được **sao chép lại** chúng, không phải nơi quyết
định. Phân loại tổng quát nằm ở blockquote "Bốn nhóm bảng" dưới R-06 trong
[../01-rules/RULES.md](../01-rules/RULES.md); ở đây là danh sách tên cụ thể.

### 1. `system_tables` — bảng hạ tầng, không thuộc tenant nào

Khởi đầu gồm:

- `schema_migrations`
- `companies`

Được miễn: `company_id`, mọi cột thời gian (`created_at`, `updated_at`, `deleted_at`),
mọi cột audit (`created_by`, `updated_by`), soft delete, và cả việc sinh bản ghi audit
khi ghi. Mọi module được đọc.

Lý do miễn triệt để: `schema_migrations` do `golang-migrate` sở hữu, không phải do ứng
dụng; còn `companies` là bảng **định nghĩa** tenant nên nó không thể mang khóa trỏ tới
chính khái niệm nó định nghĩa. Nhóm này phải giữ nhỏ nhất có thể — mỗi tên thêm vào
đây là một bảng nằm ngoài toàn bộ cơ chế truy vết.

### 2. `reference_tables` — danh mục dùng chung toàn hệ thống

Khởi đầu gồm:

- `currencies`
- `units`
- `provinces`

Không có `company_id`, và mọi module được đọc. Ngoài hai điểm đó thì **giống hệt bảng
nghiệp vụ**: có đủ `created_at`, `updated_at`, `deleted_at`, có `created_by`,
`updated_by`, mọi thao tác ghi lên nó vẫn sinh bản ghi audit, và vẫn chịu soft delete.

Lý do không gộp vào `system_tables`: danh mục **có người sửa**, và sửa một danh mục
dùng chung thì ảnh hưởng tới mọi công ty cùng lúc — đó là chỗ cần truy vết nhất chứ
không phải chỗ được miễn. Bản ghi audit sinh ra mang `company_id` của actor đã sửa, vì
`audit_logs` luôn có `company_id` dù bảng bị sửa thì không.

Điều kiện để một tên được đưa vào nhóm này: dữ liệu **giống nhau với mọi tenant** và
không tenant nào được sửa riêng phần của mình. Danh mục mà mỗi công ty muốn một bản
khác nhau (nhóm khách hàng, loại chi phí) là **bảng nghiệp vụ**, không phải danh mục
dùng chung.

### 3. `append_only_tables` — bảng chỉ ghi thêm

Khởi đầu gồm:

- `outbox`
- `audit_logs`
- `idempotency_keys`

Có `company_id`, có `created_at` và `created_by`. Được miễn: `updated_at`,
`updated_by`, `deleted_at`, và miễn sinh bản ghi audit khi ghi. Được **hard delete
theo lịch giữ liệu mà không cần ADR riêng** — đây là ngoại lệ tường minh của R-18, và
nó chỉ hợp lệ vì bản ghi trong nhóm này không phải dữ liệu nghiệp vụ mà là dấu vết kỹ
thuật có hạn dùng.

Không phải mọi module đọc được: bảng trong nhóm này thuộc về hạ tầng chung, và module
chạm tới chúng qua package dùng chung (`shared/outbox`, repository audit), không phải
bằng câu SQL viết trong module mình.

Ba lý do cụ thể:

- `outbox` được ghi rồi được đánh dấu đã publish rồi bị dọn; không ai sửa nội dung một
  event đã ghi, vì sửa nó nghĩa là sửa một sự việc đã xảy ra.
- `audit_logs` mà sửa được thì không còn là audit. Miễn "sinh bản ghi audit khi ghi"
  không phải nới lỏng mà là chặn đệ quy vô hạn.
- `idempotency_keys` được ghi một lần cùng transaction với hiệu ứng nó bảo vệ, rồi hết
  hạn thì bị dọn — đúng hình dạng của nhóm này.
  [P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md) đã nêu rằng việc
  phân nhóm bảng này phải quyết bằng một ADR **trước** khi viết migration; đây là chỗ
  quyết. Hệ quả cài đặt phải chấp nhận: vì bảng không có `updated_at`, khóa và **kết
  quả** phải được ghi trong cùng một lần ghi, không phải claim trước rồi `UPDATE` kết
  quả sau.

### 4. Danh sách miễn quy tắc đặt tên

R-08 đòi tên bảng khớp `^[a-z][a-z0-9_]*s$`. Những tên dưới đây được miễn:

- `outbox` — kết thúc bằng `x`, và `outboxes` là một cái tên không ai gọi.

Danh sách này khởi đầu chỉ có một tên, nhưng nó sẽ dài ra và chỗ dài ra đã đoán trước
được: **tên tiếng Anh không đếm được hoặc bất quy tắc** — `inventory`, `equipment`,
`machinery` là ba ca gần nhất sẽ gặp. Mỗi tên như vậy **phải được thêm vào đây bằng
một ADR mới trước khi merge migration tạo bảng**, không phải bằng một ngoại lệ ghi
trong chính migration đó, và cũng không bằng cách ép thành `inventorys`.

Lý do bắt buộc ADR cho một việc nhỏ như đặt tên: quyết định "bảng này gọi là
`inventory` chứ không phải `inventory_items`" thực chất là quyết định về **mô hình dữ
liệu** — nó nói rằng ở đây có một khối không đếm được chứ không phải một tập các dòng.
Đó là thứ đáng ghi lại lý do, và cũng là thứ mà việc phải viết một ADR sẽ buộc người
ta nghĩ thêm một lần trước khi chọn.

## Quy tắc quản trị bốn danh sách

**Thêm một tên vào bất kỳ danh sách nào ở trên bắt buộc viết một ADR mới.** Không sửa
tại chỗ ADR này — ADR là bất biến; ADR mới nêu tên được thêm, lý do, và trỏ ngược về
đây.

Lý do không để các danh sách này ở tầng Convention: chúng là **công tắc miễn trừ cùng
lúc nhiều Rule**. Một cái tên nằm trong `system_tables` là một cái tên nằm ngoài R-06,
ngoài vế cột của R-08, ngoài R-17 và ngoài R-18. Nếu danh sách nằm ở tầng Convention
thì một PR sửa Convention vô hiệu hóa được bốn Rule cùng lúc mà vẫn hợp lệ về hình
thức — trái thứ tự ưu tiên `Rules > Principles > Conventions`, và trái nó theo cách
không ai nhìn ra trong lúc review.

Hệ quả thực dụng: người viết migration cho một bảng mới có đúng hai lựa chọn — hoặc
bảng đó là bảng nghiệp vụ và không được miễn gì, hoặc dừng lại viết ADR. Không có
đường thứ ba, và độ ma sát đó là có chủ đích.

## Bảng hạ tầng chưa phân loại — câu hỏi còn mở

`document_counters` (bảng cấp số chứng từ, chốt ở
[P-CONC-concurrency.md](../02-principles/P-CONC-concurrency.md)) chưa thuộc nhóm nào,
và ADR này **không** quyết thay:

- Nó bị `UPDATE` liên tục — mỗi lần cấp số là một `UPDATE ... RETURNING` trên đúng một
  hàng — nên **không** thuộc `append_only_tables`, nhóm đó định nghĩa là chỉ ghi thêm.
- Nhưng nếu để nó là bảng nghiệp vụ thì theo R-17, **mỗi lần cấp số sinh một bản ghi
  audit**. Chi phí không tương xứng: một bản ghi audit cho mỗi số chứng từ được cấp,
  trong khi chính chứng từ được tạo ra đã có bản ghi audit của nó và đã mang số đó.
  Tệ hơn, `INSERT` audit nằm trong đúng đoạn transaction đang giữ khóa hàng đếm, tức
  là nó kéo dài chính chỗ P-CONC yêu cầu ngắn nhất có thể.

Đây là câu hỏi mở, cần **một ADR riêng khi module đầu tiên cần cấp số chứng từ**. Quyết
sớm ở đây sẽ là quyết trong lúc chưa có ca dùng thật — đúng thứ ADR không nên làm. Ba
hướng đã thấy, để lại cho ADR đó cân nhắc: thêm một nhóm bảng thứ năm cho bảng hạ tầng
có trạng thái; đưa `document_counters` vào `system_tables` và chấp nhận mất truy vết;
hoặc giữ là bảng nghiệp vụ nhưng miễn audit cho riêng thao tác cấp số.

Cho tới khi ADR đó tồn tại, `document_counters` **là bảng nghiệp vụ** — vì nó không có
tên trong ba danh sách, và mặc định của một bảng không có tên trong danh sách nào là
không được miễn gì.

## Consequences

**Được:**

- Khách hàng thứ hai là việc cấu hình và nhập dữ liệu, không phải việc migrate schema
  trên hệ đang chạy. Khoản đắt nhất đã được trả trước bằng khoản rẻ nhất.
- Mọi người viết query đều quen mang `company_id` từ ngày đầu, nên không có giai đoạn
  "rà lại toàn bộ repository" — giai đoạn mà mọi lần bỏ sót đều là rò dữ liệu.
- Một database, một lần migration, một lịch backup. Vận hành đúng bằng vận hành một hệ
  single-tenant.
- Ba danh sách miễn trừ nằm ở tầng Decision nên mọi lần nới lỏng đều để lại dấu vết và
  đều có người duyệt.

**Mất:**

- Mỗi bảng thêm một cột, và mỗi index composite thêm một cột dẫn đầu. Chi phí lưu trữ
  và chi phí ghi đều tăng nhẹ, đổi lấy một khả năng chưa dùng tới.
- **Cách ly giữa các tenant nằm ở tầng ứng dụng, không ở tầng database.** Quên một
  `WHERE company_id = $n` là rò dữ liệu xuyên công ty, và không có gì ở tầng dưới đỡ
  được. R-06 tồn tại chính vì chỗ này, và nó nghiêm khắc chính vì chỗ này.
- Không backup/restore được cho riêng một khách hàng: phục hồi cho một công ty kéo
  theo toàn bộ database. Với khách hàng có yêu cầu tuân thủ về dữ liệu, đây có thể là
  lý do phải mở lại quyết định.
- Không cách ly được tài nguyên: một công ty chạy báo cáo nặng làm chậm mọi công ty
  khác.

**Nợ để lại:**

- **Row Level Security chưa bật.** Nó là lớp phòng thủ thứ hai cho đúng khoản "Mất"
  nghiêm trọng nhất ở trên, và việc bật nó cần một ADR riêng vì nó đổi cách mọi
  connection được thiết lập.
- Chưa có cách tách dữ liệu một tenant ra khỏi database chung khi khách hàng rời đi
  hoặc đòi hạ tầng riêng.
- Bốn danh sách ở trên sẽ dài ra, và mỗi lần dài ra là một ADR. Nếu nhịp đó trở nên
  phiền tới mức người ta tìm cách lách, đó là tín hiệu cần một ADR xem lại chính cơ
  chế này — không phải lý do để bỏ qua nó lặng lẽ.

**Constrains:** R-06

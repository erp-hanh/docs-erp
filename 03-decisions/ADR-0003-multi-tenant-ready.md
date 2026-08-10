# ADR-0003: Multi-tenant-ready bằng shared database và cột company_id

**Status:** Accepted (2026-08-10)

> **Sửa đổi (2026-08-10):** danh sách cụ thể các nhóm bảng ban đầu nằm trong chính ADR
> này; chúng được chuyển sang `04-conventions/C-DB-database.md` mục `C-DB-04` làm
> canonical registry. Lý do: ADR bất biến còn danh sách thì tiến hóa — thêm một bảng mà
> phải sửa ADR đã `Accepted` là tự mâu thuẫn với chính quy tắc ADR. Quyết định kiến
> trúc trong ADR này **không đổi**; chỉ chỗ giữ danh sách đổi.
>
> Cùng đợt này, `companies` chuyển từ `system_tables` sang nhóm mới `tenant_root`.
> Lý do: `system_tables` miễn cả audit lẫn soft delete, mà tạo hay sửa một công ty
> không để lại dấu vết là sai về nghiệp vụ.
>
> Ba gạch đầu dòng trỏ tới chỗ giữ danh sách cũng được sửa theo cho khỏi trỏ vào chỗ
> trống — một ở mục Phạm vi của `Decision`, hai ở `Consequences`. Nội dung quyết định
> và nội dung hệ quả không đổi, chỉ đổi chỗ được trỏ tới.
>
> Cùng đợt sửa số đếm ở mục "Bảng hạ tầng chưa phân loại": việc thêm `tenant_root` ở
> trên khiến "một nhóm bảng thứ năm" trở thành **thứ sáu**, và bốn danh sách hiện có
> (`system_tables`, `tenant_root`, `reference_tables`, `append_only_tables`) khiến
> `document_counters` giờ không có tên trong **bốn** danh sách, không phải ba. Đây là
> sửa lỗi mô tả số đếm cho khớp với đợt thêm `tenant_root`, không phải đổi quyết định.

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
- Các nhóm bảng miễn trừ và danh sách miễn quy tắc đặt tên là **current policy**, giữ ở
  `04-conventions/C-DB-database.md` mục `C-DB-04`, không liệt kê trong ADR này (xem mục
  dưới).

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

## Nơi giữ danh sách nhóm bảng

Danh sách cụ thể bảng nào thuộc nhóm nào là **current policy**, không phải quyết định
bất biến — nó dài ra theo thời gian khi hệ thống có thêm danh mục dùng chung hay bảng
chỉ ghi thêm. Vì vậy nó sống ở `04-conventions/C-DB-database.md` mục `C-DB-04` dưới
dạng registry máy đọc được, không nằm trong ADR này.

Phân vai: **ADR giữ *why*, `C-DB` giữ *current policy*.** Mỗi entry trong registry mang
một trường `adr` trỏ ngược về ADR biện minh cho phân loại của nó — nên thêm một bảng vẫn
đòi một ADR mới, chứ không phải một PR sửa Convention.

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
hướng đã thấy, để lại cho ADR đó cân nhắc: thêm một nhóm bảng thứ sáu cho bảng hạ tầng
có trạng thái; đưa `document_counters` vào `system_tables` và chấp nhận mất truy vết;
hoặc giữ là bảng nghiệp vụ nhưng miễn audit cho riêng thao tác cấp số.

Cho tới khi ADR đó tồn tại, `document_counters` **là bảng nghiệp vụ** — vì nó không có
tên trong bốn danh sách, và mặc định của một bảng không có tên trong danh sách nào là
không được miễn gì.

## Consequences

**Được:**

- Khách hàng thứ hai là việc cấu hình và nhập dữ liệu, không phải việc migrate schema
  trên hệ đang chạy. Khoản đắt nhất đã được trả trước bằng khoản rẻ nhất.
- Mọi người viết query đều quen mang `company_id` từ ngày đầu, nên không có giai đoạn
  "rà lại toàn bộ repository" — giai đoạn mà mọi lần bỏ sót đều là rò dữ liệu.
- Một database, một lần migration, một lịch backup. Vận hành đúng bằng vận hành một hệ
  single-tenant.
- Mỗi entry trong registry mang một trường `adr` bắt buộc, nên mọi lần nới lỏng đều để
  lại dấu vết và đều có người duyệt.

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
- Các danh sách trong registry sẽ dài ra, và mỗi lần dài ra là một ADR. Nếu nhịp đó
  trở nên phiền tới mức người ta tìm cách lách, đó là tín hiệu cần một ADR xem lại
  chính cơ chế này — không phải lý do để bỏ qua nó lặng lẽ.

**Constrains:** R-06

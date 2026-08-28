# ADR-0041: Đúng một đường ghi được neo vào `companies.id` từ path — đặt cờ người quản trị

**Status:** Accepted (2026-08-28)

## Context

[ADR-0040](ADR-0040-doc-cheo-phan-vung-neo-vao-companies.md), viết cùng ngày, cấp phép cho một
câu **đọc** nhận `company_id` từ path param khi giá trị đó là `companies.id` và actor giữ
`auth.company_read`. Vế 1 của nó viết thẳng: *"Chỉ `SELECT`. Không đường ghi nào được cấp bởi
ADR này."*

[ADR-0039](ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md) cùng ngày đặt ra khái niệm người quản
trị phân vùng và nói ai được đặt nó, nhưng **không** nói gì về hình dạng R-06 của đường ghi ấy.

Lỗ hổng lộ ra lúc thi công, không lộ ra lúc thiết kế: `PUT /companies/:id/admin` là một
`UPDATE user_companies SET is_admin = ... WHERE company_id = $1`, với `$1` đến từ path param.
Nó đúng hình dạng mà ADR-0040 vế 1 nói là chưa được cấp, và nó **không** bị `checkR06` bắt —
đúng như phần Nợ để lại của ADR-0040 đã đoán trước: *"một câu `UPDATE`/`DELETE` nhận
`company_id` từ path là thứ ADR này không cấp phép, và không có gì đang bắt nó."*

Đường vòng có thật và đã được cân nhắc: bắt quản trị hệ thống **chọn** phân vùng đó trước, khi
đó `actor.CompanyID` bằng đúng `:id` và R-06 thỏa mà không cần ngoại lệ nào. Vai trò dẫn xuất
`quan_tri_he_thong` giữ `auth.company_update` kể cả sau khi đã chọn ([ADR-0036](ADR-0036-quan-tri-he-thong-di-duoc-moi-phan-vung.md)
mục 3), nên đường đó chạy được. Cái giá của nó là đúng cái giá mà ADR-0040 đã loại cho vế đọc:
bấm "đổi người quản trị" trên một bảng liệt kê nhiều đơn vị thì phải rời bảng, đổi phân vùng,
quay lại, rồi đổi về.

## Decision

**Đúng một đường ghi được neo vào `companies.id` lấy từ path: đặt cờ người quản trị của một
phân vùng.**

1. **Chỉ một câu, và nó phải kể tên được:** `UPDATE user_companies SET is_admin = ...` của
   `UserCompanyRepository.DatNguoiQuanTri`. Không câu ghi nào khác được cấp bởi ADR này, và
   một câu ghi thứ hai muốn đi đường này thì cần một ADR mới — cấp phép theo **từng câu**, cố
   ý, vì một mệnh đề mở theo hình dạng sẽ nới ra dần mà không ai thấy điểm nào là quá xa.

2. **Cột ghi được duy nhất là `is_admin`.** Không cột nghiệp vụ nào khác của `user_companies`,
   và không bảng nào khác.

3. **`auth.company_update` là câu lệnh đầu tiên** của method service (R-15), rồi mới tới ba
   cửa kiểm của ADR-0039 mục 4.

4. Ba vế còn lại của ADR-0040 giữ nguyên hiệu lực: neo vào `companies.id` qua path param tên
   `:id`, DTO không mang field `company_id`, không qua query hay body.

**ADR-0040 không bị thay thế.** Nó vẫn đúng và vẫn là mệnh đề cho vế đọc. ADR này mở thêm một
cửa hẹp bên cạnh, và giữ nguyên câu "chỉ SELECT" của 0040 làm mặc định cho mọi câu chưa được
kể tên ở đây.

## Alternatives

**Bắt quản trị hệ thống chọn phân vùng trước rồi mới đổi người quản trị** — loại vì thao tác
này xuất phát từ một **bảng** liệt kê nhiều đơn vị, nơi giá trị của màn hình chính là nhìn
được nhiều phân vùng cùng lúc. Bắt rời bảng để sửa một dòng rồi quay lại là làm hỏng đúng thứ
màn hình đó sinh ra để làm. Đây là phương án **không tốn một dòng nào** và nó là đường lùi nếu
ADR này bị bỏ.

**Gộp vào ADR-0040 bằng cách sửa vế 1** — loại vì ADR đã `Accepted` là bất biến, và ở đây mệnh
đề bị sửa lại đúng là mệnh đề đắt nhất của ADR đó. Sửa tại chỗ sẽ xóa mất dấu vết rằng vế
"chỉ SELECT" từng là ranh giới, và người đọc sau sẽ không biết cửa ghi này được mở sau, có cân
nhắc riêng.

**Mở mệnh đề theo hình dạng thay vì theo từng câu** — ví dụ *"mọi câu ghi lên `user_companies`
neo vào `companies.id` đều được"* — loại vì `user_companies` là bảng giữ quan hệ ai-làm-ở-đâu,
tức đúng bảng mà một lỗi phân quyền sẽ đi qua. Một mệnh đề mở theo hình dạng cấp phép luôn cho
những câu chưa ai viết, và người viết câu thứ hai sẽ đọc nó như một lời cho phép sẵn.

## Consequences

**Được:** Màn "Quản trị phân vùng" đổi được người quản trị ngay tại bảng. Câu ghi duy nhất được
cấp có tên riêng trong văn bản, nên một PR thêm câu ghi thứ hai nhìn thấy được ngay là nó chưa
có chỗ đứng.

**Mất:** R-06 nay có **ba** hình dạng ngoại lệ — câu không có `company_id` (ADR-0034), câu đọc
neo vào `companies.id` (ADR-0040), và đúng một câu ghi (ADR này). Ba là nhiều, và con số đó tự
nó là tín hiệu: lần thứ tư nên là lúc đọc lại chính R-06 thay vì viết ngoại lệ thứ tư.

**Nợ để lại:**

- **Vẫn chưa có checker.** ADR-0040 đã ghi nợ này và ADR này làm nó nặng thêm: nay có một câu
  ghi hợp lệ, nên checker tương lai không thể là "cấm mọi `UPDATE` nhận `company_id` từ path"
  mà phải là một danh sách trắng theo tên hàm, giống map `hamMienCompanyID` mà ADR-0034 đang
  dùng. Việc đó chưa làm, và tới lúc đó ba ngoại lệ được giữ bằng review.
- Điều kiện đứng vững: `auth.company_update` còn chỉ cấp cho vai trò đứng ngoài mọi phân vùng.

**Constrains:** R-06

# ADR-0040: Một câu đọc được nhận `company_id` từ request khi giá trị đó là một `companies.id` đã đọc ra từ chính bảng `companies`

**Status:** Accepted (2026-08-28)

## Context

[R-06](../01-rules/RULES.md) viết bằng chữ: *"Giá trị truyền vào `company_id` phải lấy từ
`actor.CompanyID` — actor mà service nhận qua tham số thứ hai theo R-15 — cấm nhận từ request
của client."*

Mệnh đề đó đúng cho mọi màn hình nghiệp vụ. Nó **không nói gì** về một người đứng ngoài mọi
phân vùng nhìn vào. [ADR-0036](ADR-0036-quan-tri-he-thong-di-duoc-moi-phan-vung.md) đã chốt
rằng quản trị hệ thống là một người như vậy: họ chọn được mọi phân vùng, kể cả nơi họ không
có hàng trong `user_companies`. Trên màn "Phân vùng" họ đang xem một **danh sách** phân vùng,
và `actor.CompanyID` của họ là phân vùng họ tình cờ chọn lúc đăng nhập — không phải phân vùng
nào trong danh sách đang xem.

**Một câu đúng hình dạng đó đã chạy trên dev từ trước ADR này, và chưa văn bản nào phủ nó:**
`countActiveUsersOfCompanySQL` trong `modules/auth/internal/repository/company_repository.go`
đếm số người của **từng dòng** trong danh sách `GET /companies`, với `$1` lấy từ `rows[i].ID`
chứ không từ actor.

Bộ kiểm không bắt câu đó, và lý do đáng ghi lại: `checkR06` bắt bốn dấu hiệu — migration
thiếu cột, câu SQL thiếu `company_id` trong `WHERE`, DTO mang tag `company_id`, handler đọc
`c.Param("company_id")`. Câu này **có** `company_id` trong `WHERE`, và giá trị đi vào qua một
path param tên `:id`. Nó qua cả bốn vế. Thứ nó phá là **mệnh đề chữ**, không phải dấu hiệu
nào được mã hóa.

Nên khoảng cách giữa văn bản R-06 và checker của R-06 đang được dùng, bởi code đang chạy, mà
không ai khai. Ba việc sắp làm trên màn Phân vùng — đọc người quản trị, đếm người, liệt kê
người của một phân vùng — đều đi qua đúng khoảng cách đó. Đóng nó bằng một ADR rẻ hơn nhiều
so với để nó rộng thêm ba lần.

## Decision

**Một câu `SELECT` được phép nhận `company_id` từ request khi và chỉ khi giá trị đó là một
`companies.id` đã được đọc ra từ chính bảng `companies`, và actor giữ `auth.company_read`.**

Phạm vi, chặt đúng bằng bốn vế:

1. **Chỉ `SELECT`.** Không đường ghi nào được cấp bởi ADR này. Một `UPDATE` neo vào
   `companies.id` là một quyết định khác và cần một ADR khác.

2. **Neo vào `companies.id`, đi qua path param của một route dưới `/companies/:id`.** Không
   qua query string, không qua body, và DTO không mang field tên `company_id` — ba dấu hiệu
   vi phạm mà R-06 viết ra bằng chữ và checker bắt được vẫn giữ nguyên hiệu lực.
   [ADR-0034](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md) mục 4 đã ghi chính cái bẫy này
   là lý do `select-company` nhận `company_code` chứ không `company_id`.

3. **`auth.company_read` là câu lệnh đầu tiên của method service** (R-15), và phép kiểm phân
   vùng có tồn tại đứng **sau** nó. Quyền đó hôm nay chỉ cấp cho vai trò dẫn xuất
   `quan_tri_he_thong` (`cmd/internal/vaitro`), tức chỉ người đứng ngoài mọi phân vùng đi
   được đường này.

4. **`countActiveUsersOfCompanySQL` đang chạy được hợp thức hóa bởi ADR này**, không phải bởi
   một ngoại lệ ngầm.

**Không sửa [ADR-0034](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md).** Danh sách miễn trừ
của ADR đó dành cho câu **không có** `company_id` trong `WHERE` — `ByEmailToanHe`,
`ByPhoneToanHe`, `PhanVungTheoUser` và hai hàng thêm sau. Câu của ADR này thì **có**, chỉ
khác nguồn giá trị. Trộn hai hình dạng vào một danh sách làm chính danh sách đó mất nghĩa:
người đọc nó sẽ không còn biết mỗi hàng đang được miễn khỏi điều gì.

## Alternatives

**Thêm vào danh sách miễn R-06 của ADR-0034** — loại vì lý do vừa nêu ở mục cuối phần
Decision. Danh sách đó là danh sách các câu **không lọc theo phân vùng nào cả**, và mỗi hàng
của nó phải trả lời được câu "vì sao câu này không cần `company_id`". Câu của ADR này không
trả lời được câu đó, vì nó có `company_id`.

**`GET /users?company_id=<id>`** — loại vì nó phá đúng hai dấu hiệu vi phạm mà R-06 đã mã hóa
thành checker: struct query mang `form:"company_id"`, và `c.Query("company_id")` trong
handler. Hợp thức hóa nó nghĩa là gỡ hai vế của `checkR06`, tức viết lại R-06 chứ không phải
mở một ngoại lệ cho nó. Đường qua `/companies/:id/...` cho ra cùng dữ liệu mà không đụng vế
nào.

**Bắt quản trị hệ thống đổi sang phân vùng đó rồi dùng endpoint sẵn có** — loại vì cái giá
nằm ở chỗ khó thấy: mỗi lần xem một đơn vị phải đổi phân vùng, xem, rồi đổi về, và trong lúc
đó mọi màn đang mở nói về một đơn vị khác. ADR-0036 phần Nợ để lại đã ghi rằng giao diện chưa
nói ra được sự khác biệt giữa "đang đứng trong phân vùng nào" — thêm một luồng bắt người dùng
đổi qua đổi lại là làm nợ đó nặng lên. Phương án này **không tốn một dòng backend nào** và nó
vẫn là đường lùi nếu ADR này bị bỏ; ghi ra đây để lần sau khỏi phải tìm lại.

## Consequences

**Được:** Màn Phân vùng đọc được số liệu thật của từng đơn vị mà không bắt người dùng rời chỗ
đang đứng. Câu `countActiveUsersOfCompanySQL` đang chạy có chỗ đứng bằng văn bản thay vì tồn
tại nhờ không ai nhìn. Ba endpoint sắp viết đi theo một hình dạng đã được đặt tên, thay vì mỗi
cái tự bịa một đường.

**Mất:** R-06 nay có **hai** hình dạng ngoại lệ phải nhớ thay vì một — câu không có
`company_id` (ADR-0034) và câu có `company_id` không đến từ actor (ADR này) — và hai hình
dạng đó dễ lẫn nhau đúng ở chỗ chúng cùng được gọi là "ngoại lệ R-06". Người review một PR mới
phải hỏi thêm một câu.

**Nợ để lại:**

- **Chưa có checker tự động cho ADR này.** Bốn vế ở phần Decision hôm nay được giữ bằng
  review, và đó là trạng thái yếu hơn hẳn ADR-0034 — ngoại lệ của ADR đó có một map cứng
  trong `arch/` cộng một test canh "chỉ service nào được gọi". Vế dễ mã hóa nhất và cũng đáng
  canh nhất là vế 1: một câu `UPDATE`/`DELETE` nhận `company_id` từ path là thứ ADR này
  **không** cấp phép, và không có gì đang bắt nó.
- Điều kiện để quyết định này đứng vững: `auth.company_read` còn chỉ cấp cho vai trò đứng
  ngoài mọi phân vùng. Ngày một vai trò trong phân vùng được cấp mã đó, vế 3 hết tác dụng và
  ADR này phải được đọc lại.

**Constrains:** R-06

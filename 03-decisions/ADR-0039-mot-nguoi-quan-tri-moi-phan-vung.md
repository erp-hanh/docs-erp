# ADR-0039: Mỗi phân vùng có đúng một người quản trị, và ràng buộc database giữ điều đó

**Status:** Accepted (2026-08-28)

## Context

Spec `99-meta/my-specs/2026-08-24-module-quan-tri-hai-man-spec.md` mục 10 (đính chính
2026-08-25) viết *"mỗi phân vùng đúng một người quản trị"*, và mặt "Quản trị" của màn Phân
vùng được dựng theo đúng mệnh đề đó: một dòng là một phân vùng, có cột "Người quản trị", và
một màn riêng để **đổi** người quản trị.

**Mệnh đề đó không được giữ ở đâu trong hệ.** Đo ngày 2026-08-28: không có cột nào, không có
bảng nối nào, không có unique index nào nói một phân vùng có bao nhiêu người quản trị.

Định nghĩa vận hành duy nhất đang chạy đến từ [ADR-0037](ADR-0037-quan-tri-he-thong-chi-bo-nhiem-quan-tri.md)
mục 1: *vai trò quản trị phân hệ là vai trò có tập quyền chứa ít nhất một `<module>.role_assign`*.
Đó là một phép thử trên **vai trò**, không phải một phép đếm trên **người**. Hai người trong
cùng một phân vùng cùng mang một vai trò như vậy là trạng thái hoàn toàn hợp lệ, và code hiện
tại giả định đúng như thế: `UserCompanyRepository.DemNguoiGiuQuyen` trả về **hai** con số và
phân biệt tường minh ca "còn người quản trị khác" với ca "vốn không có ai".

Hệ quả nhìn thấy được trên màn hình: cột "Người quản trị" chạy dữ liệu giả
(`frontend-erp/src/modules/company/components/quan-tri-phan-vung-mau.ts`, ba dòng cứng), và
màn hình tự khai điều đó bằng hai dải cảnh báo *"Danh sách phân vùng là thật, cột người quản
trị là dữ liệu mẫu"*. Nút Lưu của màn đổi người quản trị bị khóa cứng kèm lý do *"Chưa có
`PUT /companies/:id/admin`"*.

Nên khoảng trống ở đây không phải một endpoint quên viết. Endpoint đó **không viết được** khi
chưa ai trả lời câu "người quản trị của một phân vùng là ai" bằng một thứ có thể đọc ra được.

## Decision

**Mỗi phân vùng có đúng một người quản trị, người đó là một thành viên của chính phân vùng
đó, và ràng buộc database — không phải một quy tắc phải nhớ — giữ vế "nhiều nhất một".**

1. Cột `user_companies.is_admin BOOLEAN NOT NULL DEFAULT false`, kèm partial unique index
   `uq_user_companies_admin ON user_companies(company_id) WHERE is_admin AND deleted_at IS NULL`.

2. **"Nhiều nhất một" do database giữ.** Hai người quản trị trong một phân vùng là một lệnh
   ghi **không chạy được**, không phải một lệnh ghi bị chặn ở tầng trên. Đó là điểm khác biệt
   duy nhất đáng kể của quyết định này: một luật ở tầng service chỉ giữ được những đường ghi
   đã biết, còn ràng buộc giữ được cả đường ghi thứ hai mà người viết nó không đọc luật.

3. **"Ít nhất một" do service giữ, ở đúng hai cửa:** tạo phân vùng bắt buộc kèm người quản trị
   đầu tiên trong cùng transaction; và gỡ người quản trị — gỡ khỏi phân vùng, hoặc hạ cờ — bị
   từ chối khi không có người thay.

4. **`is_admin` không tự cấp quyền gì.** Nó nói ai chịu trách nhiệm về một đơn vị, còn quyền
   vẫn đến từ vai trò ([ADR-0038](ADR-0038-admin-phan-vung-dat-ra-vai-tro.md)). Service kiểm
   người được đặt làm quản trị **đang giữ** `auth.role_assign`; một người quản trị không bổ
   nhiệm được ai là một đầu mối không làm được việc của mình.

5. **Không áp ngược lên phân vùng đã có.** Migration chỉ đánh dấu khi phân vùng có **đúng
   một** người giữ `auth.role_assign`. Phân vùng đang có 0 người hoặc 2+ người thì để trống,
   và màn hình nói ra bằng chữ "Chưa có người quản trị" kèm đường đặt. Một migration tự chọn
   hộ một trong hai người là một quyết định nghiệp vụ giấu trong một file SQL, và không ai rà
   lại được nó sau khi nó chạy.

## Alternatives

**Cột `companies.admin_user_id`** — loại vì nó cho phép trỏ tới một người không làm việc ở
phân vùng đó. Khóa ngoại chỉ bảo đảm người ấy tồn tại, không bảo đảm người ấy là thành viên;
muốn chặn thì phải thêm một phép kiểm chéo bảng ở tầng service, tức quay lại đúng loại ràng
buộc mà quyết định này chọn để không dùng. Cờ trên `user_companies` bảo đảm cả hai điều bằng
một chỗ: dòng mang cờ **là** dòng nói người đó làm ở đây.

**Suy ra từ tập quyền, không lưu gì** — loại vì đó chính là trạng thái hôm nay, và nó không
ép được gì. Hai người cùng giữ `auth.role_assign` là hợp lệ, nên câu hỏi "người quản trị của
phân vùng này là ai" không có câu trả lời đơn trị, và màn "Đổi người quản trị" không có nghĩa
để bám vào. Phương án này rẻ nhất và nó là phương án đúng **nếu** người quyết chấp nhận cột
đó là một danh sách; ngày 2026-08-28 người quyết đã chọn ngược lại.

**Bỏ mặt "Quản trị", để việc cấp quyền ở màn Phân quyền** — loại vì nó bỏ mất thứ mà mặt đó
sinh ra để trả lời: nhìn một bảng là biết đơn vị nào đang không có ai chịu trách nhiệm. Màn
Phân quyền trả lời câu hỏi ngược lại — một người có những quyền gì — và không có chỗ nào bày
ra một phân vùng bị bỏ rơi.

## Consequences

**Được:** Câu "ai chịu trách nhiệm về đơn vị này" có đúng một câu trả lời, đọc được bằng một
truy vấn. Mặt "Quản trị" chạy số liệu thật và bỏ được ba dòng dữ liệu giả cùng hai dải cảnh
báo. Trạng thái "hai người quản trị" không cần checker nào canh, vì nó không tồn tại được.

**Mất:** Một phân vùng có thể ở trạng thái **chưa có người quản trị** trong một khoảng thời
gian — và đó là trạng thái thật của dữ liệu cũ chứ không phải lỗi, nên màn hình phải nói ra
được nó thay vì hiển thị một ô trống. Tạo phân vùng nay tốn thêm một thao tác. Đổi người quản
trị trở thành một đường ghi phải review, thay vì một hệ quả tự nhiên của việc cấp vai trò.

**Nợ để lại:**

- **Chưa quyết điều gì xảy ra khi người quản trị duy nhất bị vô hiệu hóa** (`users.is_active
  = false`) thay vì bị gỡ. Cửa chặn ở mục 3 nói về việc gỡ, không nói về việc khóa tài khoản.
  Hôm nay hai đường đó tách nhau, và đường thứ hai đi lọt.
- **Chưa quyết bao lâu thì phân vùng cũ để trống là quá lâu.** Mục 5 cố ý không đoán, nhưng
  không đoán mãi thì cột đó thành một ô luôn trống mà không ai thấy phiền.
- Điều kiện để quyết định này đứng vững: `auth.role_assign` còn là mã mốc đúng của "người bổ
  nhiệm được người khác". Ngày ADR-0037 mục 1 đổi phép thử đó, mục 4 ở đây phải đổi theo.

# ADR-0002: Bốn repo git độc lập — docs-erp, backend, frontend, infra

**Status:** Accepted (2026-08-10)

## Context

Dự án gồm bốn thứ có vòng đời khác nhau: tài liệu kiến trúc, backend Go, frontend
React/TypeScript, và hạ tầng (IaC, script triển khai, cấu hình môi trường). Ở thời
điểm quyết, cả bốn còn trống hoặc gần trống — đây là lúc rẻ nhất để chọn, và cũng là
lúc duy nhất chọn được mà không phải viết lại lịch sử git.

Ba ràng buộc có thật lúc đó:

- Đội nhỏ, không có ai chuyên lo build system. Mọi tooling phải là thứ mặc định của
  từng hệ sinh thái: `go build`, `npm`, không có lớp điều phối riêng ở giữa.
- Ba stack không cùng nhịp phát hành: backend deploy theo tuần, frontend có thể vài
  lần một ngày, còn hạ tầng thì thỉnh thoảng và luôn cần người duyệt.
- Quyền truy cập khác nhau. Repo `infra` chứa cấu trúc môi trường sản xuất và tên các
  secret; nó không nên mở cho cùng một nhóm người như repo frontend.

Và ràng buộc thứ tư, riêng cho tài liệu: bộ Rule trong `docs-erp` ràng buộc **cả ba**
repo code, không phải chỉ backend. R-19 nói về frontend, R-07 nói về migration, quy
ước môi trường nói về infra.

## Decision

Bốn repo git độc lập — `docs-erp`, `backend`, `frontend`, `infra` — mỗi repo một vòng
đời, một quy trình review, một bộ quyền riêng.

`docs-erp` là repo tài liệu duy nhất ở tầng dùng chung; tài liệu của từng module nằm
trong repo code của module đó theo [ADR-0005](ADR-0005-documentation-follows-code.md).

## Alternatives

**Monorepo cho cả bốn** — loại. Monorepo trả lời tốt bài toán "một thay đổi phải đi
qua nhiều thành phần cùng lúc", nhưng cái giá của nó là tooling: build graph để không
phải chạy lại toàn bộ CI cho một sửa đổi ở README, quy tắc code owner để review không
loạn, và một cách phân vùng pipeline theo thư mục. Ba thứ đó cần một người chăm sóc
thường xuyên, mà đội hiện tại không có người đó. Không có chúng thì monorepo chỉ còn
lại phần dở: mọi PR chạy mọi thứ, và quyền truy cập là tất-cả-hoặc-không.

**Hai repo: một cho code, một cho docs** — loại. Nó gộp backend, frontend và infra vào
chung một chỗ, tức là gộp đúng ba thứ khác nhau nhất về nhịp phát hành và về quyền.

**Đặt `docs-erp` bên trong repo backend** — loại, và đây là phương án được tranh luận
nhiều nhất vì backend là nơi phần lớn Rule được kiểm. Loại vì frontend và infra cũng
chịu ràng buộc của **cùng một bộ rule**; để docs trong backend là đặt một repo lên
trên hai repo kia. Hệ quả rất cụ thể: một thay đổi Rule ảnh hưởng frontend sẽ phải mở
PR ở repo backend, và người review sẽ là người backend. Tài liệu dùng chung phải đứng
ngang hàng với mọi repo dùng nó, không đứng bên trong một repo trong số đó.

## Consequences

**Được:**

- Mỗi repo có vòng đời, CI và quyền riêng. Sửa một dòng trong `docs-erp` không kích
  hoạt pipeline của backend.
- `docs-erp` đứng ngang hàng với cả ba repo code, nên không repo nào là "chủ" của bộ
  Rule. Điều này giữ được thẩm quyền của tầng Rule khi có tranh chấp.
- Lịch sử git của mỗi repo đọc được: log của `docs-erp` là lịch sử quyết định kiến
  trúc, không lẫn với hàng nghìn commit code.

**Mất:**

- **Không có commit nguyên tử xuyên repo.** Đổi một hợp đồng API là hai PR ở hai repo,
  và giữa hai lần merge có một khoảng thời gian hai bên lệch nhau. Phải xử lý bằng
  versioning và thay đổi tương thích ngược (R-13), không phải bằng "merge cùng lúc".
- Không refactor xuyên repo bằng một lần đổi tên. Không có công cụ nào thấy cả hai bên.
- Người mới phải clone bốn repo và biết thứ nào ở đâu trước khi làm được việc gì.

**Nợ để lại:**

- **Docs và code có thể lệch phiên bản** — đây là khoản nợ chính của quyết định này.
  Giảm nhẹ bằng một `CLAUDE.md` ở gốc mỗi repo code, trỏ về `docs-erp` và nêu rõ bộ
  Rule nào áp lên repo đó. Giảm nhẹ, không phải xóa bỏ: không có gì bảo đảm bản
  `docs-erp` mà một PR đang tham chiếu là bản mới nhất.
- Chưa có cơ chế kiểm tự động rằng ba repo code đang tuân bộ Rule của bản `docs-erp`
  hiện hành. Việc đưa `tools/check-ids.ps1` và các hard check vào CI của từng repo
  còn để mở.
- Chưa chốt cách đánh dấu một phiên bản `docs-erp` (tag? ngày?) để một repo code trỏ
  tới được bản cụ thể thay vì trỏ tới nhánh mặc định.

**Constrains:** —

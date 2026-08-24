# ADR-0030: Phạm vi trả lời "của ai", vòng đời trả lời "còn sống không" — danh sách id của Resolve gồm cả bản ghi đã xoá mềm

**Status:** Accepted (2026-08-24)

## Context

Ngày 2026-08-24, khối 7 dựng đường đọc sổ chuyển động. Một vòng soi ngược trên mã đã merge
tìm ra rằng cùng một câu hỏi — *"các dòng sổ của một kho đã xoá mềm có còn thấy được không"* —
được hệ trả lời **hai kiểu ngược nhau, tuỳ mức quyền của người hỏi**.

Đo được bằng số, trên cùng một database, cùng một kho B vừa bị xoá mềm
(`backend-erp/modules/inventory/internal/repository/stock_movement_repository_test.go`):

| Người hỏi | Số dòng thấy được |
|---|---|
| Actor **toàn phạm vi** (`inventory.warehouse_scope_all`) | **0** |
| Actor **được cấp phạm vi** đúng kho B | **2** |

Tức **càng nhiều quyền càng thấy ít**.

### Nó không phải một lỗi cài đặt

Cả hai vế đều làm đúng thứ đã được quyết, chỉ là chưa ai đặt hai quyết định đó cạnh nhau.

[ADR-0020](ADR-0020-data-scope-theo-ban-ghi.md) mục 5 chốt: *"Resolver luôn trả về một danh
sách id cụ thể, kể cả ca toàn phạm vi — lúc đó danh sách là **toàn bộ id đang sống** của loại
đó trong phân vùng."* Chữ "đang sống" là chỗ nhánh `toanPhamVi` lấy `WHERE deleted_at IS NULL`.

Cùng ADR mục 2 chốt: *"`scope_id` không mang khóa ngoại."* Nên hàng cấp phạm vi **sống sót**
qua việc xoá mềm bản ghi nó trỏ tới, và nhánh `theoCapPhat` không có gì để lọc theo vòng đời —
câu đọc của nó không chạm bảng `warehouses` một dòng nào.

Hai câu đó viết cho hai mục đích khác nhau, cách nhau vài mục trong cùng một tài liệu, và
chúng cho hai câu trả lời ngược nhau ở đúng ca này.

### Vì sao chuyện này chỉ lộ ra bây giờ

Trước khối 7, đường đọc duy nhất chịu phạm vi là tồn kho — mà tồn của một kho đã đóng thì hầu
như không ai hỏi. Sổ chuyển động là đường đọc **lịch sử** đầu tiên, và lịch sử là thứ người ta
hỏi lại **sau khi** mọi thứ đã đóng.

Một bài test còn đang xanh để bảo chứng cho hành vi sai: nó chốt phạm vi **trước** lệnh xoá
mềm, tức dựng một trạng thái mà đường HTTP không tạo ra được.

### Ba ràng buộc thu hẹp không gian lời giải

- ADR-0020 mục 5 muốn **đúng một hình dạng câu SQL**, không nhánh `if toàn bộ` để ai đó quên.
  Một lời giải thêm biến thể "danh sách cho đường đọc lịch sử" là thêm lại đúng cái nhánh ấy.
- ADR-0020 mục 2 đã từ chối khoá ngoại trên `scope_id`, nên **không có** đường bắt hai nhánh
  đồng ý bằng một ràng buộc ở tầng database.
- `shared/scope.Nguon` hôm nay có đúng một method: `IDsTrongPhanVung(ctx, companyID, loai)`.
  Mọi lời giải đều phải đi qua đó.

## Decision

**`Nguon.IDsTrongPhanVung` trả về mọi id của loại đó trong phân vùng, KỂ CẢ bản ghi đã xoá
mềm. Phạm vi trả lời "của ai"; vòng đời trả lời "còn sống không"; và hai câu hỏi đó được trả
lời ở hai chỗ khác nhau.**

Sửa mục 5 của ADR-0020: bỏ chữ **"đang sống"**.

Bốn điều làm rõ:

**1. Câu hỏi vòng đời được trả lời ở bảng sở hữu bản ghi, không ở danh sách phạm vi.** Câu
`ListWarehouses` vẫn có `deleted_at IS NULL` trên `warehouses`; câu `ListMovements` vẫn có
`deleted_at IS NULL` trên `stock_movements`. Không gì rò rỉ: một kho đã xoá mềm vẫn không hiện
trong danh mục kho, vì danh mục kho đọc bảng kho.

Cái đổi là những gì **treo vào** kho đó và có vòng đời riêng của mình — trước hết là các dòng
sổ. Chúng có `deleted_at` của chính chúng, và nó vẫn `NULL`.

**2. Vẫn đúng MỘT hình dạng câu SQL.** Không thêm biến thể `Nguon`, không thêm cờ, không thêm
nhánh ở repository. Đây là lý do lời giải này được chọn thay vì "một `Nguon` thứ hai cho đường
đọc lịch sử": lời giải kia đúng về nghĩa nhưng phá đúng cái mà mục 5 của ADR-0020 dựng ra để
bảo vệ.

**3. Thu hồi quyền vẫn hiệu lực ngay.** Gỡ hàng cấp phạm vi thì người đó mất luôn cả lịch sử
của kho ấy — nhánh `theoCapPhat` đọc hàng cấp phát, không đọc bảng kho. Quyết định này **không**
làm yếu đường thu hồi; nó chỉ thôi lấy việc đóng cửa một cái kho làm một cách thu hồi ngầm.

**4. Hai nhánh của `Resolve` từ nay BẮT BUỘC trả lời giống nhau cho cùng một câu hỏi**, và
điều đó phải có test canh. Bất đối xứng giữa hai nhánh là một lớp lỗi im lặng: nó không làm
đỏ gì, nó chỉ làm hai người thấy hai sự thật.

### Vì sao là hướng này chứ không hướng ngược lại

Hướng ngược — bắt cả hai nhánh **cùng giấu** lịch sử của kho đã đóng — cũng chữa được bất đối
xứng, và nó rẻ hơn (thêm một phép lọc vào câu `theoCapPhat`). Bị loại vì ba lý do, xếp theo
sức nặng:

**Chính bất đối xứng là bằng chứng về ý định.** Không ai thiết kế "càng nhiều quyền càng thấy
ít". Nhánh `theoCapPhat` giữ lịch sử vì đó là điều tự nhiên xảy ra khi không ai cố tình xoá
nó; nhánh `toanPhamVi` giấu nó vì chữ "đang sống" ở mục 5 được viết cho một câu hỏi khác — *"có
những kho nào"* — rồi bị dùng lại cho câu *"người này được thấy gì"*.

**Đóng một cái kho không làm hàng đã đi qua nó chưa từng đi qua.** Sổ chuyển động là bản ghi
việc đã xảy ra; hệ này đã chốt không có `PATCH` cho nó và đường chữa một dòng sai là ghi một
dòng ngược lại. Để một thao tác trên **danh mục** xoá được cả một quãng lịch sử là mở một
đường sửa sổ mà không ADR nào cấp.

**Người cần lịch sử đó nhất là người đã đóng kho.** "Kho đó lúc đóng còn những gì", "ba tháng
qua ai đưa hàng vào đó" — cả hai chỉ được hỏi **sau** khi kho đóng.

## Consequences

**Phải sửa:** `shared/scope` — bỏ `deleted_at IS NULL` khỏi câu của nhánh `toanPhamVi`; hoặc
chính xác hơn, khỏi cài đặt `Nguon` của module sở hữu (hôm nay là
`inventory/internal/repository/warehouse_scope_source.go`). Kèm test chốt rằng hai nhánh cho
cùng một câu trả lời trên cùng một kho đã xoá mềm.

**Phải sửa theo:** hai bài test tách ra ngày 2026-08-24
(`TestListMovementsKhoDaXoaMemBienMatVoiActorToanPhamVi` và `...VanHienVoiActorDuocCapPhat`).
Bài thứ nhất đang chốt đúng hành vi mà ADR này bỏ; nó phải đổi kỳ vọng và đổi tên.

**Đổi hành vi nhìn thấy được:** một actor toàn phạm vi từ nay **thấy** các dòng sổ của kho đã
xoá mềm, với `warehouse_code` và `warehouse_name` là **chuỗi rỗng** (LEFT JOIN đã có sẵn ở
`stock_movement_repository.go` cho đúng ca này). Màn hình phải hiện một dòng chữ chứ không một
ô trống — một ô trống đọc y hệt "chưa điền", trong khi `warehouse_id` là `NOT NULL`.

**Không đổi:** danh mục kho, danh mục vật tư, và mọi câu hỏi *"có những kho nào"* — chúng đọc
bảng của chính mình và vẫn lọc `deleted_at IS NULL`.

**Cần xem lại khi có loại phạm vi thứ hai.** Hôm nay chỉ có một loại là kho. Loại thứ hai có
thể là một tài nguyên mà "đã xoá mềm" nghĩa khác hẳn, và lúc đó phải hỏi lại xem quy tắc này
còn đúng không — chứ đừng suy ra rằng nó đúng vì nó đã đúng với kho.

**Điều kiện tự huỷ:** ADR này giả định mọi thứ chịu phạm vi đều có `deleted_at` của chính nó ở
bảng sở hữu. Ngày nào có một tài nguyên chịu phạm vi mà **không** xoá mềm được — hoặc mà việc
xoá mềm mang nghĩa "cấm truy cập" chứ không phải "đã đóng" — thì quyết định này phải mở lại.

**Constrains:** R-18

# Bàn giao: khối 6 và khối 7, phiên 2026-08-24

Đích: một thủ kho thật ghi chuyển động thật trên `http://103.179.172.110/`.
Kế hoạch gốc và bảng 12 khối: `2026-08-21-thu-tu-dua-kho-vao-su-dung.md`.
Bàn giao liền trước: `2026-08-23-ban-giao-o-tim-danh-muc-frontend.md`.

## Chốt cuối phiên

`v0.1.0-rc.34` đang chạy trên dev: `infra 0ef1f72` · `backend 0db44f9` · `frontend 8cfba14`.

**Khối 6 xong** - `infra-erp/scripts/nap-ton-dau-ky.ps1`. Nghiệm thu trên một phân vùng sạch:
nạp 3 dòng `201`, chạy lại cho `movement_id` **trùng khít**, `-ChiKiem` báo `0 chỗ lệch`.

**Khối 7 xong cả hai đầu.** Backend: năm bộ lọc và bốn field tên trên `GET /stock-movements`.
Frontend: `/chuyen-dong` và `/chuyen-dong/:id`, cộng ba đường đi chữa ba ngõ cụt.

Bảng 12 khối đã được sửa cho khớp, gồm cả hai dòng nói sai từ trước (khối 5 và khối 8).

## Việc còn treo, cần người quyết

### 1. Xoá mềm một cái kho nghĩa là gì với sổ đã ghi - CẦN MỘT ADR

Đây là thứ đáng làm tiếp nhất, và nó là một câu hỏi thiết kế chứ không phải một lỗi để vá.

Hôm nay hệ trả lời **hai kiểu tuỳ mức quyền**, đo được bằng số ở
`stock_movement_repository_test.go`:

- Actor **toàn phạm vi**: các dòng sổ của kho đã xoá mềm **biến mất** (0 dòng). Mệnh đề phạm
  vi `sm.warehouse_id = ANY($2)` chặn trước, vì mảng id chỉ gồm kho còn sống.
- Actor **được cấp phạm vi theo kho**: **vẫn thấy** (2 dòng, tên rỗng). Câu
  `selectScopeIDsTheoActorSQL` không kiểm `warehouses.deleted_at`.

Tức **càng nhiều quyền càng thấy ít**. Chi tiết ở mục 6.4 của
`backend-erp/docs/superpowers/specs/2026-08-24-so-chuyen-dong-tra-duoc-design.md`.

**Đừng chữa bằng cách sửa `deleted_at` ở một trong hai câu phạm vi.** Sửa ở đó là đổi ngữ
nghĩa cho **mọi** tài nguyên chịu phạm vi, không riêng sổ chuyển động.

### 2. Rác thử trên dev

Phân vùng `DEFAULT` còn: vật tư `SO-VT-001` và **hai dòng sổ** (`nhap 100`, `xuat -8`, ghi chú
`kiem man so`). Cố ý để lại để có gì mà nhìn khi mở `/chuyen-dong`. Xoá thì xoá dòng sổ trước.

Bốn hàng tombstone của đợt dọn trước vẫn nằm đó (3 dòng sổ + vật tư `DEMO-0250`) - vô hại, và
mã `DEMO-0250` vẫn chèn lại được vì chỉ mục duy nhất có `WHERE deleted_at IS NULL`.

Phân vùng `3604117302-2026` sạch: 0 kho, 0 vật tư, 0 dòng sổ. Tài khoản `nap-thu@erp.test`
(mật khẩu `QaPhamVi!2026`) còn, dùng lại được cho lần thử nạp sau.

## Bốn cái bẫy của phiên này

### 1. Soi trước KHÔNG thay được chạy thật, và tỉ lệ không nhỏ

Ba subagent soi kế hoạch khối 6 trước khi gõ mã bắt **20 lỗi**, năm cái nghiêm trọng. Thi công
bắt thêm **19 lỗi nữa** mà soi không thấy. Phần lớn là bẫy chỉ lộ khi chạy thật:

- `@($x)` với `List[object]` **ném** `ArgumentException` trên PS 5.1, kể cả khi list rỗng, và
  **chỉ** với `List[object]`; `List[string]` trôi qua.
- `StreamWriter` giải đường dẫn tương đối theo `[Environment]::CurrentDirectory` của .NET, thứ
  **không** đi theo `cd` của PowerShell.
- `Invoke-RestMethod` ở PS 5.1 **đã đọc cạn** response stream trước khi ném, nên
  `GetResponseStream().ReadToEnd()` trả chuỗi rỗng mà không báo gì. Thân lỗi nằm ở
  `$_.ErrorDetails.Message`.
- `"$Path?abc"` parse thành biến `$Path?abc` - dấu `?` hợp lệ trong tên biến. Không warning.

**Bài học dùng được:** ba lần trong phiên này, kế hoạch **tự mâu thuẫn với ràng buộc của chính
nó** - tôi bắt bật `StrictMode 2` rồi viết mã vi phạm nó ở ba chỗ, và đặt một mốc ví dụ mà
guard của chính tôi chặn. Soi không bắt được loại đó; chỉ chạy mới bắt.

### 2. Trình duyệt bắt được thứ 1000 bài test không bắt

Màn sổ trên dev hiện `8/20/2026, 9:00:00 AM` - định dạng Mỹ. `toLocaleString()` trần lấy locale
của **trình duyệt**, nên cùng một màn hình hiện khác nhau trên hai máy, và **không bài test nào
bắt được** vì jsdom chạy dưới một locale cố định.

Nguy hiểm hơn chuyện xấu xí: `5/6` là ngày 5 tháng 6 hay ngày 6 tháng 5, tuỳ locale.

Đã chữa bằng `frontend-erp/src/shared/dinh-dang/thoi-diem.ts`. Cùng họ với bài học
`crypto.randomUUID` của phiên trước: **cả hai chỉ lộ ra khi mở trình duyệt thật trỏ vào dev.**
Đó là lý do bước "đi thử bằng tay sau khi deploy" không thay được bằng một lần `curl /health`.

### 3. Cây làm việc dùng chung - commit đi nhờ cú push của phiên khác

`backend-erp` được hai phiên Claude cùng dùng, và `main` được checkout ở đúng một cây. Tôi
commit thẳng vào `main` cục bộ rồi để đấy; phiên kia cắt nhánh, merge, push - và commit khối 7
của tôi lên remote **chưa qua vòng soi nào**.

Không hỏng gì (CI xanh, và tôi đã soi ngược lại sau), nhưng đường đi thì sai.

**Luật rút ra: ở repo này làm trên nhánh riêng, đừng commit vào `main` cục bộ rồi để đó.**

Và soi ngược lại tìm ra thứ CI không nói được: **ba đoạn ghi chú khẳng định sai về chính hành
vi của chúng, cộng một bài test đang xanh để bảo chứng cho điều sai** - nó chốt phạm vi
**trước** lệnh xoá mềm, tức dựng một trạng thái mà đường HTTP không tạo ra được.

### 4. R-09 thắng spec, và index sinh ra có thể là index chết

Spec khối 7 viết "`kind` không cần index" theo đúng ghi chú của migration 000017. Nhưng R-09
đòi **mọi** cột trong `WHERE` của repository phải ở vị trí 1 hoặc 2 của một index nào đó, không
bỏ phiếu theo độ chọn lọc. Rule thắng spec - đã thêm migration `000027`.

Nhưng vòng soi ngược chỉ ra: số đo của chính đợt này cho thấy planner **không dùng** index đó
(mệnh đề `$5 = '' OR sm.kind = $5` không gập được, và `ORDER BY occurred_at ... LIMIT` neo câu
vào index khác). Tức một khoản thu vĩnh viễn trên mọi `INSERT` của một bảng phình theo thời
gian, để làm xanh một checker. Đề xuất chưa làm: đổi thành
`(company_id, kind, occurred_at)` - vẫn thoả R-09, mà phục vụ được câu thật.

## Chỗ hở đáng làm tiếp, theo thứ tự

1. **ADR cho câu hỏi ở mục "việc còn treo" số 1.** Nó chặn việc chữa một bug thật.
2. **Khối 10** - luật chặn sửa mã và xoá vật tư đã dùng. Spec đã có ở
   `backend-erp/.../2026-08-21-thu-kho-quan-ly-danh-muc-design.md`.
3. **Khối 9** - thi công ADR-0023. Chỉ có ADR, chưa có spec thi công.
4. **Endpoint sửa tập quyền của một vai trò.** Vẫn chưa có; mọi lần thêm một quyền cho công ty
   đang chạy vẫn phải qua SQL thô. Sẽ lặp lại ở 9 module còn lại.
5. **`LOGIN_RATE_LIMIT` trong `infra-erp`** cho máy dev. Một dòng biến môi trường.

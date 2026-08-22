# Bàn giao: tìm kiếm danh mục, phiên 2026-08-22

Đích: một thủ kho thật ghi chuyển động thật trên `http://103.179.172.110/`.
Kế hoạch gốc và bảng 12 khối: `2026-08-21-thu-tu-dua-kho-vao-su-dung.md`.
Bàn giao liền trước, còn nguyên giá trị: `2026-08-22-ban-giao-module-kho.md`.

## Chốt cuối phiên 2026-08-22

**Khối 5 xong phần backend, và chỉ phần backend.** Merge commit `a64c87a` trên `main` của
`backend-erp`, gộp nhánh `feat/tim-kiem-danh-muc` (bảy commit, `41301bb`..`d08ac30`). CI trên
`main` xanh cả ba job: lint 1m24s, arch 1m17s, test 3m13s (run 32585905061).

Hợp đồng đã chốt, để người làm frontend không phải đọc lại mã:

- Query param `q` trên `GET /api/v1/stock-items` và `GET /api/v1/warehouses`.
- Khớp **tiền tố** của `code` **hoặc chuỗi con** của `name`. Không phải cả hai đều chuỗi con.
- `binding:"omitempty,max=64"`. Vượt 64 ký tự trả **422** kèm `error.fields` mang tên `q`.
- Chuỗi rỗng và không gửi là **một thứ**, đều nghĩa là không lọc.
- `%`, `_`, `\` được thoát ở tầng service (`chuanHoaTimKiem`, khai một lần dùng chung cho hai
  service), nên người dùng gõ ký tự nào cũng chỉ là chữ, không thành ký tự đại diện.
- Mệnh đề lọc nằm sẵn trong mười hằng SQL (năm hằng mỗi bảng), **không** nối chuỗi lúc chạy.
- `q` **không** có ở `/stock-movements` và `/stock-balances`. Đó là tham số của **danh mục**,
  không phải của sổ. Muốn lọc sổ thì lọc bằng `stock_item_id` đã có sẵn.

**Đã đo index rồi mới quyết, không thêm index nào.** Ba câu trên máy dev với 500 vật tư và 50
kho cho 0,45-0,72 ms / 4 block, 0,52-0,89 ms / 11 block, 2,04-2,39 ms / 1 block. Ngưỡng là 20 ms
và 200 block, nên cả ba dưới ngưỡng một khoảng rất xa. Cuộc bàn hạ tầng `pg_trgm` **không mở**,
không ADR nào phải viết. Số đo đầy đủ, cách nạp dữ liệu đo, cách dọn, và **điều kiện tự huỷ**
của kết luận nằm ở phần "Nhật ký thi công" của kế hoạch gốc - đọc ở đó trước khi tin ba con số
này, vì chúng chỉ còn hiệu lực chừng nào mệnh đề lọc chưa đổi hình dạng.

## Chỗ hở đáng làm tiếp, theo thứ tự

### 1. Phần frontend của khối 5 - đây là thứ còn chặn ngày đi vào sử dụng

Backend đã có `q` nhưng **ô tìm kiếm chưa có trên màn hình nào**, nên với người dùng thì khối 5
vẫn chưa xảy ra. Triệu chứng gốc còn nguyên: `MovementRecordForm.tsx:103-111` nạp danh mục vật
tư với `page_size` bằng trần 100 rồi đổ thẳng vào một thẻ `<select>`, mà quy mô thật là vài
trăm mã - hai phần ba danh mục không chọn được.

**`frontend-erp/docs/superpowers/specs/` chưa có spec cho việc này.** Bảng 12 khối trước đây ghi
"+ bản frontend cùng tên", câu đó sai và đã sửa. Nên việc đầu tiên là viết spec, không phải mở
editor.

Hai chỗ dùng lại được `q` ngay khi có ô nhập:

- `src/modules/inventory/components/MovementRecordForm.tsx` - ô chọn vật tư, chỗ đau chính.
- `src/modules/inventory/pages/BalanceListPage.tsx` - lọc danh sách tồn.

Lưu ý khi viết spec: `code` khớp tiền tố còn `name` khớp chuỗi con, nên gõ giữa mã sẽ **không**
ra kết quả theo mã. Nếu thiết kế giao diện muốn gõ đâu cũng ra thì đó là đổi hợp đồng backend,
kéo theo phải đo index lại - không phải việc sửa ở frontend.

### 2. Endpoint sửa tập quyền của một vai trò

Vẫn chưa có. ADR-0024 và ADR-0027 đặt tập quyền dưới thẩm quyền quản trị công ty, nhưng API
chỉ có `PUT /users/:id/roles` và `GET /roles`. Nên **mọi lần thêm một quyền cho công ty đang
chạy đều phải qua SQL thô** gõ tay trên máy dev. Đợt module kho đã phải làm đúng thế cho hai
quyền mới của `inventory.admin`.

Việc này sẽ lặp lại ở **9 module còn lại**, nên nó không phải bất tiện một lần. Ràng buộc kèm
theo, đừng bỏ sót khi thi công: ADR-0028 mục 5 phải được áp ngay tại đường ghi - phép loại trừ
tập quyền tự tác động áp cho cả chiều ghi, không riêng chiều gán. Chi tiết ở
`2026-08-22-ban-giao-vai-tro-dot-2a.md` mục "Đợt 2b".

### 3. Khai `LOGIN_RATE_LIMIT` trong `infra-erp` cho máy dev

Thiếu nó thì mặc định 20 vẫn chạy, nên không có gì hỏng ngay. Chỗ đau là người vận hành **không
có nút nới** khi cả văn phòng ngồi sau một NAT bị chặn oan. Một dòng biến môi trường.

### 4. Ba khối còn lại của kế hoạch gốc

Khối 6 script nạp tồn đầu kỳ · khối 7 sổ chuyển động tra được · khối 10 luật chặn sửa mã và xoá
vật tư đã dùng. Khối 6 giờ đã hết bị chặn về phía backend: sau khi nạp vài trăm mã thì việc
nghiệm thu bằng tay đã có `q` để tìm, ít nhất là qua API.

## Hai cái bẫy của phiên này

Cả hai đã ghi đầy đủ vào nhật ký thi công của kế hoạch gốc. Nhắc lại một dòng mỗi cái:

- **`strings.ReplaceAll(sach, "\\", "\\")` trong chuỗi thô Go là lệnh rỗng** - hai vế bằng nhau
  từng byte - và bộ test viết ngay sau đó đã đóng đinh đúng hành vi sai ấy vì nó chép kỳ vọng từ
  mã chứ không tính lại từ đặc tả.
- **Thêm file test mới làm golden `arch/LEVELS.md` lệch số đếm**, nhưng chạy `arch-update` dưới
  máy Windows không có Docker thì nó ghi `FAIL` giả cho sáu rule cần database. Sửa tay con số,
  đừng chạy công cụ.

## Hai cái bẫy trên VPS dev, chưa ai ghi ra và sẽ cắn người sau

**`go run ./cmd/dev test` đỏ oan ở `erp/arch/internal/registry`.** Trên VPS dev, biến
`ERP_DOCS_PATH` **không có sẵn trong môi trường**, nên bài đó không tìm thấy tài liệu và báo đỏ.
Nghiệp vụ vẫn xanh. Đúng cái bẫy "chín bài `erp/arch` đỏ" mà bàn giao module kho đã ghi, chỉ là
nó chưa được vá vào môi trường của VPS nên nó quay lại mỗi phiên - đặt biến rồi chạy lại trước
khi tin màu đỏ.

**Bản `docs-erp` ở `/home/deploy/docs-erp` trên VPS dev không phải git repo.** Nó là một bản chép
tay, **không ai biết nó cũ tới đâu**. Đừng đọc nó để tra tài liệu, và tuyệt đối đừng sửa gì vào
đó rồi tưởng là đã sửa tài liệu - repo thật nằm dưới máy. Nếu cần trỏ `ERP_DOCS_PATH` tới nó thì
biết rằng mình đang cho `arch` đọc một bản có thể đã lệch.

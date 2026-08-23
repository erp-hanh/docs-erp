# Bàn giao: ô tìm danh mục, phần frontend - phiên 2026-08-23

Viết sáng 2026-08-24, ngay sau phiên.

Đích: một thủ kho thật ghi chuyển động thật trên `http://103.179.172.110/`.
Kế hoạch gốc và bảng 12 khối: `2026-08-21-thu-tu-dua-kho-vao-su-dung.md`.
Bàn giao liền trước: `2026-08-22-ban-giao-tim-kiem-danh-muc.md` - phần "chỗ hở đáng làm tiếp"
của nó vẫn còn giá trị, trừ mục 1 đã xong trong phiên này.

## Chốt cuối phiên

**Khối 5 xong cả hai đầu, và đã được đi thử bằng tay trên máy dev.** `v0.1.0-rc.30` đang chạy:
`infra-erp bae5b8b` · `backend-erp a64c87a` · `frontend-erp 4d6e8ff`.

Đây là bản rc đầu tiên mang tham số `q` của backend - rc.28 chưa có nó, dù nhánh đã merge từ
2026-08-22.

Bằng chứng nghiệm thu, đo trên chính máy dev với 300 vật tư:

- Trước khi gõ tìm, ô chọn vật tư của màn ghi chuyển động có **đúng 101 mục**, dừng ở
  `DEMO-0100`. `DEMO-0250` không với tới được. Đó là triệu chứng gốc mà khối 5 sinh ra để chữa,
  và nó đo được chứ không phải suy ra.
- Gõ `DEMO-0250` rồi Enter, ô chọn còn 2 mục và mã đó chọn được. **Ghi thật một dòng nhập 12**,
  backend lưu `12`, sổ lên 1 dòng.
- Chọn một mã rồi đổi chuỗi tìm: giá trị thật về rỗng **cùng lúc** ô chọn về rỗng. Không còn ca
  màn hình hiện một đằng mà request gửi một nẻo.
- Bấm Enter trong ô tìm nhiều lần: sổ vẫn 1 dòng, không dòng nào bị ghi oan.

Spec và kế hoạch nằm trong repo frontend, không ở đây:
`frontend-erp/docs/superpowers/specs/2026-08-23-o-tim-danh-muc-design.md` và
`frontend-erp/docs/superpowers/plans/2026-08-23-o-tim-danh-muc.md`.

## Ba cái bẫy của phiên này, và cái thứ nhất sẽ cắn lại

### 1. `main` của `frontend-erp` đổi hình dạng giữa chừng, vì tôi không `fetch` trước khi mở nhánh

Tôi mở nhánh từ `git log main` dưới máy mà **không** `git fetch` trước. `origin/main` lúc đó đã
đi trước **11 commit**, trong đó là cả đợt chuyển module `inventory` sang bộ component dùng
chung (PR #20, #21) - viết lại đúng năm file tôi đang sửa. Sáu file xung đột, và phần đắt không
nằm ở xung đột git mà ở chỗ **hai quyết định trong spec đã thành sai**:

- "Không thêm CSS, module inventory dùng thẻ gốc" - sai, module đã có `.module.css` từng màn.
- "Không thêm nhánh lỗi cho hai ô chọn" - sai, đợt refactor **đã** thêm `isPending` và `error`
  cho ô chọn danh mục. Gói hai `<select>` vào một component mà bỏ mất chúng là một bước lùi.

Và một chỗ nữa suýt lọt: ghi chú của bản refactor viết "màn danh sách kho không có ô lọc nào
cắt bớt tập kết quả nên không có ca lọc không ra gì". Thêm `q` làm câu đó sai, sinh ra ca rỗng
thứ ba - và nó phải được hỏi **trước** ca "chưa có kho nào", vì `meta.total` lúc đang lọc là số
bản ghi khớp chứ không phải số kho của công ty.

**Việc phải làm ở phiên sau: `git fetch` rồi so `origin/main` TRƯỚC khi mở nhánh, mỗi lần.**
Đọc `git log main` dưới máy không trả lời được câu "người khác đã đẩy gì lên".

### 2. Máy dev là insecure context, và điều đó làm vỡ những thứ không bài test nào bắt được

`http://` ở một địa chỉ IP nên `window.isSecureContext === false`. Mọi API chỉ có trong secure
context đều **`undefined`** ở đó.

Đã cắn: `crypto.randomUUID` vắng mặt làm **cả màn ghi chuyển động vỡ ngay lúc mở** với
`crypto.randomUUID is not a function`, và ba chỗ khác trong module `machine` cũng vậy. Lỗi nằm
im từ 2026-08-15.

Vì sao không ai thấy: cả bộ test xanh vì **jsdom chạy trong một secure context giả**, và
`npm run dev` dưới máy là `localhost` - mà `localhost` cũng LÀ secure context. Chỉ có mở trình
duyệt thật trỏ vào dev mới lộ ra.

Đã chữa bằng `frontend-erp/src/shared/api/sinh-khoa.ts`: dùng `randomUUID` khi có, không thì
ghép UUID v4 từ `crypto.getRandomValues` - hàm này **không** đòi secure context và vẫn là nguồn
ngẫu nhiên mật mã, nên lý do gốc của khoá idempotency được giữ nguyên và không hạ xuống
`Math.random`. Nó ở `shared/api/` chứ không trong module vì ba chỗ gọi nằm ở hai module, mà
C-TS-01 chỉ cho module này chạm module kia qua `api/`.

**Còn chờ cắn y hệt:** `navigator.clipboard`, `navigator.geolocation`, service worker,
`crypto.subtle`, `navigator.mediaDevices`. Trước khi dùng bất kỳ API trình duyệt nào, hỏi xem
nó có đòi secure context không.

### 3. Một con số tổng nói dối khi có bộ lọc

Tiêu đề màn danh sách vật tư ghi "10 vật tư trong công ty này" trong khi công ty có 300 - vì
khi có bộ lọc, `meta.total` là số bản ghi **khớp**. Màn phân vùng đã rẽ đúng từ đầu; hai màn kho
thì chưa, và ô tìm làm ca đó xảy ra mỗi ngày thay vì thỉnh thoảng. Đã chữa.

Cả ba lỗi ở mục 2 và 3 đều **không** do đợt này sinh ra, và **không** bài test nào bắt được.
Chúng lộ ra vì có người mở trình duyệt thật sau khi deploy. Đó là lý do bước "đi thử bằng tay
trên dev" không thay được bằng một lần `curl /health`.

## Chỗ hở đáng làm tiếp, theo thứ tự

### 1. Dọn dữ liệu thử trên dev - quyết trước khi làm gì khác

Trên dev đang có **300 vật tư `DEMO-0001..DEMO-0300`** ở phân vùng `DEFAULT`, chèn thẳng bằng
SQL nên **không có dòng audit**, cộng **một dòng sổ chuyển động thật** (nhập 12 vào `QA-KHO-A`
cho `DEMO-0250`) do đi qua giao diện nên có audit đầy đủ.

Chúng được cố ý để lại cho chủ dự án tự xem. Muốn dọn thì **xoá dòng sổ trước** - nó tham chiếu
`DEMO-0250` nên xoá vật tư trước sẽ vướng khoá ngoại. Đợt đo index của phiên trước dọn sạch sau
khi xong; nếu giữ nếp đó thì đây là việc còn nợ.

### 2. Endpoint sửa tập quyền của một vai trò

Vẫn chưa có, và bàn giao trước đã tả đủ. Nhắc lại một dòng vì nó sẽ lặp lại ở **9 module còn
lại**: mọi lần thêm một quyền cho công ty đang chạy đều phải qua SQL thô gõ tay trên dev. Chi
tiết và ràng buộc ADR-0028 mục 5 ở `2026-08-22-ban-giao-vai-tro-dot-2a.md`.

### 3. Khai `LOGIN_RATE_LIMIT` trong `infra-erp` cho máy dev

Một dòng biến môi trường. Thiếu nó thì mặc định 20 vẫn chạy, nhưng người vận hành không có nút
nới khi cả văn phòng ngồi sau một NAT bị chặn oan.

### 4. Ba khối còn lại của kế hoạch gốc

Khối 6 script nạp tồn đầu kỳ · khối 7 sổ chuyển động tra được · khối 10 luật chặn sửa mã và xoá
vật tư đã dùng. Khối 6 giờ hết bị chặn ở cả hai đầu: sau khi nạp vài trăm mã thì nghiệm thu bằng
tay đã có ô tìm trên **giao diện**, không chỉ qua API.

## Một commit chưa vào `main` của `infra-erp`

Nhánh `docs/dong-bo-ke-hoach-kho`, một commit docs thuần
(`121b366 docs: bỏ tiền đề sai "VPS không có Go" khỏi spec nạp tồn đầu kỳ`). rc.29 và rc.30 đều
không có nó. Docs nên không đổi thứ gì được build, nhưng nó đang treo ở đó.

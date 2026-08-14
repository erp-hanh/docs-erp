# Bàn giao — việc làm sau chặng F, trước chặng G

File này nối tiếp [2026-08-14-ban-giao-chang-f.md](2026-08-14-ban-giao-chang-f.md), viết
cùng ngày trong một phiên khác chạy song song. Nó ghi phần việc mà bàn giao chặng F không
biết vì hai phiên làm cùng lúc trên cùng bốn repo.

Nó **không** thay thế file kia. Đọc file kia trước — nó mô tả chặng F; file này mô tả những
gì xảy ra sau khi chặng F đóng.

---

## 0. Đọc dòng này trước mọi dòng khác

**Toàn bộ việc trong file này đã merge lên `main` của cả bốn repo, và CI xanh.** Không nhánh
nào chờ, không việc nào chưa commit. Đây là khác biệt lớn nhất so với hai bàn giao trước.

| Repo | `main` |
|---|---|
| `docs-erp` | `a885427` |
| `backend-erp` | xem PR #5 bên dưới nếu đã merge, nếu chưa thì `285670c` |
| `frontend-erp` | `6143eee` |
| `infra-erp` | `a0ed19e` |

Chặng E và F **đều** đã lên `main` — trước phiên này chúng nằm local từ chặng E, chưa đẩy
lần nào.

## 1. Bốn khối việc

### 1.1 Bản đồ phạm vi hệ thống — thứ đáng đọc đầu tiên

[pham-vi-he-thong.md](pham-vi-he-thong.md) và [ADR-0017](../03-decisions/ADR-0017-muoi-hai-module-va-ten-tieng-anh.md).

Trước phiên này, câu hỏi *"còn bao nhiêu chặng nữa"* **không ai trả lời được từ repo**. Mỗi
chặng được viết spec đúng vào ngày nó bắt đầu, và registry `C-DB-04` không dự trù một bảng
nghiệp vụ nào.

Giờ có: **12 module, 10 chặng còn lại, ~145–185k dòng** theo mốc đo được từ `machine`
(14.700 dòng / 75 file cho một module ba thực thể). Tên module tiếng Anh — `inventory`,
`purchasing`, `sales`, `yard`, `production`, `hr`, `attendance`, `payroll`, `accounting`,
`reporting`.

ADR-0017 chốt **tập ranh giới**, và cố ý **không** chốt danh sách bảng, thứ tự chặng hay
ước lượng: chín trên mười hai module chưa có dòng code nào.

[ADR-0016](../03-decisions/ADR-0016-kalmar-dung-chung-machine.md) đóng một câu hỏi treo từ
ADR-0001: Kalmar dùng chung `machine`. Nó **đã được trả lời từ chặng C bằng một CHECK
constraint** (`ck_machines_kind` có sẵn `xe_nang`) mà không ADR nào giải trình.

### 1.2 Ba bảng danh mục

`migrations/000012` `000013` `000014` — `units`, `currencies`, `provinces`. Cả ba đã có tên
trong `reference_tables` của `C-DB-04` từ trước nên không cần ADR mới.

**Bảng rỗng, không seed dữ liệu.** Xem 3.1.

### 1.3 Ba câu hỏi hợp đồng treo từ chặng E — đã trả lời và đã có code

| Câu | Trả lời |
|---|---|
| Nới date-only | **Có**, nhưng chỉ cho trường trên cột `DATE`; `occurred_at` giữ RFC 3339 |
| Đường gỡ `commissioned_date` | **Có**, `""` làm sentinel — đúng khuôn `assigned_to` |
| `PATCH` cho ghi rỗng | **Không**, `422` kèm tên ô; luật ở service chứ không ở tag |

Test ở `modules/machine/internal/handler/hopdong_test.go`. Mục 3.4 của bàn giao chặng E giữ
nguyên văn ba câu hỏi kèm một bảng trả lời ở đầu mục — chúng ghi lại **điều chưa biết ở thời
điểm viết**, và đó là thứ duy nhất giải thích được vì sao hợp đồng ban đầu có hình dạng đó.

### 1.4 Hai lỗ hổng công cụ — cùng một họ

Cả hai đều là bẫy **chỉ nổ ở máy dev Windows, không nổ ở CI** — loại khó tìm nhất.

**`arch/RULES-PIN.md` không được `.gitattributes` khóa về LF.** Golden file thứ hai, thêm ở
chặng F, bị bỏ quên. Sau một lần `git checkout` sang nhánh khác, `pin_test.go` báo *"khong
doc duoc dong ghim nao"* trong khi `git diff` **sạch** — git chuẩn hóa xuống dòng khi so
sánh nên nó giấu đúng dấu vết duy nhất.

**`*.go` cũng vậy, và hệ quả lớn hơn.** `go run ./cmd/dev lint` báo **75/75 file** là "chưa
định dạng", toàn bộ là báo giả. Lệnh đó thực tế **không dùng được** trên máy dev, nên lỗi
gofmt thật chỉ còn bị bắt ở CI — đã xảy ra trong chính phiên này.

## 2. Một giới hạn kiến trúc của CI, đã sửa

CI của `backend-erp` checkout `docs-erp` **không chỉ định `ref`**, nên luôn đọc `main`. Suốt
năm chặng đầu điều đó đúng vì chưa chặng nào đổi *cả* `RULES.md` *lẫn* code trong cùng một
PR. Chặng F là lần đầu, và hậu quả là hai job đỏ ở PR #1 với thông điệp *"menh de nguon cua
R-11 da doi"* — trong khi `cmd/dev arch` chạy **cục bộ** cho exit 0.

Không có lỗi code nào. Nhưng nó đặt ra một **thứ tự merge bắt buộc giữa hai repo mà không
văn bản nào nói**.

Đã sửa ở PR #2: lấy nhánh cùng tên của `docs-erp` nếu có, không thì lùi về `main`. **Cả hai
nhánh của điều kiện đã được chứng minh trên CI thật**, và sau đó nó gặp một PR thật chạm hai
repo (PR #4 + docs PR #2) và xử đúng.

## 3. Việc chưa làm

### 3.1 Nạp dữ liệu cho ba bảng danh mục — chưa ai quyết đường nào

`000001_create_companies.up.sql` có seed, nhưng ngoại lệ R-17 cho nó được cấp với **một lý
do đã hết hạn**: `audit_logs` khi đó chưa tồn tại. Nó tồn tại từ `000004`. Một câu `INSERT`
trong migration bây giờ sẽ ghi vào bảng chịu R-17 mà không sinh dòng audit nào.

Hai đường: một lệnh dev đi qua service thật (khuôn `cmd/dev bootstrap-user` đang dùng), hoặc
một ADR mở rộng ngoại lệ R-17 cho seed danh mục.

**Không chặn chặng G** — `inventory` chỉ cần bảng `units` tồn tại để trỏ khóa ngoại tới.
Chặn màn hình nhập vật tư đầu tiên.

### 3.2 Ba mốc phải xong trước ba chặng cụ thể

| Việc | Trước chặng |
|---|---|
| ADR cho `document_counters` — chưa xếp được vào bốn nhóm bảng của `C-DB-04` | **H** |
| ADR cho phân quyền theo phạm vi — `Can(ctx, actor, perm string)` không diễn đạt nổi *"xem lương cả phòng tôi"*; động vào `shared/authz` mà mọi module đều gọi | **N** |
| Trả lời câu hỏi hóa đơn điện tử thuế — ERP này *phát hành* hay chỉ ghi nhận | **O** |

### 3.3 Bốn câu hỏi còn lại của mục 3.4 bàn giao chặng E

Câu 4 đến 7 vẫn mở: link lùi làm rơi bộ lọc, `src/modules/machine` import ngược `@/app`,
hai văn phạm đường dẫn field, `toFormErrors` không có `isForbidden`.

### 3.4 Việc duy nhất chỉ người làm được

**Cho người dùng thật bấm [mockup-dieu-huong.html](mockup-dieu-huong.html).**

Sáu dòng `CHỐT` trong bản đồ phạm vi dựa trên câu *"phạm vi điển hình như bao công ty
khác"* — chưa va nghiệp vụ thật lần nào. Ba câu để hỏi: thiếu trang nào, trang nào không bao
giờ mở, sơ đồ quy trình có giống cách họ đang làm không.

Một dòng sai phát hiện ở đó tốn một dòng markdown. Phát hiện ở chặng G tốn một migration đã
merge mà R-07 không cho sửa.

## 4. Hai thứ về môi trường, không có trong repo

**Tài khoản GitHub.** Bốn repo ở org `erp-hanh`, và `gh` trên máy có hai tài khoản.
`tonghanh106` là active mặc định nhưng **không có quyền** — `docs-erp` trả 403, ba repo kia
trả "Repository not found". Tài khoản đúng là `hanhtv106`. Chạy `gh auth switch --user
hanhtv106` trước khi push. Nó **tự nhảy về** trong phiên này ít nhất một lần.

**Trình duyệt tự động dùng chung.** Hai phiên chạy song song dùng chung daemon
`agent-browser`; giữa chừng nó nhảy sang trang của dự án khác. Nếu cần, dùng session riêng.

## 5. Đề nghị cho phiên tiếp theo

**Chặng G — `inventory`.** Đường vào rõ:

1. Đọc `06-checklists/CL-NEWMOD-new-module.md` — 15 dòng kiểm, phần lớn đã có checker trong
   `arch/` kiểm tự động
2. Viết spec + plan theo khuôn năm chặng trước, đặt ở `99-meta/specs/`
3. `units` đã có bảng, chỉ cần trỏ khóa ngoại tới

**Phép thử thật sự của chặng này không phải `inventory` chạy được.** Hai module hiện có —
`auth` và `machine` — **chính là** cái đẻ ra bộ khung, nên chúng không kiểm chứng được nó.
`inventory` là module đầu tiên đi qua bộ khung mà không tham gia thiết kế nó.

Nếu nó nhanh bất thường, bộ khung đáng giá. Nếu nó chậm và phải nới rule liên tục, thì đó là
điều đáng biết hơn nhiều so với việc canh thêm một mệnh đề nữa.

Câu hỏi nên hỏi ở cuối chặng G: **module thứ ba tốn bao nhiêu so với mốc 14.700 dòng của
`machine`?** Con số đó là thứ duy nhất trả lời được sáu chặng hạ tầng có đáng hay không.

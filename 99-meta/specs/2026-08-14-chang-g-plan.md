# Chặng G — Implementation Plan

> **Spec:** [2026-08-14-chang-g-inventory-design.md](2026-08-14-chang-g-inventory-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách sáu chặng trước đã chạy.

**Goal:** Bảng phép đo ở mục 1 của spec được điền bằng số đếm thật, và câu hỏi *"module thứ
ba tốn bao nhiêu so với mốc 14.700 dòng của `machine`"* có một câu trả lời bằng số.

---

## Đồ thị phụ thuộc

Hai ràng buộc thứ tự **cứng**, và cả hai là hàng phòng thủ chứ không phải tiện bố cục.

> **G1 phải chạy TRƯỚC khi thư mục `modules/inventory/` tồn tại.**

`tools/dem-dong.ps1` là công cụ sinh ra con số mà cả chặng này tồn tại để đọc. Viết nó sau
khi đã có code `inventory` là mở đường cho việc chọn cách đếm sau khi biết kết quả — cùng
hình dạng bẫy mà chặng F đã đặt tên: *checker viết trước code thì nó sinh ra đã xanh*, và ở
đây là mặt kia của cùng đồng xu. Nghiệm thu của G1 là đếm lại `machine` ra **đúng** 14.700
/ 75; lệch thì sửa **công cụ**, không sửa mốc.

> **G4 phải xong trước G9, và nó động vào một đường đang chạy thật.**

`shared/idempotency` hôm nay có đúng một người dùng: subscriber `auth.user.deleted`. Đổi chữ
ký của nó mà làm hỏng nhánh đó thì cái hỏng **không** lộ ra ở bất kỳ test nào của
`inventory`.

```
DOT 1 (song song, 3 agent):
  G1  tools/dem-dong.ps1 + do lai moc machine        backend-erp/tools/, frontend-erp/
  G2  ADR-0018 + bon keo theo docs                   docs-erp/
  G3  migration ba bang + ma loi ERR_INVENTORY_*     migrations/00001{5,6,7}, shared/errors/

DOT 2 (song song, sau DOT 1):
  G4  migration 000018 + hop dong ClaimOrLoad        migrations/000018, shared/idempotency/
  G5  cmd/dev seed-units                             cmd/dev/, cmd/internal/
  G6  model + ba repository                          modules/inventory/internal/{model,repository}/

DOT 3 (sau G6):
  G7  WarehouseService                               .../service/warehouse_service.go
  G8  StockItemService                               .../service/stock_item_service.go

DOT 4 (sau G4 va G6):
  G9  MovementService - khoa, ton kho, idempotency   .../service/movement_service.go

DOT 5 (sau DOT 3 va DOT 4):
  G10 ba handler + ba file route
  G11 module.go + module.yaml + vaitro + ghep o cmd/api

DOT 6 (sau G11):
  G12 docs module (5 file) + e2e + phep thu tranh chap ghi

DOT 7 (sau G10 - can hop dong API that de viet client):
  G13 api client + hooks + sinh Idempotency-Key luc mo form   frontend-erp/src/modules/inventory/{api,hooks}/
  G14 man kho + man vat tu (list + form tao/sua)              .../components/, .../pages/
  G15 man ton kho + man ghi chuyen dong                       .../components/, .../pages/

DOT 8 (sau G13-G15):
  G16 route + duong dan dieu huong toi SAU man
```

**G7 và G8 trước G9, không đảo:** `MovementService` giữ `stockItemRepo` của riêng nó để lấy
khóa `FOR UPDATE` (spec mục 5.2). Hình dạng repository phải chốt xong ở G6 và đã có hai
service dùng thật trước khi G9 dựa vào nó — nếu G6 sai hình dạng thì G7/G8 phát hiện rẻ hơn
G9 nhiều.

**G9 là task đắt nhất của chặng** và nó gánh ba thứ chưa từng có trong repo cùng lúc: khóa
ở tầng database, một số dư tính ra, và hợp đồng `Idempotency-Key` đầu tiên. Không gộp thêm
gì vào nó.

**G13 sau G10, không sau G11:** client cần **hợp đồng HTTP thật** (đường, hình dạng body,
mã lỗi), không cần composition root đã ghép xong.

**G16 tồn tại như một task riêng chứ không phải một dòng của G14/G15**, và lý do là một lỗi
đã xảy ra thật: chặng E dựng đúng ba màn spec của nó chốt, cả ba chạy, 278 test xanh, và
**không màn nào có đường dẫn tới từ giao diện** (bàn giao chặng F mục 3.2). Không test nào
bắt được vì mọi test đều dựng thẳng component cần kiểm. Một task riêng là chỗ duy nhất câu
hỏi *"làm sao người dùng tới được đây"* có người phải trả lời.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test phạm vi của mình.** Không `go build ./...`, không `npm test` toàn bộ —
   agent khác đang viết dở, và lỗi của người khác không phải tín hiệu về việc mình đúng hay
   sai.
2. **Không sửa file ngoài phạm vi task.** `docs-erp/**` chỉ G2; `shared/idempotency/**` chỉ
   G4; `cmd/**` chỉ G5 và G11; `frontend-erp/**` chỉ G13–G16.
3. **Không chạy `go test ./arch -update`, `arch-pin`, hay `npm run arch:update`** — golden
   file do người điều phối sinh lại một lần ở cuối.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code, theo
   đúng mật độ và giọng của `modules/machine`. Tài liệu thì tiếng Việt **có dấu**.
5. **Số lượng không bao giờ đi qua `float64`**, kể cả trong test: cột `NUMERIC(18,4)`, Go là
   `decimal.Decimal`, JSON là **chuỗi**. `quantity` ở module này chịu đúng luật mà chặng C
   đặt ra cho tiền — spec mục 5.4.
6. Mọi method public của service nhận `actor auth.Actor` làm tham số thứ hai và mở đầu bằng
   `s.authz.Can` — không dòng nào đứng trước.
7. **Không tạo bảng `stock_balances`, không thêm cột `on_hand`.** Tồn kho là `SUM(quantity)`
   (spec mục 3.4). Nếu một task thấy mình cần một cột tồn để làm xong việc, đó là dấu hiệu
   thiết kế sai — **dừng và báo cáo**, đừng thêm cột.
8. **Không phát event, không viết `internal/subscriber/`** (spec mục 6). Một dòng
   `outboxRepo.Append` trong chặng này là một hợp đồng công khai chưa ai ký.
9. **Chạy test cần Postgres**: container cổng 5433, template `erp_template`.
   `export TEST_DATABASE_URL="postgres://erp:erp@localhost:5433/erp_dev?sslmode=disable"` rồi
   `go test ...`. Đừng chạy `go run ./cmd/dev test` (chậm, dựng container riêng).
10. **`gh auth switch --user hanhtv106` trước khi đẩy.** `tonghanh106` là active mặc định,
    không có quyền, và nó **tự nhảy về** — bàn giao chuẩn bị mục 4.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **G1** | `tools/dem-dong.ps1` — đếm dòng/file theo **sáu** hạng mục của mốc `machine`, chạy được cho một tên module bất kỳ ở cả hai repo | `backend-erp/tools/dem-dong.ps1` | Chạy cho `machine` ra **14.700 dòng / 75 file**, và sáu hạng mục khớp bảng ở `pham-vi-he-thong.md` mục 1. Lệch thì sửa **công cụ**, không sửa mốc. Chạy cho `inventory` lúc này ra **0** — đó là nghiệm thu thứ hai |
| **G2** | ADR-0018 (lưu response phát lại cho `Idempotency-Key` HTTP); bốn kéo theo: bốn dòng `ERR_INVENTORY_*` + bốn dòng ánh xạ constraint ở C-API-05, dòng đầu tiên của C-API-07 **bảng 5**, sửa blockquote `outbox_dead_letters` ở C-DB-04, sửa cột bảng của `inventory` ở `pham-vi-he-thong.md` | `docs-erp/03-decisions/`, `04-conventions/`, `99-meta/` | `check-ids.ps1` xanh. ADR-0018 ghi **điều kiện mở lại**. Blockquote C-DB-04 không còn câu nào nói chặng G viết migration dead-letter — spec mục 8 |
| **G3** | Migration ba bảng + bốn hằng `ERR_INVENTORY_*` | `migrations/00001{5,6,7}_*.{up,down}.sql`, `shared/errors/codes.go` | R-06/R-08/R-09/R-17/R-18 xanh trên migration mới; `down` lùi đúng thứ tự ngược. `INSERT` thẳng một dòng `kind='xuat'` với `quantity > 0` → **database từ chối**. Hằng khớp bảng C-API-05 từng ký tự |
| **G4** | `migrations/000018` nới `idempotency_keys` (`request_hash`, `response_status`, `response_body`) + chữ ký `ClaimOrLoad`, bỏ `Claim` | `migrations/000018_*`, `shared/idempotency/` | **`TestClaimLanDauGianhDuocLanHaiThiKhong` và `TestClaimCuonNguocCungTransaction` vẫn xanh sau khi đổi**; phải sửa thì nêu lý do trong báo cáo chứ không sửa cho qua. Bảng vẫn ghi **đúng một lần** — không có `UPDATE` nào lên nó. Subscriber `auth.user.deleted` chuyển sang hàm mới và test DB của nó vẫn xanh |
| **G5** | `cmd/dev seed-units` — ghi `units` + `audit_logs` trong **cùng** transaction, actor là `system_actor_id` | `cmd/dev/`, `cmd/internal/` | **Không** câu `INSERT` nào vào migration (spec mục 3.2). Chạy hai lần không nhân đôi dòng. Tên lệnh có mặt ở bảng lệnh trong `backend-erp/CLAUDE.md` — test đối chiếu hai chiều sẽ đỏ nếu thiếu |
| **G6** | Ba model + ba repository, gồm câu tính tồn | `modules/inventory/internal/{model,repository}/**` | SQL là hằng chuỗi đơn (C-GO-07); mọi câu kèm `company_id = $n` và `deleted_at IS NULL`. Câu tính tồn là `SUM(quantity)` trần, **không** có `CASE` nào theo `kind`. `sort` đi qua map whitelist tĩnh (R-12) |
| **G7** | `WarehouseService` — 5 method CRUD | `.../service/warehouse_service.go` + test | Trùng mã → `409 ERR_INVENTORY_CODE_DUPLICATED`; xóa là set `deleted_at`, và tạo lại đúng mã đó sau khi xóa **thành công** |
| **G8** | `StockItemService` — 5 method CRUD + kiểm `unit_id` | `.../service/stock_item_service.go` + test | `unit_id` không tồn tại → `422 ERR_INVENTORY_UNIT_INVALID`. Câu đọc `units` **không** làm `checkR02` đỏ (ngoại lệ `reference_tables`) — kiểm bằng cách chạy `arch`, không bằng suy luận |
| **G9** | `MovementService` — ghi chuyển động, khóa `FOR UPDATE`, kiểm tồn, `ClaimOrLoad`, và `ListBalances` | `.../service/movement_service.go` + test | Xuất quá tồn → `409 ERR_INVENTORY_INSUFFICIENT_STOCK` và **không dòng nào được ghi**. `ClaimOrLoad` là câu lệnh đầu tiên chạm database của phần nghiệp vụ. `id` và `created_at` sinh ở Go (spec mục 4), không phải `gen_random_uuid()`/`now()`. Tồn của một cặp (kho, vật tư) tại `tinh_den` trong quá khứ đọc theo `occurred_at`, không theo `created_at` |
| **G10** | Ba handler + ba file route | `modules/inventory/internal/handler/**` | Mọi đường ra qua `shared/response`; `BindFailed` cho mọi lỗi bind. `POST /stock-movements` đọc header `Idempotency-Key`, thiếu → `422 ERR_COMMON_IDEMPOTENCY_KEY_MISSING`; trùng khóa cùng payload → **response y hệt lần đầu**; trùng khóa khác payload → `422 ERR_COMMON_IDEMPOTENCY_KEY_REUSED`. `GET /stock-balances` chịu R-12 đủ (`page`, `page_size`, `sort`, `meta.total`) |
| **G11** | `module.go`, `module.yaml`, permission vào `cmd/internal/vaitro`, ghép ở `cmd/api` | `modules/inventory/module.{go,yaml}`, `cmd/**` | `allowed_deps: []` và `internal_methods: []`, cả hai khai **rỗng** chứ không bỏ trường. Mười bốn permission đều có ít nhất một vai trò cấp được (C-GO-08) |
| **G12** | Năm file docs module + e2e + phép thử tranh chấp ghi | `modules/inventory/docs/**`, `cmd/api/e2e_test.go` | `Database.md` khớp **từng dòng** `tables`. `Events.md` mục 1 và 2 **rỗng**, mục 3 liệt kê ứng viên kèm lý do (spec mục 6). E2e chạy hết vòng ở spec mục 9. Hai `POST` xuất 8 song song trên tồn 10 → đúng một `201`, một `409`, tồn cuối `2`; **không dùng đồng hồ** để đồng bộ |
| **G13** | `api/inventory-api.ts` + hooks; khóa `Idempotency-Key` sinh **lúc mở form** | `frontend-erp/src/modules/inventory/{api,hooks}/` | Khóa giữ nguyên qua mọi lần bấm và mọi lần retry, chỉ đổi khi bắt đầu một thao tác mới (C-API-07 bảng 5). Có test chứng minh: bấm hai lần → **cùng** một khóa đi ra |
| **G14** | Màn danh sách kho, form tạo/sửa kho, màn danh sách vật tư, form tạo/sửa vật tư | `.../components/`, `.../pages/` | Có đường tạo ngay từ đầu — không lặp lại ngõ cụt của `machine` (bàn giao chặng F mục 3.2). Form vật tư chọn đơn vị tính từ `units` |
| **G15** | Màn tồn kho + màn ghi chuyển động | `.../components/`, `.../pages/` | Thân request chỉ mang **đầu vào thô**; tồn mới render lại từ response. Hiện *"tồn sau thao tác"* lên màn thì được — và **phải có**, vì nó là ca chứng minh luật R-19 phân biệt được hiển thị với gửi đi |
| **G16** | Route + đường dẫn điều hướng tới **sáu** màn | `frontend-erp/src/app/router/`, menu | Một ca test đi từ màn đăng nhập tới màn ghi chuyển động **chỉ bằng cách bấm**, không gõ URL. Đây là câu hỏi 278 test của chặng E không hỏi |

---

## Cuối chặng — người điều phối làm, không giao agent

1. **Phép đo, và nó đứng đầu chứ không đứng cuối.** Chạy `tools/dem-dong.ps1` cho
   `inventory`, điền bảng ở mục 1 của spec, rồi **viết câu trả lời** cho câu hỏi *"module thứ
   ba tốn bao nhiêu so với 14.700"* — kèm cả con số thô lẫn con số đã trừ ba khoản không so
   sánh được. Nếu nó chậm và phải nới rule liên tục thì **đó** là kết quả của chặng, và nó
   đáng ghi hơn bất cứ thứ gì khác trong bàn giao.
2. **Bốn phép thử bằng đột biến**, mỗi cái đỏ đúng chỗ rồi hoàn lại: SQL nêu tên `machines`
   trong repository của `inventory` → `checkR02` đỏ; SQL nêu tên `units` → **vẫn xanh**; bỏ
   `idx_stock_items_company_id_unit_id` → R-09 đỏ; `tonHienTai - soLuongXuat` vào thân request
   `POST` → ESLint đỏ, còn để nguyên phép tính đó trong JSX → **xanh**.
3. **Đo vùng mù `allowed_deps`.** Thêm `auth` vào `allowed_deps` của `inventory` trong khi
   module không import gì của `auth`, chạy `arch`, **ghi lại kết quả thật**. Xanh thì đó là
   một vùng mù có tên — vào bàn giao, **không** vá trong chặng này.
4. **Ba ca `Idempotency-Key` chạy qua HTTP thật**, không qua unit test của service: thiếu
   header, trùng khóa cùng payload, trùng khóa khác payload. Ca thứ hai kiểm thêm
   `SELECT count(*) FROM stock_movements` tăng **đúng 1**.
5. **Chạy thật cả stack rồi mở trình duyệt.** `scripts/up`, đăng nhập ở `localhost:5173`,
   `seed-units`, rồi đi hết lát cắt bằng chuột. Chặng F đã cho thấy có một lớp lỗi mà chỉ dựng
   thật mới thấy, và cả ba lỗi lớn nhất của nó đều không tìm được bằng đọc code hay chạy test.
6. `go run ./cmd/dev arch-update`, **đọc diff** — chỉ cột FILE được tăng, không dòng nào hạ
   mức.
7. `go generate ./arch/...` + `git diff --exit-code`.
8. `go run ./cmd/dev check` rồi `test`. `npm run lint && npm run arch && npm test`.
   `check-ids.ps1` cho `docs-erp`.
9. Chạy `CL-NEWMOD-new-module.md`, `CL-SCHEMA-schema-change.md`, `CL-API-new-endpoint.md`
   **bằng mắt**. `CL-NEWMOD-01` và `CL-NEWMOD-08` là hai dòng đáng soi nhất ở chặng này —
   `tables` thiếu một bảng thì bộ kiểm **không báo gì**, nó chỉ lặng lẽ coi bảng đó là của
   module khác.
10. **PR chạm cả `docs-erp` lẫn code phải merge `docs-erp` trước.** CI của `backend-erp` lấy
    nhánh cùng tên của `docs-erp` nếu có, không thì lùi về `main` — chặng G có G2 sửa
    `C-API-05` và `C-API-07` trong khi G3 và G10 dựa vào chúng, nên đây là ca thật của cơ chế
    đó.
11. Đẩy bốn repo, đợi CI — `backend-erp` ba job, `frontend-erp` ba job, `infra-erp` một job.

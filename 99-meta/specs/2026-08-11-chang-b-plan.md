# Chặng B — Implementation Plan

> **Spec:** [2026-08-11-chang-b-auth-user-design.md](2026-08-11-chang-b-auth-user-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách chặng A đã chạy, nhưng lần này các task độc lập chạy song song.

**Goal:** Bảy dòng `PASS tren tap RONG` trong `arch/LEVELS.md` biến mất; 18/19 rule chạm code sản xuất.

---

## Đồ thị phụ thuộc

```
DOT 1 (song song, 6 agent):
  B1  checker C-GO-05 cho module.yaml       arch/
  B2  shared/auth                            shared/auth/
  B3  shared/authz                           shared/authz/
  B5  shared/audit                           shared/audit/
  B6  migration users/refresh_tokens/audit_logs   migrations/
  B9  ma loi moi + quy uoc permission        docs-erp/ + shared/errors/

DOT 2 (sau B2):
  B4  shared/middleware/auth                 shared/middleware/auth/

DOT 3 (sau B1..B6):
  B7  modules/auth
  B8  modules/user        <- B7 phu thuoc B8 qua api/, xem muc "Thu tu B7/B8"

DOT 4:
  B10 cmd/api ghep lai: bang role->permission, dang ky module, middleware
  B11 docs module (5 file moi module), dang ky C-API-07, chay het checklist
```

**Thứ tự B7/B8:** `modules/auth` gọi `modules/user/api/` để lấy user theo email (spec mục 7),
nên `user/api/` phải có trước. Làm `B8` phần `api/` + `model/` + `repository/` trước, rồi
`B7`, rồi phần còn lại của `B8`. Hoặc đơn giản hơn: một agent làm cả hai module tuần tự.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test package của mình**, không chạy `go build ./...` — các agent khác đang
   viết dở package khác, và một lỗi biên dịch của người khác không phải tín hiệu về việc mình
   làm đúng hay sai.
2. **Không sửa file ngoài phạm vi task**. Trùng file giữa hai agent là hỏng.
3. **Không chạy `go test ./arch -update` hay `arch-pin`** — golden file do người điều phối
   sinh lại một lần ở cuối, sau khi mọi task xong.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code — theo
   đúng mật độ và giọng của code hiện có.
5. Mọi checker mới phải qua phép thử: **vô hiệu hóa nó thì có thứ gì đó đỏ**.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **B1** | Checker `C-GO-05` cho `module.yaml` | `arch/checks_module.go`, `arch/testdata/cgo05/` | Fixture hai chiều; `TestFixtures/C-GO-05` xanh; phá checker thì đỏ |
| **B2** | `shared/auth` — `Actor`, `FromContext`, `WithActor` | `shared/auth/auth.go` + test | Không import JWT; test round-trip ctx |
| **B3** | `shared/authz` — `Checker`, `Bang`, `New` | `shared/authz/authz.go` + test | `Can` trả `apperr.Forbidden` khi thiếu quyền |
| **B4** | `shared/middleware/auth` — verify JWT, gắn actor | `shared/middleware/auth/auth.go` + test | Thiếu token → 401 envelope + abort; token hợp lệ → actor trong ctx |
| **B5** | `shared/audit` — `Entry`, `Repository` | `shared/audit/audit.go` + `postgres.go` + test | `Record` nhận `DBTX`; ghi được trong transaction |
| **B6** | Migration ba bảng | `migrations/00000{2,3,4}_*.{up,down}.sql` | `cmd/dev test` xanh; R-06/R-08/R-09/R-17/R-18 xanh trên migration mới |
| **B7** | `modules/auth` | `modules/auth/**` | Bốn method; `token/` chỉ ký, không parse |
| **B8** | `modules/user` | `modules/user/**` | CRUD + list phân trang; mọi method nhận actor + kiểm quyền |
| **B9** | `ERR_AUTH_INVALID_CREDENTIALS` + quy ước tên permission | `docs-erp/04-conventions/*`, `shared/errors/` | `check-ids` xanh; hằng khớp bảng C-API-05 |
| **B10** | `cmd/api` ghép lại | `cmd/api/*.go` | Đăng nhập được thật, end-to-end |
| **B11** | Docs module + đăng ký C-API-07 + chạy checklist | `modules/*/docs/`, `docs-erp/04-conventions/C-API-http.md` | Đủ 5 file mỗi module |

---

## Cuối chặng — người điều phối làm, không giao agent

1. `go run ./cmd/dev arch-update` sinh lại `arch/LEVELS.md`, **đọc diff** — bảy dòng
   `PASS tren tap RONG` phải biến mất, và không dòng nào bị hạ mức ngoài dự kiến.
2. `go generate ./arch/...` + `git diff --exit-code`.
3. `go run ./cmd/dev check` rồi `test`.
4. Chạy `CL-NEWMOD-new-module.md` và `CL-API-new-endpoint.md` **bằng mắt** cho từng module —
   năm mục không có checker nào canh (cây thư mục, chu trình `allowed_deps`, 5 file docs,
   test cho mỗi method public) chỉ có người kiểm được.
5. Đẩy lên GitHub, đợi CI ba job xanh.

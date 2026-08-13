# Chặng E — Implementation Plan

> **Spec:** [2026-08-13-chang-e-frontend-design.md](2026-08-13-chang-e-frontend-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách bốn chặng trước đã chạy.

**Goal:** Sửa màn báo sự cố để gửi `repair_cost` do frontend nhân ra, chạy bộ canh, và có thứ gì đó đỏ đúng dòng đó.

---

## Đồ thị phụ thuộc

Hai nhánh chạy song song từ đầu và chỉ gặp nhau ở DOT 5. Nhánh backend và nhánh frontend
nằm ở **hai repo khác nhau**, nên chúng không thể đụng file của nhau — đây là chặng đầu
tiên có tính chất đó, và nó là thứ cho phép fan-out rộng hơn ba chặng trước.

```
DOT 1 (song song, 5 agent):
  E1  hop dong 422: Fields trong shared/errors + response.Error   backend-erp/shared/
  E2  GET /auth/me + permission auth.self_read                    backend-erp/modules/auth/, cmd/
  E3  CORS middleware                                             backend-erp/shared/middleware/, cmd/
  E4  ADR-0011, ADR-0012 + keo theo C-API-05, C-TS-04/05/06       docs-erp/
  E7  khung frontend-erp: vite + ts + alias + CI                  frontend-erp/

DOT 2 (sau E1):
  E5  chin call site apperr.ValidationFailed gan ten field        backend-erp/modules/
  E6  BindFailed 422-co-field + ngay sang chuoi + chiPhiTuChuoi   backend-erp/shared/, modules/machine/

DOT 2' (sau E7, song song voi DOT 2):
  E8  shared/api/client.ts + types envelope                       frontend-erp/src/shared/
  E9  tam luat eslint + fixture hai chieu                         frontend-erp/eslint-rules/

DOT 3 (sau E9):
  E10 runner arch.mjs + arch/LEVELS.md + job 'arch' trong CI      frontend-erp/scripts/, arch/

DOT 4 (sau E8):
  E11 man dang nhap + refresh                                     frontend-erp/src/modules/auth/
  E12 man danh sach may, bo loc song o URL                        frontend-erp/src/modules/machine/
  E13 man chi tiet + sua may, tô ô theo error.fields              frontend-erp/src/modules/machine/
  E14 man bao su co — man co truong tien                          frontend-erp/src/modules/machine/

DOT 5 (sau tat ca):
  E15 docs frontend + e2e that qua trinh duyet
```

**E9 không chờ E11-E14.** Luật viết trên fixture của chính nó, không trên code sản phẩm —
đó là cách `arch/` của backend làm từ chặng A, và nó là lý do luật đứng vững trước khi
có code thật để soi. Ngược lại, **E10 phải sau E9**: runner không có gì để chạy khi chưa
có luật, và một bảng mức sinh từ tập luật rỗng là đúng cái ta đang tránh.

**E11-E14 không chờ nhánh backend merge.** Chúng viết theo hợp đồng đã chốt ở mục 4-5 của
spec. Chỉ E15 mới cần cả hai nhánh có thật.

**E5 phải sau E1** và không được gộp vào: E1 mở đường cho field đi từ service lên envelope,
E5 đi qua chín chỗ gắn tên. Gộp lại thành một task là một agent sửa chín file nghiệp vụ
cùng lúc với việc đổi hình dạng một kiểu ở `shared/` — hai loại rủi ro khác nhau trong
một lần review.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test phạm vi của mình.** Không `go build ./...`, không `npm run build` toàn repo — agent khác đang viết dở, và lỗi biên dịch của người khác không phải tín hiệu về việc mình đúng hay sai.
2. **Không sửa file ngoài phạm vi task.** `backend-erp/**` chỉ E1, E2, E3, E5, E6 được chạm; `frontend-erp/**` chỉ E7-E15; `docs-erp/**` chỉ E4.
3. **Không chạy `go test ./arch -update`, `arch-pin`, hay runner sinh `LEVELS.md`.** Cả hai golden file do người điều phối sinh lại một lần ở cuối.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code — theo đúng mật độ và giọng của `modules/auth`. Áp cho cả `.ts`/`.tsx`.
5. **Tiền không bao giờ đi qua `float64`, và ở TypeScript không bao giờ đi qua `number`.** `number` trong JavaScript *là* `float64`. `repair_cost` là chuỗi từ ô input tới thân request; không `parseFloat`, không `Number()`, không phép toán nào chạm nó.
6. `shared/errors` **cấm import `shared/response`** — kiểu đựng field phải là kiểu của `shared/errors`, `response` tự ánh xạ. Đọc dòng 1-11 của `errors.go` trước khi gõ.
7. Mọi method public của service nhận `actor auth.Actor` làm tham số thứ hai và mở đầu bằng `s.authz.Can` — không dòng nào đứng trước, kể cả `/me`.
8. **Mỗi luật ESLint phải có fixture hai chiều**: ít nhất một ca vi phạm phải bị bắt, ít nhất một ca hợp lệ không được bắt oan. Luật không có fixture vi phạm là task **chưa xong**, không phải task xanh.
9. **Ba ngoại lệ không được bắt oan** (spec mục 6): đường dẫn v2, số tạm tính render ra JSX, nút không kiểm quyền gì cả.
10. Không hàm nào trong `src/**/api/` trả `any`.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **E1** | Kiểu đựng field trong `shared/errors`; `response.Error` ánh xạ sang `response.FieldError` | `shared/errors/errors.go`, `shared/response/response.go` | `shared/errors` không import `shared/response`; 24 call site của `response.Error` không đổi một dòng |
| **E2** | `GET /api/v1/auth/me` + permission `auth.self_read` cấp cho cả ba vai trò | `modules/auth/internal/{service,handler}/`, `cmd/internal/vaitro/` | Method mở đầu bằng `s.authz.Can`; không token → `401`; token hợp lệ → đúng người đăng nhập |
| **E3** | CORS middleware, origin từ cấu hình | `shared/middleware/cors/`, `cmd/api/router.go`, `main.go` | Không `*` trên đường có `Authorization`; preflight `OPTIONS` trả đúng; origin lạ bị từ chối |
| **E4** | ADR-0011 (TanStack Query), ADR-0012 (R-19 canh ở frontend-erp); kéo theo C-API-05, C-TS-04/05/06 | `docs-erp/03-decisions/`, `04-conventions/` | `check-ids.ps1` xanh; ADR-0012 ghi rõ điều kiện mở lại; `RULES.md` không đổi một chữ |
| **E5** | **Mười** call site `apperr.ValidationFailed` gắn tên field (đếm bằng grep, không tin con số trong văn xuôi) | `modules/machine/internal/service/{breakdown_service,errors,machine_service}.go`, `modules/auth/internal/service/user_service.go` | Mỗi `422` có `fields`; bốn dòng `dichViPhamCheck` có comment nói rõ tên field là ước lệ |
| **E6** | `BindFailed` nhận `*json.UnmarshalTypeError` → `422` có field; `planned_date`/`commissioned_date` bind thành chuỗi; `chiPhiTuChuoi` chặn khoảng trắng. **Bẫy trên đường của bạn:** `FieldErrors(err)` hiện trả về một phần tử `Field: ""` cho mọi lỗi không phải `validator.ValidationErrors`. Đi qua nhánh đó thì response có đúng status, đúng số phần tử, và **tên ô rỗng** — đúng hình dạng im lặng mà comment trong `fielderrors.go` nói đã sống sót qua chặng B và C. Phải lấy tên ô từ `UnmarshalTypeError.Field` một cách tường minh | `shared/response/{response,fielderrors}.go`, `modules/machine/internal/handler/` | `"repair_cost":1500000` → `422` có field; `"planned_date":"01/09/2026"` → `422` có field; `"  "` → `422`; `""` và vắng mặt → `0.0000`; JSON hỏng cú pháp và body rỗng vẫn `400` **không** fields; `page=abc` vẫn `400` |
| **E7** | Khung `frontend-erp`: Vite + TypeScript + alias `@/` + `.github/workflows/ci.yml` | `frontend-erp/{package.json,tsconfig.json,vite.config.ts,.github/}` | Alias khai đúng một lần ở `tsconfig` và bundler; CI có job `lint` chạy được trên repo gần rỗng |
| **E8** | `shared/api/client.ts` — bóc envelope đúng một lần; `types.ts` cho `Envelope`/`Meta`/`ApiErrorBody` | `frontend-erp/src/shared/api/` | `/api/v1` xuất hiện đúng một chỗ; `request_id` không optional; component không bao giờ thấy `.data` |
| **E9** | Tám luật ESLint + fixture hai chiều cho từng luật | `frontend-erp/eslint-rules/**` | Bảng tám luật ở spec mục 6 đủ tám; ba ngoại lệ mục 6 không bắt oan; mỗi luật có cả ca đỏ lẫn ca xanh |
| **E10** | Runner `arch.mjs`, `arch/rules.mjs`, `arch/LEVELS.md`, job `arch` trong CI | `frontend-erp/{scripts,arch}/`, `.github/workflows/ci.yml` | Ba mệnh đề khai báo được thi hành: `FULL`→`Unverifiable` rỗng, `PARTIAL`/`NA`→khác rỗng, **luật không fixture vi phạm = `FAIL`**; bảng cùng văn phạm với `backend-erp/arch/LEVELS.md`. **Ba bàn giao từ E9, đọc trước khi viết runner:** (1) bảng luật đọc từ `export const rules` trong `eslint-rules/index.js`, **không** glob `eslint-rules/*.js` — `lib/` và `index.js` không phải luật; (2) fixture dùng chỉ thị `// @erp-path: <duong-dan>` để giả lập vị trí trong `src/`, và chỉ thị đó chỉ có hiệu lực dưới `__fixtures__/` — runner đặt filename ảo khác sẽ làm sai chiều hợp lệ của bốn luật; (3) `vi-pham` chạy **một** luật của nó, `hop-le` chạy **cả tám** — chạy chéo sẽ đếm sai, vì một ca `axios.post` vi phạm đồng thời hai luật |
| **E11** | `index.html`, `src/main.tsx`, `src/app/` (router + provider + layout chung); màn đăng nhập, lưu token, luồng refresh | `frontend-erp/{index.html,src/app/**,src/main.tsx}`, `src/modules/auth/**` | `npm run dev` và `npm run build` chạy được — hôm nay chúng **không** chạy được vì bản đầu của plan này không giao entry point cho ai; `401` không đá người dùng ra giữa chừng khi refresh còn hạn |
| **E12** | Màn danh sách máy: phân trang, lọc `status`, sắp xếp | `frontend-erp/src/modules/machine/pages/` | Bộ lọc và trang sống ở **URL**, không ở `useState`; đọc `meta.total`, không suy từ `array.length` |
| **E13** | Màn chi tiết + form sửa máy, tô ô theo `error.fields` | `frontend-erp/src/modules/machine/**` | `assigned_to` sai → `422`, form tô đúng ô; `403` không đăng xuất, không tự thử lại, không màn trắng |
| **E14** | Màn báo sự cố — màn có trường tiền | `frontend-erp/src/modules/machine/**` | `repair_cost` là chuỗi từ input tới body; không `parseFloat`/`Number()` chạm nó; số tạm tính (nếu hiện) không đi vào request |
| **E16** | Nợ tài liệu và một lỗi 500, gom từ đợt 2 | `docs-erp/04-conventions/C-API-http.md`, `docs-erp/03-decisions/ADR-0012-*`, `backend-erp/modules/auth/internal/service/auth_service.go` | (1) C-API-02/05 phải nói rõ: `*json.UnmarshalTypeError` có `Field == ""` (thân request là mảng/chuỗi/số thay vì object) thì **ở lại 400** — nếu không, mệnh đề "422 luôn có fields" tự mâu thuẫn; (2) ghi nợ: `UnmarshalTypeError.Field` cho `items.quantity` **không có chỉ số**, trong khi `FieldErrors` hứa `items.0.quantity` — chưa có hậu quả vì chưa DTO nào có mảng-của-object, nhưng phải có tên trước khi có; (3) ADR-0012 ghi tập sink của `r19-*` rộng hơn danh sách trong "Dấu hiệu vi phạm" của R-19, kèm lý do; (4) `AuthService.ChangePassword` dịch `bcrypt.ErrPasswordTooLong` thành `422` kèm field `new_password` — hôm nay nó ra **500** cho một mật khẩu tiếng Việt 40 ký tự |
| **E15** | Docs frontend + e2e thật qua trình duyệt | `frontend-erp/docs/`, e2e | Đăng nhập → danh sách → chi tiết → báo sự cố, chạy trong trình duyệt thật với backend thật qua CORS |

---

## Cuối chặng — người điều phối làm, không giao agent

1. **Phép thử của chính mục tiêu.** Sửa `E14` để gửi `repair_cost` do frontend nhân ra, chạy bộ canh, xác nhận **đỏ đúng dòng đó**, hoàn lại. Rồi chiều ngược lại: render một con số tạm tính ra JSX mà không gửi đi, xác nhận **không luật nào đỏ**. Một luật chỉ đỏ đúng chỗ mới là luật; đỏ mọi chỗ là một luật sẽ bị tắt trong tháng đầu.
2. **Phép thử của bộ canh.** Xóa thư mục fixture vi phạm của một luật bất kỳ, chạy runner, xác nhận luật đó ra **`FAIL`** chứ không phải `PASS`. Đây là mệnh đề duy nhất ngăn bảng mức mới mục theo đúng cách bảng cũ suýt mục ở chặng A.
3. **Ba ngoại lệ.** `/api/v2/orders` không đỏ, `/api/v1/orders` đỏ. Nút không kiểm quyền không đỏ, `disabled={role !== 'admin'}` đỏ. Import `@/modules/auth/api` không đỏ, `@/modules/auth/hooks/...` đỏ.
4. **Hợp đồng lỗi, kiểm từ đầu kia của dây.** Không phải bằng test Go, mà bằng form thật: gõ `assigned_to` sai và xem ô có được tô không; gõ `  ` vào ô chi phí và xem có bị chặn không.
5. `go run ./cmd/dev arch-update` sinh lại `backend-erp/arch/LEVELS.md`, **đọc diff** — `R-19` vẫn `N/A / N/A / chua chay`, và cột `Unverifiable` trong `README.md` giờ trỏ đích danh sang `frontend-erp`. Không dòng nào hạ mức.
6. `go generate ./arch/...` + `git diff --exit-code`.
7. `go run ./cmd/dev check` rồi `test`.
8. Chạy `CL-API-new-endpoint.md` **bằng mắt** cho `/auth/me`, và `CL-PR-*` cho cả hai repo. Chặng B và C đều cho thấy mục không có checker nào canh vẫn bắt được lỗi thật.
9. Đẩy cả ba repo, đợi CI xanh — `backend-erp` ba job, `frontend-erp` hai job (`lint`, `arch`).

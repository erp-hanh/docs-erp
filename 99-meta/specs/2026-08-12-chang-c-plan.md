# Chặng C — Implementation Plan

> **Spec:** [2026-08-12-chang-c-machine-design.md](2026-08-12-chang-c-machine-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách chặng B đã chạy.

**Goal:** `modules/machine/module.yaml` khai `allowed_deps: [auth]`, và đổi nó thành `[]` thì `go run ./cmd/dev arch` đỏ.

---

## Đồ thị phụ thuộc

```
DOT 1 (song song, 4 agent):
  C1  ma loi ERR_MACHINE_* + bang C-API-05       shared/errors/ + docs-erp/
  C2  migration ba bang                          migrations/00000{6,7,8}_*
  C3  auth/api: interface UserReader + cua ra     modules/auth/
  C4  dang ky C-API-07 bang 1 + va hai checklist  docs-erp/

DOT 2 (sau C2):
  C5  model + ba repository                      modules/machine/internal/{model,repository}/

DOT 3 (sau C1, C3, C5):
  C6  MachineService                             modules/machine/internal/service/machine_service.go
  C7  MaintenanceService + bang chuyen trang thai modules/machine/internal/service/maintenance_service.go
  C8  BreakdownService                           modules/machine/internal/service/breakdown_service.go

DOT 4 (sau DOT 3):
  C9  handler + route ba nhom
  C10 module.go + module.yaml + vaitro + ghep o cmd/api

DOT 5:
  C11 docs module (5 file) + e2e lien module
```

**Thứ tự C6/C7:** `MaintenanceService.StartPlan` đổi `machines.status` trong cùng transaction với `maintenance_plans.status`, nên nó cần `MachineRepository` — **không** cần `MachineService`. Hai service không gọi nhau (`internal_methods` rỗng); chúng dùng chung repository. Làm C6 trước để hình dạng repository chốt xong, rồi C7.

**C3 phải xong trước C6:** `MachineService.CreateMachine` gọi `UserReader.GetByID` để kiểm người phụ trách. Agent làm C6 khai interface đó ở phía người dùng (C-GO-02) và nhận qua tham số, nên nó biên dịch được trước khi C3 merge — nhưng ca end-to-end thì không chạy được.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test package của mình**, không chạy `go build ./...` — các agent khác đang viết dở package khác, và một lỗi biên dịch của người khác không phải tín hiệu về việc mình làm đúng hay sai.
2. **Không sửa file ngoài phạm vi task.** Trùng file giữa hai agent là hỏng. Riêng chặng này: `modules/auth/**` chỉ C3 được chạm, `cmd/**` chỉ C10 được chạm.
3. **Không chạy `go test ./arch -update` hay `arch-pin`** — golden file do người điều phối sinh lại một lần ở cuối.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code — theo đúng mật độ và giọng của `modules/auth`.
5. **Tiền không bao giờ đi qua `float64`**, kể cả trong test: cột `NUMERIC(18,4)`, Go là `decimal.Decimal`, JSON là **chuỗi**.
6. Mọi method public của service nhận `actor auth.Actor` làm tham số thứ hai và mở đầu bằng `s.authz.Can` — không dòng nào đứng trước.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **C1** | Ba mã `ERR_MACHINE_*` + ba dòng bảng C-API-05 + bảng ánh xạ constraint | `shared/errors/codes.go`, `docs-erp/04-conventions/C-API-http.md` | `check-ids.ps1` xanh; hằng khớp bảng từng ký tự |
| **C2** | Migration ba bảng | `migrations/00000{6,7,8}_*.{up,down}.sql` | `cmd/dev test` xanh; R-06/R-08/R-09/R-17/R-18 xanh trên migration mới; `down` lùi đúng thứ tự ngược |
| **C3** | `UserReader` ở `auth/api` + cửa ra ở `auth/module.go` | `modules/auth/api/user_reader.go`, `modules/auth/module.go` | Không tên `Internal*` nào lọt vào `api/`; C-GO-05 vế 5 xanh |
| **C4** | Ba dòng `/actions/*` vào C-API-07 bảng 1; sửa `CL-PR-14`/`CL-API-17` trỏ C-TS-05/C-TS-06 | `docs-erp/04-conventions/C-API-http.md`, `docs-erp/06-checklists/*` | Mỗi endpoint một dòng kèm lý do và ngày duyệt |
| **C5** | Ba model + ba repository | `modules/machine/internal/{model,repository}/**` | SQL là hằng chuỗi đơn (C-GO-07); mọi câu kèm `company_id = $n` và `deleted_at IS NULL` |
| **C6** | `MachineService` — 5 method CRUD + kiểm người phụ trách | `modules/machine/internal/service/machine_service.go` + test | Gán user không tồn tại → `422 ERR_MACHINE_ASSIGNEE_INVALID`; user công ty khác → **cùng mã đó** |
| **C7** | `MaintenanceService` — 4 CRUD + 3 action, bảng chuyển trạng thái | `modules/machine/internal/service/maintenance_service.go` + test | `start` hai lần → `409`; `start` đổi `machines.status` trong **cùng** transaction; rollback thì cả hai bảng nguyên vẹn |
| **C8** | `BreakdownService` — ghi và đọc nhật ký sự cố | `modules/machine/internal/service/breakdown_service.go` + test | `repair_cost` đi qua `decimal.Decimal`, không `float64` ở bất kỳ đâu |
| **C9** | Ba handler + ba file route | `modules/machine/internal/handler/**` | Route dưới `/api/v1` do composition root dựng; mọi đường ra qua `shared/response`; `BindFailed` cho mọi lỗi bind |
| **C10** | `module.go`, `module.yaml`, permission vào `cmd/internal/vaitro`, ghép ở `cmd/api` | `modules/machine/module.{go,yaml}`, `cmd/**` | `allowed_deps: [auth]`; đổi thành `[]` thì `arch` đỏ |
| **C11** | Năm file docs của module + ca end-to-end liên module | `modules/machine/docs/**`, `cmd/api/e2e_test.go` | `Database.md` khớp từng dòng `tables`; e2e chạy hết vòng đời một kế hoạch bảo trì |

---

## Cuối chặng — người điều phối làm, không giao agent

1. **Phép thử của chính mục tiêu:** đổi `allowed_deps` của `machine` thành `[]`, chạy `go run ./cmd/dev arch`, xác nhận **đỏ**, rồi hoàn lại. Làm tương tự với một `import "erp/modules/auth/internal/service"` và một câu SQL nêu tên `users` trong repository của `machine`. Ba phép thử này là thứ duy nhất chứng minh sáu vế rule ở mục 1 của spec đã thật sự sống.
2. `go run ./cmd/dev arch-update` sinh lại `arch/LEVELS.md`, **đọc diff** — chỉ cột FILE được tăng, không dòng nào hạ mức.
3. `go generate ./arch/...` + `git diff --exit-code`.
4. `go run ./cmd/dev check` rồi `test`.
5. Chạy `CL-NEWMOD-new-module.md`, `CL-SCHEMA-schema-change.md` và `CL-API-new-endpoint.md` **bằng mắt**. Năm mục không có checker nào canh chỉ có người kiểm được, và chặng B đã cho thấy chúng bắt được lỗi thật.
6. Đẩy lên GitHub, đợi CI ba job xanh.

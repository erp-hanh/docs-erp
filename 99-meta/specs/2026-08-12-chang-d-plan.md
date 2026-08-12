# Chặng D — Implementation Plan

> **Spec:** [2026-08-12-chang-d-outbox-relay-design.md](2026-08-12-chang-d-outbox-relay-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách chặng B và C đã chạy.

**Goal:** Xóa một user đang phụ trách một máy, đợi relay chạy, đọc lại máy — `assigned_to` là `NULL`. Gửi lại đúng event đó lần thứ hai thì không đổi gì thêm.

---

## Đồ thị phụ thuộc

```
DOT 1 (song song, 3 agent):
  D1  migration outbox + idempotency_keys      migrations/00001{0,1}_*
  D2  shared/outbox + shared/outbox/events     shared/outbox/
  D3  shared/idempotency                       shared/idempotency/

DOT 2 (sau D2):
  D4  shared/bus - pub/sub trong tien trinh    shared/bus/

DOT 3 (sau D1, D2):
  D5  auth.DeleteUser ghi outbox trong cung tx modules/auth/

DOT 4 (sau D1, D3, D4):
  D6  relay/ - vong lap, FOR UPDATE SKIP LOCKED  relay/
  D7  subscriber cua machine                     modules/machine/internal/subscriber/

DOT 5:
  D8  cmd/relay - composition root thu ba
  D9  go Optional[relay] o loader.go, cap nhat docs Events.md hai module
  D10 e2e: xoa user -> relay -> assigned_to NULL, va gui lai lan hai
```

**Thứ tự D6/D7:** relay không biết gì về module; nó publish ra bus và dừng lại. Subscriber
đăng ký vào bus ở `cmd/relay`, không ở `relay/`. Hai task độc lập nhau, chỉ gặp nhau ở D8.

**`TestOptionalRootStaysHonest` sẽ đỏ ở D6** — ngay khi `relay/` có file `.go` đầu tiên.
Đó là cơ chế nổ đúng lúc; D9 xử nó bằng cách **gỡ khai báo**, không bằng cách nới điều kiện.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test package của mình**, không chạy `go build ./...` — trừ D8, task ghép.
2. **Không sửa file ngoài phạm vi task.** Riêng chặng này: `relay/` chỉ D6 chạm, `cmd/**`
   chỉ D8 chạm, `arch/**` chỉ D9 chạm.
3. **Không chạy `go test ./arch -update` hay `arch-pin`** — golden file do người điều phối
   sinh lại, sau khi đọc diff.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** — theo đúng giọng của
   `modules/auth` và `modules/machine`.
5. **`event_id` sinh đúng một lần**, lúc service ghi hàng outbox. Không nơi nào khác được
   sinh nó — relay gửi lại phải mang đúng chuỗi cũ, nếu không dedupe phía consumer mất tác
   dụng đúng lúc nó cần nhất.
6. **Dedupe là câu lệnh đầu tiên** của thân handler, và nó chạy trong **chính** transaction
   của hiệu ứng.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **D1** | Migration `outbox` + `idempotency_keys` | `migrations/00001{0,1}_*.{up,down}.sql` | Cả hai thuộc `append_only_tables`: có `created_by`, **không** `updated_*`/`deleted_at`; index outbox là partial `WHERE published_at IS NULL` và **không** dẫn đầu bằng `company_id` |
| **D2** | `shared/outbox` — `Event`, `Repository`, hằng `EventType` | `shared/outbox/**` + test | `Append` nhận `DBTX`; hằng tên event ở package riêng; không import `modules/` (R-04) |
| **D3** | `shared/idempotency` — `Claim` | `shared/idempotency/**` + test | `INSERT ... ON CONFLICT DO NOTHING`; gọi hai lần cùng khóa → lần hai trả `false`, không lỗi |
| **D4** | `shared/bus` — pub/sub trong tiến trình | `shared/bus/**` + test | Đăng ký nhiều handler cho một event; handler lỗi không nuốt im lặng |
| **D5** | `DeleteUser` ghi outbox trong cùng `tx` | `modules/auth/internal/service/user_service.go` + test | Bỏ lời gọi `Append` → có test đỏ; rollback thì **không** hàng outbox nào còn lại |
| **D6** | `relay/` — vòng lặp, `FOR UPDATE SKIP LOCKED` | `relay/**` + test | Hai bản relay chạy song song không gửi trùng; `Publish` lỗi → `break` cả batch, hàng vẫn `published_at IS NULL` |
| **D7** | Subscriber của `machine` | `modules/machine/internal/subscriber/**` + test | Câu lệnh đầu là claim khóa; gọi hai lần cùng `event_id` → hiệu ứng chỉ một lần, cả hai lần trả thành công |
| **D8** | `cmd/relay` — composition root thứ ba | `cmd/relay/**`, `cmd/dev` | Dựng module để **tiêu thụ**, không đăng ký route nào; `cmd/dev dev` chạy cả hai tiến trình hoặc nói rõ nó không chạy relay |
| **D9** | Gỡ `Optional[relay]`, cập nhật `Events.md` hai module | `arch/internal/loader/loader.go`, `modules/*/docs/Events.md` | `TestOptionalRootStaysHonest` xanh **vì đã gỡ khai báo**, không vì nới điều kiện |
| **D10** | E2E: xóa user → relay → `assigned_to` NULL | `cmd/api/e2e_test.go` hoặc test riêng | Gửi lại đúng event lần hai không đổi gì thêm, và không có hàng `idempotency_keys` thứ hai |

---

## Cuối chặng — người điều phối làm, không giao agent

1. **Phép thử của chính mục tiêu:** bỏ lời gọi `Append` khỏi `DeleteUser` → phải có test
   đỏ. Bỏ bước claim khóa khỏi subscriber → phải có test đỏ. Hai phép thử này là thứ duy
   nhất chứng minh outbox và idempotency đang canh thật.
2. `go run ./cmd/dev arch-update`, **đọc diff** — chỉ cột FILE được tăng, không dòng nào
   hạ mức. Chú ý R-05: vế 3 nay có code thật, nên `Unverifiable` của nó phải được đọc lại.
3. `go generate ./arch/...` + `git diff --exit-code`.
4. `go run ./cmd/dev check` rồi `test`.
5. Chạy `CL-NEWMOD`, `CL-SCHEMA` và `CL-PR-code-review` **bằng mắt**. Chặng C cho thấy
   chúng bắt được lỗi thật mà không checker nào thấy.
6. Đẩy lên GitHub, đợi CI ba job xanh.

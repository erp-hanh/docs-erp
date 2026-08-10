# START HERE

## 1. Hệ thống này là gì

ERP modular monolith cho doanh nghiệp cơ khí và cảng, viết bằng Go (Gin + pgx/sqlx)
và React, dữ liệu trên PostgreSQL. Kiến trúc multi-tenant-ready: mọi bảng nghiệp vụ
có `company_id`, nhưng vận hành single-tenant trước, dùng chung một database.
Hệ thống không tích hợp IoT/PLC — Machine và Kalmar là module CRUD thường.

## 2. Bản đồ tài liệu

| Tầng | Vai trò | Ở đâu |
|---|---|---|
| **RULES** | What must be true — bắt buộc, kiểm được | `01-rules/` |
| **PRINCIPLES** | How we reason — cách suy luận khi áp dụng Rules | `02-principles/` |
| **DECISIONS** | Why we chose this — bất biến theo thời điểm | `03-decisions/` |
| **CONVENTIONS** | How we consistently implement it | `04-conventions/` |
| **CHECKLISTS** | How we verify it | `06-checklists/` |

Quan hệ giữa chúng:

```
        CONVENTIONS ──┐
Code ───┤             ├──> RULES ──> PRINCIPLES ──> DECISIONS
        CHECKLISTS ───┘
```

CONVENTIONS nằm giữa Rule và Code, không nối tiếp sau Rule: Rule nói *"FK phải có
index"*, Convention nói *"tên index là `idx_<table>_<cols>`"*. CHECKLISTS cắt ngang,
kiểm cả Rule lẫn Convention.

Mọi thứ đều có ID ổn định (`R-05`, `P-TXN`, `ADR-0006`, `C-DB-01`, `CL-NEWMOD-01`)
và trường link ngược. Báo một vi phạm chỉ cần nêu ID là tra ngược được toàn chuỗi.

## 3. Tôi cần làm X thì đọc gì

| Việc | Đọc theo thứ tự |
|---|---|
| Thêm module mới | `06-checklists/CL-NEWMOD-new-module.md` → R-01..R-05 → `04-conventions/C-GO-backend.md` → `05-templates/module-docs/` |
| Sửa schema | `06-checklists/CL-SCHEMA-schema-change.md` → R-06..R-09 → `04-conventions/C-DB-database.md` |
| Thêm endpoint | `06-checklists/CL-API-new-endpoint.md` → R-10..R-13 → `04-conventions/C-API-http.md` |
| Review PR | `06-checklists/CL-PR-code-review.md` |
| Không hiểu vì sao có quy tắc này | `03-decisions/` |

## 4. Khi xung đột

```
Rules > Principles > Conventions > existing code
```

Hai quy tắc bắt buộc, áp dụng cho cả người lẫn AI:

> **Nếu hai Rule mâu thuẫn nhau thì DỪNG LẠI và hỏi người. Không tự chọn bên.**
> Tự diễn giải một lần là tạo tiền lệ sai cho mọi lần sau.

> **Khi Principle thắng Convention trong một ca cụ thể, BẮT BUỘC mở issue sửa Convention.**
> Thứ tự ưu tiên là chỉ dẫn tạm thời cho tới khi tầng dưới được sửa cho khớp,
> không phải giấy phép bỏ qua nó.

`existing code` đứng cuối vì nó là thứ có thể sai và phải sửa. Code hiện có không
bao giờ là lý do để vi phạm Rule.

## 5. 30 phút đầu của người mới

1. Đọc mục 1–4 của file này (5 phút)
2. Đọc `01-rules/RULES.md` từ đầu đến cuối (15 phút) — không cần nhớ, chỉ cần biết có gì
3. Đọc `03-decisions/README.md` để nắm các quyết định nền (5 phút)
4. Mở checklist ứng với việc đầu tiên bạn sắp làm (5 phút)

Chưa cần đọc `02-principles/` và `04-conventions/` ngay — tra khi cần.

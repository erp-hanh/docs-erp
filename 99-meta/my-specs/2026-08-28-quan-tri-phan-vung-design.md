# Thiết kế: màn Quản trị phân vùng chạy số liệu thật

Ngày: 2026-08-28. Trạng thái: đã duyệt, đang thi công backend.

Quyết định nền: [ADR-0039](../../03-decisions/ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md)
(mỗi phân vùng đúng một người quản trị) và
[ADR-0040](../../03-decisions/ADR-0040-doc-cheo-phan-vung-neo-vao-companies.md) (đọc chéo phân
vùng neo vào `companies.id`). Hai ADR đó giữ phần *vì sao*; file này chỉ nói *làm gì*.

## 1. Vấn đề

Mặt "Quản trị" của màn Phân vùng đang chạy một nửa dữ liệu giả, và tự khai điều đó bằng hai
dải cảnh báo. Ba lỗ thủng đo được:

| # | Lỗ | Bằng chứng |
|---|---|---|
| 0 | Cột "Số người dùng" **đếm sai** | `countActiveUsersOfCompanySQL` lọc `users.company_id` — nơi tài khoản được tạo — chứ không lọc `user_companies` — nơi người đó đang làm |
| 1 | Cột "Người quản trị" là dữ liệu giả | `quan-tri-phan-vung-mau.ts`, ba dòng cứng khóa theo `code` |
| 2 | Không xem được ai đang ở trong một phân vùng | `GET /users` luôn lọc theo `actor.CompanyID` |
| 3 | Phân vùng tạo ra thì rỗng người | `CreateCompany` chỉ chèn `companies` + nạp vai trò mặc định |

Lỗ 0 là lỗi, ba lỗ còn lại là việc chưa làm.

## 2. Phạm vi

Backend trước, frontend sau — mọi lỗ đều bị chặn ở backend. File này tả **backend**; frontend
có plan riêng sau khi backend lên `main`.

**Ngoài phạm vi:** phân vùng nhiều cấp (ADR-0033 còn `Proposed`), kiêm nhiệm nhiều phân vùng
(có spec riêng), và tách phân vùng thành module backend riêng — việc cuối không đáng làm, nó
đòi một ADR sửa ADR-0017 và người dùng không thấy gì khác trên màn hình.

## 3. Bốn phần việc

### P0 — sửa phép đếm người (lỗi)

`countActiveUsersOfCompanySQL` đổi từ `users.company_id = $1` sang `JOIN user_companies` như
hình dạng mà đính chính ADR-0034 ngày 2026-08-28 đã áp cho `UserRepository`. Câu sau khi sửa
chính là câu P2 cần, nên làm nó trước là rẻ nhất.

### P1 — người quản trị

- Migration: `user_companies.is_admin BOOLEAN NOT NULL DEFAULT false` + partial unique index
  `uq_user_companies_admin ON user_companies(company_id) WHERE is_admin AND deleted_at IS NULL`.
- Backfill trong cùng migration: đánh dấu **chỉ khi** phân vùng có đúng một người giữ
  `auth.role_assign`. Không đoán ở ca 0 người hoặc 2+ người (ADR-0039 mục 5).
- `GET /companies/:id/admin` → người quản trị, hoặc rỗng.
- `PUT /companies/:id/admin` → đặt người quản trị. Kiểm: người đó là thành viên phân vùng đó,
  và đang giữ `auth.role_assign` (ADR-0039 mục 4).
- Cửa "ít nhất một": `GoKhoiPhanVung` và `ThayVaiTro` từ chối khi thao tác làm phân vùng mất
  người quản trị duy nhất. Một nửa cửa này đã có (`DemNguoiGiuQuyen`).

`PUT` là đường **ghi** nên nó **không** đi qua ADR-0040 — nó ghi vào `user_companies` của
đúng phân vùng đang được trỏ, và giá trị `company_id` là `companies.id` đọc ra từ path. Vế
này ADR-0040 cố ý không cấp; nó được cấp bởi ADR-0039, vốn đặt ra chính khái niệm người quản
trị và nói người đặt phải giữ `auth.company_update`.

### P2 — người trong một phân vùng

`GET /companies/:id/users` — phân trang, sort, lọc theo hình dạng của `GET /users` sẵn có.
Đi qua ADR-0040: chỉ đọc, neo vào `companies.id`, gác bằng `auth.company_read` là câu lệnh
đầu tiên rồi mới tới `auth.user_list`.

Đường lùi nếu ADR-0040 bị bỏ: bắt quản trị hệ thống đổi phân vùng rồi dùng `GET /users` — tốn
0 dòng backend, ghi ở Alternatives của ADR-0040.

### P3 — tạo phân vùng kèm người quản trị đầu tiên

`POST /companies` nhận thêm khối người quản trị. Một transaction, sáu lần ghi:
`companies` → `roles` (bộ mặc định, đã có) → `users` → `user_companies` (`is_admin = true`) →
`user_company_roles` (`auth.admin`) → hai dòng audit (`company.created`, `user.created`).

Ba điều phải giữ:
- bcrypt chạy **ngoài** transaction (P-TXN, khuôn có sẵn ở `user_service.go`);
- email đã tồn tại toàn hệ thì **mời người đã có** vào phân vùng mới, không trả 409 —
  `uq_users_email_active` nay là toàn hệ (ADR-0034 mục 1);
- kiểm cờ `is_system` trên bộ 7 vai trò của phân vùng mới (nợ đã ghi ở ADR-0038).

## 4. Cách biết là đúng

| Lớp | Kiểm gì |
|---|---|
| `go run ./cmd/dev check` | 19 Rule, không cần Docker. R-06 vế DTO/handler phải vẫn xanh — ADR-0040 cố ý không nới hai vế đó |
| Test không cần database | phép dịch lỗi, phép kiểm đầu vào, các cửa chặn ở service |
| Test có database (CI) | migration lên/xuống chạy được; partial unique index thật sự từ chối người quản trị thứ hai; backfill đánh dấu đúng ca một người và bỏ qua ca 0/2+ |
| CI trên `main` | job `test` xanh — đây là bằng chứng duy nhất cho phần cần database |

**Bài kiểm quan trọng nhất:** một test chèn hai hàng `is_admin = true` cùng một `company_id`
phải **đỏ ở tầng database**, không phải đỏ vì service chặn. Đó là toàn bộ lý do ADR-0039 chọn
ràng buộc thay vì một luật.

## 5. Dây chuyền phải nhớ khi merge

Đợt này chạm `RULES.md` (thêm `ADR-0040` vào dòng `Decisions` của R-06), nên:

1. `backend-erp` phải chạy `go run ./cmd/dev arch-pin` và commit lại băm ghim;
2. `docs-erp` phải lên `main` **trước** `backend-erp`, vì job `arch` của backend checkout
   `docs-erp` theo cùng ref.

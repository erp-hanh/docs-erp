# CL-SCHEMA — Đổi schema

**Dùng khi nào:** PR có thêm file trong `migrations/`. Bất kỳ file nào — tạo bảng, thêm
cột, thêm index, backfill. Cũng dùng khi PR chỉ thêm một câu SQL mới trong repository mà
không đụng migration, vì câu SQL mới là thứ quyết định index nào còn thiếu.

**Dùng thế nào:** đi từ trên xuống, đánh dấu từng dòng. Mỗi dòng kết thúc bằng một trường
`Verifies` trong ngoặc, trỏ ngược về Rule hoặc Convention cụ thể — mở ID đó ra đọc là
biết chính xác thứ đang bị kiểm. Rule nằm ở
[../01-rules/RULES.md](../01-rules/RULES.md), quy ước database nằm ở
[../04-conventions/C-DB-database.md](../04-conventions/C-DB-database.md), năm danh sách
miễn trừ nằm ở mục `C-DB-04` của cùng file đó.

**Đánh dấu một dòng nghĩa là đã kiểm thật, không phải đã đọc qua.** Schema là tầng khó
sửa nhất sau khi có dữ liệu thật — mọi dòng bỏ qua ở đây đều được trả bằng một migration
`ALTER TABLE` trên bảng đang chạy.

---

- [ ] CL-SCHEMA-01 — Mỗi thay đổi schema nằm trong `migrations/`, có đủ cặp `<số>_<tên>.up.sql` và `<số>_<tên>.down.sql`, số 6 chữ số kế tiếp số lớn nhất đang có (Verifies: R-07, C-DB-06)
- [ ] CL-SCHEMA-02 — `git diff --name-status` trên `migrations/` chỉ cho trạng thái `A`; không file migration đã merge nào bị sửa nội dung (Verifies: R-07, C-DB-06)
- [ ] CL-SCHEMA-03 — Không có `CREATE TABLE`, `ALTER TABLE` hay `DROP TABLE` nào nằm trong file ngoài thư mục `migrations/` (Verifies: R-07)
- [ ] CL-SCHEMA-04 — Phần `up` không chứa `IF NOT EXISTS` và không tự viết `BEGIN`/`COMMIT`; phần `down` đưa schema về đúng trạng thái trước `up`, theo thứ tự ngược (Verifies: R-07, C-DB-06)
- [ ] CL-SCHEMA-05 — Tên bảng mới khớp `^[a-z][a-z0-9_]*s$`, hoặc đã có một ADR bổ sung tên đó vào danh sách miễn đặt tên trước khi merge migration này (Verifies: R-08, C-DB-01)
- [ ] CL-SCHEMA-06 — Mỗi bảng mới được khai tường minh thuộc nhóm nào trong bốn nhóm bảng, bằng một comment ASCII ngay trên câu `CREATE TABLE` (Verifies: R-06, C-DB-04)
- [ ] CL-SCHEMA-07 — Bộ cột khớp đúng nhóm đã khai: bảng nghiệp vụ có đủ `id`, `company_id`, `created_at`, `updated_at`, `deleted_at`, `created_by`, `updated_by`; bảng thuộc `append_only_tables` chỉ có `created_at` và `created_by` (Verifies: R-06, R-08, R-17, C-DB-03)
- [ ] CL-SCHEMA-08 — Kiểu dữ liệu theo bảng chuẩn: tiền và số lượng cân đo là `NUMERIC(18,4)`, thời điểm là `TIMESTAMPTZ`, định danh là `UUID`, văn bản là `TEXT`; không có `FLOAT`, `MONEY`, `TIMESTAMP`, `SERIAL`, `VARCHAR(n)`, `ENUM` (Verifies: R-08, C-DB-02)
- [ ] CL-SCHEMA-09 — Mọi khóa ngoại khác `company_id` được phục vụ bởi một index khai trong cùng file migration: cột dẫn đầu, hoặc cột thứ hai sau `company_id` (Verifies: R-09, C-DB-05)
- [ ] CL-SCHEMA-10 — Mọi ràng buộc duy nhất trên bảng có `deleted_at` viết bằng `CREATE UNIQUE INDEX ... WHERE deleted_at IS NULL`, không phải `UNIQUE` thường (Verifies: R-18, C-DB-05)
- [ ] CL-SCHEMA-11 — Tên index và constraint theo mẫu `idx_<table>_<cols>`, `uq_<table>_<cols>`, `fk_<table>_<ref_table>`, `ck_<table>_<mo_ta>`, với `<cols>` là tên cột đầy đủ đúng thứ tự trong index (Verifies: R-09, C-DB-01)
- [ ] CL-SCHEMA-12 — Bảng xin miễn index có comment đúng mẫu ASCII `-- index-exempt: <ly do>` trong chính file migration, và tên bảng đã nằm sẵn trong `reference_tables` chứ không được cấp lẻ tại đây (Verifies: R-09, C-DB-05)
- [ ] CL-SCHEMA-13 — Mọi câu `SELECT`/`UPDATE`/`DELETE` mới trong `*_repository.go` chạm bảng nghiệp vụ đều có `company_id = $n` trong mệnh đề `WHERE` (Verifies: R-06, C-GO-03)
- [ ] CL-SCHEMA-14 — Mọi câu đọc bảng nghiệp vụ hoặc bảng trong `reference_tables` có `deleted_at IS NULL`; method xóa nghiệp vụ dùng `UPDATE ... SET deleted_at = now()` chứ không `DELETE FROM` (Verifies: R-18, C-GO-03)
- [ ] CL-SCHEMA-15 — Mọi cột mới xuất hiện trong `WHERE` hoặc `ORDER BY` của repository — và mọi cột mới mở cho `sort` — là cột thứ nhất hoặc thứ hai của ít nhất một index (Verifies: R-09, C-API-04)
- [ ] CL-SCHEMA-16 — `Database.md` của module đã cập nhật bảng, cột, index và bảng ánh xạ constraint sang mã lỗi; `tables` trong `module.yaml` đã thêm hoặc bỏ đúng tên bảng (Verifies: R-02, C-GO-05)

---

## Hai ca dừng lại viết ADR thay vì tự quyết

- **Bảng mới cần được miễn một thứ gì đó** — không có `company_id`, không có cột audit,
  không soft delete, hoặc tên không kết thúc bằng `s`. Năm danh sách miễn trừ ở
  `04-conventions/C-DB-database.md` mục `C-DB-04` (`system_tables`, `tenant_root`,
  `reference_tables`, `append_only_tables`, `naming_exempt`) chỉ dài ra bằng một ADR
  mới: mỗi entry mang một trường `adr` bắt buộc trỏ tới ADR biện minh cho nó. Người viết
  migration có đúng hai lựa chọn: bảng đó là bảng nghiệp vụ và không được miễn gì, hoặc
  dừng lại viết ADR. Không có đường thứ ba.
- **Cần hard delete một bảng nghiệp vụ.** Phải có ADR riêng cho phép, comment tại chỗ xóa
  theo mẫu `-- hard-delete: ADR-00xx`, và ADR được trỏ tới phải có mục liệt kê đúng tên
  bảng được phép. Chi tiết ở
  [../03-decisions/ADR-0008-soft-delete-by-default.md](../03-decisions/ADR-0008-soft-delete-by-default.md).

## Một lưu ý vận hành

Thêm index lên bảng đã có dữ liệu production cần `CREATE INDEX CONCURRENTLY`, và câu đó
**không chạy được trong transaction block** — nó phải đứng một mình trong file migration
của nó, kèm file `down` cũng chỉ có một câu. Migration tạo bảng mới thì bảng còn rỗng,
dùng `CREATE INDEX` thường.

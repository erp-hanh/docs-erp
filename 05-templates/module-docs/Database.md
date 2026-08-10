# `<ten-module>` — Database

> **Khung tài liệu — xóa mọi dòng trích dẫn `>` sau khi điền xong.**
>
> File này mô tả **schema thật** của module: bảng, cột, quan hệ, index. Nó không lặp lại
> quy ước chung — quy ước nằm ở `docs-erp/04-conventions/C-DB-database.md`.

## 0. Ràng buộc phải giữ khi sửa file này

> Danh sách bảng ở mục 1 phải **khớp từng dòng** với trường `tables` trong
> `modules/<ten-module>/module.yaml`. Đây không phải yêu cầu về hình thức: `module.yaml`
> là đầu vào của bộ kiểm R-02 — nó là thứ trả lời được câu hỏi "tên bảng này trong câu
> SQL của repository là bảng của module hay là truy cập chéo module". Hai danh sách lệch
> nhau thì R-02 không kiểm được bằng máy, và một JOIN sang bảng của module khác sẽ đi
> qua review mà không ai thấy.
>
> Thứ tự đúng khi thêm một bảng: viết migration → thêm tên bảng vào `tables` của
> `module.yaml` → thêm mục ở file này. Ba việc trong **cùng một PR**.

## 1. Danh sách bảng

| Bảng | Nhóm (C-DB-04) | Mô tả một dòng |
|---|---|---|
| `<bang_1>` | Bảng nghiệp vụ | <...> |
| `<bang_2>` | Bảng nghiệp vụ | <...> |

> Cột "Nhóm" nhận đúng một trong năm giá trị: `system_tables`, `tenant_root`,
> `reference_tables`, `append_only_tables`, hoặc **Bảng nghiệp vụ**. Nhóm quyết định bộ
> cột bắt buộc, việc có sinh bản ghi audit hay không, và việc có soft delete hay không
> — nên nó phải được khai tường minh ở đây chứ không để người đọc tự suy ra từ
> migration.
>
> Mặc định của một bảng không có tên trong bốn danh sách miễn trừ ở
> `04-conventions/C-DB-database.md` mục `C-DB-04` là **bảng nghiệp vụ**, và bảng
> nghiệp vụ không được miễn thứ gì. Muốn một bảng nằm ngoài mặc định đó thì phải có
> ADR trước, không phải một dòng ghi chú ở đây.

## 2. Chi tiết từng bảng

### `<bang_1>`

**Nhóm:** <Bảng nghiệp vụ | tenant_root | reference_tables | append_only_tables | system_tables>

**Bảng này giữ gì:** <một câu>

| Cột | Kiểu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| `id` | `UUID` | PK, `DEFAULT gen_random_uuid()` | Khóa chính |
| `company_id` | `UUID` | `NOT NULL REFERENCES companies(id)` | Tenant |
| `<cot_fk>_id` | `UUID` | `NOT NULL`, FK tới `<bang_dich>` | <...> |
| `<cot_nghiep_vu>` | `<kiểu theo C-DB-02>` | <...> | <...> |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |
| `deleted_at` | `TIMESTAMPTZ` | | `NULL` nghĩa là chưa xóa |
| `created_by` | `UUID` | `NOT NULL` | |
| `updated_by` | `UUID` | `NOT NULL` | Lúc `INSERT` bằng `created_by` |

**Quan hệ:**

- `<bang_1>.<cot_fk>_id` → `<bang_dich>.id` — <1-n hay n-1, và xóa bản ghi cha thì sao>
- <bảng này thuộc module nào nếu bảng đích không phải của module này; nếu bảng đích thuộc
  module khác thì repository **không** được JOIN sang nó — nêu rõ đường thay thế>

**Index:**

| Tên | Cột | Điều kiện | Phục vụ truy vấn nào |
|---|---|---|---|
| `uq_<bang_1>_company_id_<cot>` | `(company_id, <cot>)` | `WHERE deleted_at IS NULL` | Ràng buộc duy nhất theo công ty |
| `idx_<bang_1>_company_id_<cot>` | `(company_id, <cot>)` | | <method repository dùng nó> |

> Mỗi dòng index phải trả lời được cột cuối. Một index không nêu được truy vấn nào dùng
> nó là một index chưa có lý do tồn tại — nó vẫn làm chậm mọi lần ghi.
>
> Bảng có `deleted_at` thì mọi ràng buộc duy nhất là **partial unique index** với vế
> `WHERE deleted_at IS NULL`, không phải `UNIQUE` thường.

**Ràng buộc mức bảng:**

| Tên constraint | Nội dung | Mã lỗi nghiệp vụ tương ứng |
|---|---|---|
| `ck_<bang_1>_<mo_ta>` | `CHECK (...)` | `<ERR_...>` |
| `uq_<bang_1>_company_id_<cot>` | partial unique | `<ERR_..._DUPLICATED>` |

> Cột cuối là thứ dễ quên nhất và là thứ service dựa vào: lỗi Postgres được dịch sang mã
> lỗi nghiệp vụ **theo tên constraint**. Constraint không có dòng ở đây thì lỗi của nó ra
> client dưới dạng `ERR_INTERNAL`.

### `<bang_2>`

<lặp lại cấu trúc trên>

## 3. Sơ đồ quan hệ

```text
<bang_1> 1 ──── n <bang_2>
    │
    └── n ──── 1 <bang_cua_module_khac>   (KHONG JOIN - goi qua api/)
```

> Vẽ cả quan hệ trỏ sang bảng của module khác, và đánh dấu rõ chúng. Sơ đồ giấu chúng đi
> là sơ đồ khiến người đọc tưởng một JOIN là hợp lệ.

## 4. Migration đã tạo ra schema này

| File | Làm gì |
|---|---|
| `migrations/<000xxx>_create_<bang_1>.up.sql` | <...> |
| `migrations/<000xxx>_add_<cot>_to_<bang_1>.up.sql` | <...> |

> Danh sách này chỉ để tra ngược. Nguồn sự thật của schema là chính các file migration —
> file tài liệu này mô tả lại, không thay thế. Khi hai bên lệch nhau, migration đúng và
> file này là thứ phải sửa.

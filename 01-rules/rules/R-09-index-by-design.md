# R-09 — Index by Design

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Thiếu index không hề lộ ra khi viết migration — bảng lúc đó rỗng hoặc có vài chục
dòng, `SELECT ... WHERE order_id = $1` nhanh như nhau dù có index hay không, seq scan
trên vài chục dòng là tức thời. Bug chỉ lộ ra khi bảng đã lớn lên tới hàng trăm
nghìn, hàng triệu dòng — và đó thường đúng vào lúc hệ thống đang phục vụ khách hàng
thật, tức là thời điểm tệ nhất để phát hiện ra.

Lúc đó, thêm index không còn là việc rẻ nữa. `CREATE INDEX` thường giữ lock chặn ghi
lên bảng trong suốt thời gian build; trên bảng vài triệu dòng việc này có thể mất
hàng phút tới hàng giờ, nên phải dùng `CREATE INDEX CONCURRENTLY` (không được chạy
chung transaction với DDL khác, có thể fail giữa chừng và để lại index ở trạng thái
`INVALID` phải dọn tay), và phải canh giờ thấp điểm cùng người trực theo dõi. Một
việc đáng lẽ chỉ là thêm hai dòng vào migration lúc code review biến thành một thao
tác vận hành có rủi ro, cần lên kế hoạch. Rẻ nhất luôn là đặt đúng index ngay tại
migration tạo bảng, khi chi phí tạo index gần như bằng không.

Với bảng multi-tenant (R-06), index đơn trên `(company_id)` gần như vô dụng: mọi
bảng nghiệp vụ đều có `company_id`, và trong phần lớn truy vấn nó là điều kiện lọc
đầu tiên xuất hiện ở hầu hết mọi dòng — độ chọn lọc (selectivity) của một index chỉ
có một cột `company_id` quá thấp để planner dùng hiệu quả, nhất là khi hệ thống mới
chỉ có một hoặc vài công ty. Quy ước bắt buộc là index composite, `company_id` luôn
đứng đầu, theo sau là cột thật sự dùng để lọc hoặc sắp xếp, ví dụ
`idx_orders_company_id_status ON orders(company_id, status)`.

## Ví dụ SAI

```sql
-- migrations/000045_create_order_items.up.sql

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id),
    order_id    UUID NOT NULL REFERENCES orders(id),
    product_id  UUID NOT NULL,
    quantity    NUMERIC(14,2) NOT NULL,
    unit_price  NUMERIC(14,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
-- SAI: order_id là khóa ngoại nhưng không có CREATE INDEX nào đi kèm, và cũng
-- không có comment miễn index nào giải thích lý do bỏ qua.
-- Khi order_items còn vài trăm dòng, "SELECT * FROM order_items WHERE order_id = $1"
-- (dùng để mở màn hình chi tiết đơn hàng) nhanh như nhau có index hay không.
-- Khi bảng lên tới hàng triệu dòng, câu đó seq-scan toàn bảng mỗi lần mở một đơn hàng.
```

## Ví dụ ĐÚNG

```sql
-- migrations/000045_create_order_items.up.sql

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id),
    order_id    UUID NOT NULL REFERENCES orders(id),
    product_id  UUID NOT NULL,
    quantity    NUMERIC(14,2) NOT NULL,
    unit_price  NUMERIC(14,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);

-- ĐÚNG: index cho khóa ngoại, đặt tên theo quy ước idx_<table>_<cols>.
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
```

```sql
-- migrations/000046_create_order_tags.up.sql

CREATE TABLE order_tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    order_id   UUID NOT NULL REFERENCES orders(id),
    label      TEXT NOT NULL
);

-- ĐÚNG: bảng này đủ điều kiện miễn theo Ngoại lệ của R-09 (dự kiến dưới 1000 dòng,
-- không tham gia JOIN) — nhưng lý do PHẢI được ghi ngay tại đây, không ghi ở nơi khác.
-- miễn index: order_tags dự kiến dưới 200 dòng/công ty, chỉ đọc kèm theo màn hình
-- chi tiết đơn hàng (đã có idx_order_items_order_id ở bảng order_items), không JOIN
-- ở bất kỳ truy vấn nào khác.
```

```sql
-- migrations/000047_add_orders_status_index.up.sql

-- ĐÚNG: orders là bảng multi-tenant — index đơn (company_id) gần như vô dụng vì
-- company_id lặp lại trên phần lớn bản ghi. Composite, company_id đứng đầu, theo
-- sau là cột thật sự dùng để lọc trong repository (WHERE company_id = $1 AND status = $2).
CREATE INDEX idx_orders_company_id_status ON orders(company_id, status);
```

Bộ quy tắc chi tiết hơn về index nằm ở skill `postgres-index-expert` của dự án.

## Cách kiểm

```powershell
# 1) Migration nào có REFERENCES nhưng không có CREATE INDEX và không ghi lý do miễn?
Get-ChildItem -Path migrations -Filter *.up.sql | ForEach-Object {
    $text = Get-Content -Path $_.FullName -Raw
    if ($text -match 'REFERENCES' -and $text -notmatch '(?i)CREATE INDEX' -and $text -notmatch 'miễn index') {
        Write-Host ("{0}: co REFERENCES nhung khong co CREATE INDEX va khong ghi ly do mien" -f $_.Name)
    }
}

# 2) Liệt kê từng cột khóa ngoại để đối chiếu thủ công với CREATE INDEX ngay bên dưới
#    (bắt cả trường hợp file có CREATE INDEX nhưng lệch cột, ví dụ index nhầm cột khác)
Get-ChildItem -Path migrations -Filter *.up.sql | Select-String -Pattern '^\s*(\w+)\s+UUID\s+NOT NULL\s+REFERENCES' | ForEach-Object {
    "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
}
```

Lệnh (1) bắt trường hợp thiếu hẳn cả index lẫn lý do miễn — vi phạm chắc chắn. Lệnh
(2) chỉ liệt kê để đối chiếu bằng mắt, vì việc khớp chính xác "cột này có đúng index
tương ứng không" cần đọc câu `CREATE INDEX` cùng file, không phải thứ regex một dòng
xác định chắc chắn được.

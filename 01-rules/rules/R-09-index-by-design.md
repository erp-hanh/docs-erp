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
lặp lại ở hầu hết mọi dòng — độ chọn lọc (selectivity) của một index chỉ có một cột
`company_id` quá thấp để planner dùng hiệu quả, nhất là khi hệ thống mới chỉ có một
hoặc vài công ty. Đó là lý do rule chấp nhận hai dạng cho khóa ngoại: hoặc nó là cột
dẫn đầu của một index riêng, hoặc — dạng dùng gần như luôn luôn trên bảng nghiệp vụ —
nó là cột **thứ hai** trong index composite mở đầu bằng `company_id`, khớp đúng hình
dạng mọi câu WHERE thật sự chạy (`WHERE company_id = $1 AND order_id = $2`).

Tên index không phải việc của rule này. R-09 chỉ quy định **cột nào phải nằm ở vị trí
nào**; cách đặt tên nằm ở `04-conventions/C-DB-database.md` và được kiểm ở đó.

Ngoại lệ của R-09 từng dựa trên dự đoán kích thước ("dưới 1000 dòng, không tham gia
JOIN"). Vế đó đã bị bỏ vì hai lý do. Thứ nhất, nó không kiểm được tại thời điểm review:
người viết migration đoán, người review không có cách nào xác nhận hay bác bỏ. Thứ
hai, nó sai theo thời gian — mọi bảng đều nhỏ trong tháng đầu, và không ai quay lại
xóa dòng miễn trừ khi bảng lớn lên. Ngoại lệ hiện tại dựa trên tính chất cấu trúc,
đọc thẳng ra được từ chính file migration: bảng tra cứu tĩnh, không có `company_id`,
không có khóa ngoại trỏ tới bảng giao dịch. Một bảng như vậy không lớn lên theo lượng
giao dịch, nên kết luận rút ra hôm nay vẫn còn đúng sau ba năm.

## Ví dụ SAI

```sql
-- migrations/000045_create_order_items.up.sql

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id),
    order_id    UUID NOT NULL REFERENCES orders(id),
    product_id  UUID NOT NULL REFERENCES products(id),
    quantity    NUMERIC(14,2) NOT NULL,
    unit_price  NUMERIC(14,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    created_by  UUID NOT NULL,
    updated_by  UUID
);
-- SAI: order_id và product_id là khóa ngoại nhưng không có CREATE INDEX nào đi kèm,
-- và cũng không có comment miễn nào giải thích lý do bỏ qua.
-- Khi order_items còn vài trăm dòng, "SELECT * FROM order_items WHERE company_id = $1
-- AND order_id = $2" (dùng để mở màn hình chi tiết đơn hàng) nhanh như nhau có index
-- hay không. Khi bảng lên tới hàng triệu dòng, câu đó seq-scan toàn bảng mỗi lần mở
-- một đơn hàng.
```

## Ví dụ ĐÚNG

```sql
-- migrations/000045_create_order_items.up.sql

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id),
    order_id    UUID NOT NULL REFERENCES orders(id),
    product_id  UUID NOT NULL REFERENCES products(id),
    quantity    NUMERIC(14,2) NOT NULL,
    unit_price  NUMERIC(14,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    created_by  UUID NOT NULL,
    updated_by  UUID
);

-- ĐÚNG: mỗi khóa ngoại khác company_id là cột THỨ HAI của một index composite mở đầu
-- bằng company_id — khớp đúng hình dạng câu WHERE thật sự chạy trong repository.
CREATE INDEX idx_order_items_company_id_order_id   ON order_items(company_id, order_id);
CREATE INDEX idx_order_items_company_id_product_id ON order_items(company_id, product_id);
```

```sql
-- migrations/000046_create_order_tags.up.sql

CREATE TABLE order_tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    order_id   UUID NOT NULL REFERENCES orders(id),
    label      TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    created_by UUID NOT NULL,
    updated_by UUID
);

-- ĐÚNG: order_tags KHÔNG đủ điều kiện miễn dù bảng rất nhỏ — nó có company_id và có
-- khóa ngoại trỏ tới orders, một bảng giao dịch. Kích thước dự kiến không còn là căn
-- cứ để miễn, nên bảng này nhận index như mọi bảng nghiệp vụ khác.
CREATE INDEX idx_order_tags_company_id_order_id ON order_tags(company_id, order_id);
```

```sql
-- migrations/000047_create_currencies.up.sql

CREATE TABLE currencies (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code       TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    minor_unit SMALLINT NOT NULL
);

-- index-exempt: currencies la bang tra cuu tinh - khong co company_id, khong co khoa
-- ngoai tro toi bang giao dich. Du lieu nap mot lan luc seed (~180 dong ISO 4217) va
-- chi doc qua PRIMARY KEY hoac UNIQUE(code); ca hai rang buoc do da tu sinh index.
```

Comment miễn phải viết đúng mẫu ASCII `-- index-exempt: <lý do>` và nằm ngay trong
file migration đó. Lý do dùng ASCII thuần: PowerShell 5.1 đọc file `.sql` mã hóa UTF-8
không BOM theo codepage ANSI, nên một marker viết tiếng Việt có dấu sẽ không khớp khi
grep — script sẽ báo oan file đã ghi lý do miễn.

Lưu ý về `currencies`: nó không có `company_id`, mà theo R-06 chỉ bảng nằm trong danh
sách `system_tables` mới được thiếu cột đó. Nghĩa là muốn dùng ngoại lệ của R-09,
bảng phải được thêm tên vào `system_tables` ở
`03-decisions/ADR-0003-multi-tenant-ready.md` trước — và việc đó cần một ADR mới. Đây
là chủ ý: ngoại lệ index không được cấp lẻ trong một migration, nó đi kèm quyết định
"bảng này không thuộc tenant nào".

```sql
-- migrations/000048_add_orders_status_index.up.sql

-- ĐÚNG: orders là bảng multi-tenant — index đơn (company_id) gần như vô dụng vì
-- company_id lặp lại trên phần lớn bản ghi. Composite, company_id đứng đầu, theo
-- sau là cột thật sự dùng để lọc trong repository (WHERE company_id = $1 AND status = $2).
CREATE INDEX idx_orders_company_id_status ON orders(company_id, status);
```

Tên index trong các ví dụ trên (`idx_order_items_company_id_order_id`, ...) theo quy
ước đặt tên ở `04-conventions/C-DB-database.md`; R-09 không quy định phần đó và không
kiểm nó.

Bộ quy tắc chi tiết hơn về index nằm ở skill `postgres-index-expert` của dự án.

## Cách kiểm

```powershell
# 1) Migration co khoa ngoai (khac company_id) nhung so CREATE INDEX khong du
Get-ChildItem -Path migrations -Filter *.up.sql | ForEach-Object {
    $text = Get-Content -Path $_.FullName -Raw
    if (-not $text) { return }

    # Marker mien phai la ASCII thuan: PowerShell 5.1 doc file UTF-8 khong BOM theo
    # codepage ANSI nen chuoi tieng Viet co dau se khong bao gio khop.
    if ($text -match '(?im)^\s*--\s*index-exempt:') { return }

    $fks = @()
    # FK khai o muc cot, bat ca FK nullable: "<col> UUID [NOT NULL] REFERENCES ..."
    $fks += @([regex]::Matches($text, '(?im)^\s*([a-z_][a-z0-9_]*)\s+UUID\b[^,;\r\n]*\bREFERENCES\b') |
              ForEach-Object { $_.Groups[1].Value })
    # FK khai o muc bang: "FOREIGN KEY (<col>) REFERENCES ..."
    $fks += @([regex]::Matches($text, '(?is)FOREIGN\s+KEY\s*\(\s*([a-z_][a-z0-9_]*)') |
              ForEach-Object { $_.Groups[1].Value })
    $fks = @($fks | Where-Object { $_ -ne 'company_id' } | Select-Object -Unique)
    if ($fks.Count -eq 0) { return }

    $idx = @([regex]::Matches($text, '(?i)CREATE\s+(?:UNIQUE\s+)?INDEX')).Count
    if ($idx -lt $fks.Count) {
        Write-Host ("{0}: {1} khoa ngoai (khac company_id) nhung chi co {2} CREATE INDEX -> {3}" -f `
            $_.Name, $fks.Count, $idx, ($fks -join ', '))
    }
}

# 2) Liet ke khoa ngoai va index cua tung file de doi chieu bang mat
Get-ChildItem -Path migrations -Filter *.up.sql | ForEach-Object {
    $name = $_.Name
    Select-String -Path $_.FullName -Pattern `
        '(?i)^\s*[a-z_][a-z0-9_]*\s+UUID\b[^,;]*\bREFERENCES\b', `
        '(?i)FOREIGN\s+KEY\s*\(', `
        '(?i)CREATE\s+(UNIQUE\s+)?INDEX' | ForEach-Object {
        "{0}:{1}: {2}" -f $name, $_.LineNumber, $_.Line.Trim()
    }
}
```

Lệnh (1) so **số** khóa ngoại (đã trừ `company_id`) với **số** `CREATE INDEX` trong
cùng file, thay vì chỉ hỏi "file này có `CREATE INDEX` nào không". Điều kiện kiểu
"có ít nhất một" cho qua trường hợp phổ biến nhất trên thực tế: bảng có ba khóa ngoại
nhưng người viết chỉ index một cái rồi quên hai cái còn lại. Regex bắt khóa ngoại
cũng nới để không bỏ sót hai dạng khai báo hợp lệ mà bản cũ bỏ lọt: khóa ngoại
nullable (`parent_id UUID REFERENCES categories(id)`, không có `NOT NULL`) và khóa
ngoại khai ở mức bảng (`FOREIGN KEY (order_id) REFERENCES orders(id)`).

Đây vẫn là heuristic đếm, không phải chứng minh: hai `CREATE INDEX` cùng đặt trên một
cột vẫn đủ số để lọt. Vì vậy lệnh (2) in ra cạnh nhau mọi dòng khóa ngoại và mọi dòng
`CREATE INDEX` của từng file, để đối chiếu bằng mắt xem đúng cột đó có nằm ở vị trí
thứ nhất — hoặc thứ hai sau `company_id` — của một index nào không. Lệnh (2) in ra cả
dòng khai `company_id ... REFERENCES companies(id)` để thấy đủ khối, nhưng bản thân
`company_id` không cần index riêng: nó chỉ hợp lệ ở vị trí dẫn đầu của index composite.

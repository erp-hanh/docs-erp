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
xóa dòng miễn trừ khi bảng lớn lên.

Ngoại lệ hiện tại dựa trên hai điều kiện cấu trúc, cả hai đều tra được chứ không đoán:
tên bảng **có trong danh sách `reference_tables`** ở `04-conventions/C-DB-database.md`
mục `C-DB-04`, và trong chính file migration **không có khóa ngoại trỏ tới bảng giao
dịch**. Điều kiện thứ nhất tra ở registry, điều kiện thứ hai đọc thẳng ra từ file đang
review. Một bảng thỏa cả hai là danh mục dùng chung, không lớn lên theo lượng giao
dịch, nên kết luận rút ra hôm nay vẫn còn đúng sau ba năm.

Phải là `reference_tables` chứ không phải "bảng nào không có `company_id`". Theo R-06,
bảng thiếu `company_id` chỉ hợp lệ khi nó nằm trong `system_tables`, `tenant_root` hoặc
`reference_tables`; mà `system_tables` (`schema_migrations`) và `tenant_root`
(`companies`) vốn không có khóa ngoại nào nên chẳng bao giờ cần tới ngoại lệ này. Nếu
ngoại lệ chỉ ghi "không có `company_id`" thì hai nhóm bảng duy nhất dùng được nó lại là
hai nhóm không cần nó — ngoại lệ thành chữ chết. `reference_tables` là nhóm thật sự rơi
vào tình huống đó: danh mục dùng chung, có người sửa, có audit, có soft delete, nhưng
không thuộc tenant nào.

## Ví dụ SAI

```sql
-- migrations/000045_create_order_items.up.sql

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id),
    order_id    UUID NOT NULL REFERENCES orders(id),
    product_id  UUID NOT NULL REFERENCES products(id),
    quantity    NUMERIC(18,4) NOT NULL,
    unit_price  NUMERIC(18,4) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    created_by  UUID NOT NULL,
    updated_by  UUID NOT NULL
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
    quantity    NUMERIC(18,4) NOT NULL,
    unit_price  NUMERIC(18,4) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    created_by  UUID NOT NULL,
    updated_by  UUID NOT NULL
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
    updated_by UUID NOT NULL
);

-- ĐÚNG: order_tags KHÔNG đủ điều kiện miễn dù bảng rất nhỏ — nó trượt CẢ HAI điều
-- kiện: tên không có trong reference_tables (nó là bảng nghiệp vụ, có company_id), và
-- nó có khóa ngoại trỏ tới orders, một bảng giao dịch. Kích thước dự kiến không còn là
-- căn cứ để miễn, nên bảng này nhận index như mọi bảng nghiệp vụ khác.
CREATE INDEX idx_order_tags_company_id_order_id ON order_tags(company_id, order_id);
```

```sql
-- migrations/000047_create_currencies.up.sql

-- currencies nam trong nhom reference_tables: danh muc dung chung toan he thong,
-- khong thuoc tenant nao nen khong co company_id (R-06). Nhung no chi duoc mien dung
-- ve do: van co du cot thoi gian (R-08), du cot audit va van sinh ban ghi audit khi
-- ghi (R-17), van xoa mem (R-18) - vi danh muc co nguoi sua va can truy vet ai sua.
CREATE TABLE currencies (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code       TEXT NOT NULL,
    name       TEXT NOT NULL,
    minor_unit SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    created_by UUID NOT NULL,
    updated_by UUID NOT NULL
);

-- Partial unique index thay cho UNIQUE thuong, theo R-18: bang co soft delete nen mot
-- ma da xoa mem van chiem cho neu dung UNIQUE, khong tao lai duoc ban ghi cung ma.
-- Bang khong co company_id nen index bat dau thang tu cot nghiep vu.
CREATE UNIQUE INDEX uq_currencies_code ON currencies(code) WHERE deleted_at IS NULL;

-- index-exempt: currencies nam trong danh sach reference_tables va khong co khoa ngoai
-- tro toi bang giao dich - du ca hai dieu kien. Du lieu nap mot lan luc seed (~180 dong
-- ISO 4217) va chi doc qua PRIMARY KEY hoac code; ca hai cot do da co index san.
```

Comment miễn phải viết đúng mẫu ASCII `-- index-exempt: <lý do>` và nằm ngay trong
file migration đó. Lý do dùng ASCII thuần: PowerShell 5.1 đọc file `.sql` mã hóa UTF-8
không BOM theo codepage ANSI, nên một marker viết tiếng Việt có dấu sẽ không khớp khi
grep — script sẽ báo oan file đã ghi lý do miễn.

Hai điều kiện của ngoại lệ phải đủ **cả hai**, và `currencies` là ví dụ đủ cả hai.
Điều kiện (a) — tên nằm trong `reference_tables` — không cấp được bằng một dòng comment
trong migration: muốn có nó phải viết ADR bổ sung tên bảng vào danh sách ở
`04-conventions/C-DB-database.md` mục `C-DB-04`. Đây là chủ ý: ngoại lệ index đi kèm
quyết định "bảng này là danh mục dùng chung, không thuộc tenant nào", chứ không phải
một ưu ái xin lẻ lúc viết migration. Điều kiện (b) — không có khóa ngoại trỏ tới bảng
giao dịch — thì đọc thẳng ra từ file: nếu ngày mai ai đó thêm `order_id UUID REFERENCES
orders(id)` vào `currencies`, bảng mất quyền miễn ngay cả khi vẫn nằm trong
`reference_tables`, vì lúc đó nó lớn lên theo lượng giao dịch.

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

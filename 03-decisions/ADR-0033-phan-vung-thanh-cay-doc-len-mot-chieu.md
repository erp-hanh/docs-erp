# ADR-0033: Phân vùng thành cây, và ranh giới dữ liệu chỉ mở theo một chiều lên trên

**Status:** Proposed (2026-08-24)

## Context

Người dùng mô tả mô hình phân vùng họ muốn, lấy MISA làm mẫu:

1. **Doanh nghiệp tự tạo phân vùng**, mỗi phân vùng có **tên gọi**, **mã đơn vị**, và **mã số
   thuế riêng**.
2. **Hạch toán độc lập hoặc phụ thuộc**: một đơn vị có bộ sổ riêng, hoặc **báo sổ về công ty
   mẹ**.
3. **Phân quyền dữ liệu theo phân vùng**: nhân sự ở phân vùng nào chỉ xem/thao tác dữ liệu
   thuộc phân vùng đó; riêng Giám đốc / Kế toán trưởng xem được **toàn hệ thống**.

Đối chiếu với code thật:

| Yêu cầu | Hiện trạng |
|---|---|
| Tên gọi | `companies.name` - có (`migrations/000001_create_companies.up.sql:7`) |
| Mã đơn vị | `companies.code` - có, kèm partial unique index (dòng 6, 18) |
| Mã số thuế riêng | **không có cột** |
| Nhân sự chỉ thấy dữ liệu phân vùng mình | **có, và được canh bằng máy** - token mang `company_id`, R-06 vế hai bắt mọi câu SELECT trong repository phải có `company_id = $` (`arch/checks_migration.go:207-249`) |
| Hạch toán độc lập / phụ thuộc | **không có khái niệm**, và nó đòi một cây cha-con |
| Xem toàn hệ thống | **không có đường nào** |

Hai dòng cuối không phải thiếu tính năng. Chúng đụng vào mệnh đề trung tâm của
[ADR-0019](ADR-0019-phan-vung-la-cong-ty.md): *"mỗi phân vùng là một `companies`, dữ liệu giữa
các phân vùng không lẫn nhau"*. Mọi thứ dựng trên mệnh đề đó - R-06, cách token mang một
`company_id` duy nhất, cách từng repository viết query.

**"Báo sổ về công ty mẹ" nghĩa là dữ liệu CÓ lẫn, theo một chiều.** Đó là điều ADR-0019 không
cho.

**"Xem toàn hệ thống" bị chặn cứng, không chỉ chưa thiết kế.** Một câu truy vấn xuyên phân vùng
theo định nghĩa không có `company_id = $`, nên bộ kiểm kiến trúc báo đỏ. Và nó **không** phải
thứ `inventory.warehouse_scope_all` giải được: [ADR-0026](ADR-0026-toan-pham-vi-khong-la-mot-permission.md)
mở rộng phạm vi **trong** một phân vùng, không bước qua ranh giới phân vùng.

Cùng bức tường đã được ghi ở `99-meta/my-specs/2026-08-24-adr-0019-gd2-ke-hoach.md` (rủi ro số
1). Lúc đó nó là chi tiết của một đợt; với yêu cầu này nó thành câu hỏi trung tâm của sản phẩm.

## Decision

**Phân vùng thành một cây. Ranh giới dữ liệu vẫn kín theo chiều ngang, và chỉ mở theo chiều
LÊN TRÊN, dưới một quyền tường minh, và chỉ cho đường ĐỌC.**

**1. `companies` thêm ba cột.**

```
parent_id  UUID NULL REFERENCES companies(id)   -- NULL = gốc cây
tax_code   TEXT NULL                            -- mã số thuế, không unique (xem mục 6)
hach_toan  TEXT NOT NULL DEFAULT 'doc_lap'      -- 'doc_lap' | 'phu_thuoc'
```

`hach_toan = 'phu_thuoc'` nghĩa là dữ liệu của phân vùng này **được đọc lên** cây cha.
`'doc_lap'` nghĩa là không, kể cả khi nó có `parent_id`. Hai cột tách nhau vì chúng trả lời hai
câu khác nhau: `parent_id` nói *"tôi thuộc về ai trong cơ cấu tổ chức"*, `hach_toan` nói *"sổ
của tôi có chảy lên hay không"*. Gộp chúng là ép một chi nhánh phải chọn giữa việc nằm trong
cơ cấu và việc giữ sổ riêng.

**2. Ba chiều, và chỉ một chiều được mở.**

| Chiều | Cho phép? |
|---|---|
| Đọc dữ liệu của **chính** phân vùng mình | Có, như hôm nay |
| Đọc **lên trên** - cha đọc dữ liệu của con `phu_thuoc` | Có, dưới quyền ở mục 3 |
| Đọc **ngang** - chi nhánh này đọc chi nhánh kia | **Không, mãi mãi** |
| **Ghi** xuyên phân vùng, theo bất kỳ chiều nào | **Không, mãi mãi** |

Chiều ngang bị cấm vì nó là thứ mà "dữ liệu không lẫn nhau" thật sự bảo vệ. Ghi bị cấm vì một
bút toán ghi vào phân vùng khác thì không ai trả lời được nó thuộc sổ của ai.

**3. Đọc lên trên đi qua một quyền mới, không qua một cờ.** Đề xuất `auth.company_scope_tree`
(tên chốt lúc thi công). Nó **không** phải một cờ trên `users`: cờ không đi qua `authz.Can` nên
không qua được R-15, và bảng permission thôi nói thật ai làm được gì - đúng lập luận ADR-0019
mục 5 đã dùng khi loại claim `sys_admin` riêng.

Giám đốc và Kế toán trưởng của công ty mẹ là hai vai trò **của phân vùng mẹ** mang quyền này.
Không phải vai trò dẫn xuất, không phải `quan_tri_he_thong`.

**4. R-06 cần một ngoại lệ HẸP, và ngoại lệ đó phải kiểm được bằng máy.** Câu truy vấn xuyên
cây vẫn phải nói ra phạm vi của nó; nó chỉ không nói bằng `company_id = $1`. Hình dạng đề xuất:

```sql
WHERE company_id = ANY($1)   -- $1 = danh sách id đã được service giải từ cây
```

Service giải cây **trước** khi gọi repository, và repository nhận một mảng id chứ không nhận
một câu điều kiện. Nhờ vậy: repository vẫn không biết gì về cây; cửa quyền vẫn nằm ở service
theo R-15; và bộ kiểm R-06 có một khuôn cụ thể để nhận ra thay vì phải bỏ qua cả file.

`arch/checks_migration.go` phải học thêm khuôn `company_id = ANY($n)` và **chỉ chấp nhận nó
trong những repository method có tên đã khai vào một danh sách tường minh**. Không có danh sách
đó thì ngoại lệ này biến R-06 từ một luật thành một gợi ý.

**5. Cấm "giải cây trong SQL".** Một `WITH RECURSIVE` trong repository để tự đi cây là đường
ngắn nhất và cũng là đường làm R-06 mất nghĩa hoàn toàn: từ đó không câu nào còn phải nói phạm
vi của mình. Cây được giải ở service, thành một mảng id, mỗi request một lần.

**6. `tax_code` KHÔNG unique.** Một pháp nhân có nhiều đơn vị phụ thuộc dùng chung mã số thuế
của công ty mẹ - đó là chuyện bình thường ở Việt Nam. Ràng buộc unique ở đây sẽ chặn đúng ca
nghiệp vụ hợp lệ. Nếu sau này cần chống nhập trùng do lỗi tay, đó là một phép kiểm ở tầng
service kèm cảnh báo, không phải một index.

**7. Việc này KHÔNG thay ADR-0019, nó nới ADR-0019.** Mệnh đề "một phân vùng là một
`companies`" đứng nguyên. Mệnh đề "dữ liệu không lẫn nhau" được thay bằng một mệnh đề chặt hơn:
**dữ liệu không lẫn NGANG, và chỉ chảy LÊN khi con khai `phu_thuoc` và người đọc mang quyền
tương ứng.** Vì ADR-0019 là `Accepted` và tầng Decision không sửa tại chỗ, ADR này là chỗ ghi
mệnh đề mới.

## Alternatives

**Nhánh B - giữ cô lập tuyệt đối, hợp nhất ở một tầng báo cáo riêng.** Phân vùng không bao giờ
lẫn nhau; báo cáo toàn hệ đọc từ một nơi khác (view chỉ đọc, hoặc kho dữ liệu nạp định kỳ).

Loại, nhưng **suýt được chọn**, và lý do loại không phải kỹ thuật:

- Được: R-06 không phải nới một chữ. Bộ kiểm giữ nguyên sức mạnh, và không ai phải tin một danh
  sách ngoại lệ.
- Mất: một tầng nữa phải dựng, vận hành và đồng bộ. Và số liệu hợp nhất **trễ hơn giao dịch** -
  một kế toán trưởng vừa duyệt một phiếu rồi mở báo cáo hợp nhất sẽ không thấy nó. Với một hệ
  mà người dùng làm việc trong ngày, độ trễ đó là thứ họ sẽ báo là lỗi.

Ngày số phân vùng lớn tới mức mảng id ở mục 4 thành vài trăm phần tử, nhánh B là đường ra và
ADR này không đóng nó.

**Bỏ hẳn `company_id` khỏi các bảng nghiệp vụ, thay bằng một cột trỏ tới cây** - loại. Nó bắt
viết lại mọi query, mọi index, mọi migration đã có, và nó phá R-06 ở tận gốc chứ không phải nới
một ngoại lệ.

**Token mang danh sách phân vùng thay vì một `company_id`** - loại ở ADR này. Nó đổi hình dạng
access token, tức chạm luồng đăng nhập, tức chồng lên
[ADR-0019 giai đoạn hai](ADR-0019-phan-vung-la-cong-ty.md) đang còn nợ. Service giải cây từ một
`company_id` đạt cùng kết quả mà không đụng token.

**Dùng `inventory.warehouse_scope_all` mở rộng thành "toàn phân vùng"** - loại. ADR-0026 chốt
rằng toàn phạm vi là **dữ liệu treo cùng chỗ với phạm vi**, và phạm vi đó neo vào một hàng gán
vai trò **trong một phân vùng**. Không có chỗ nào trong hình dạng đó nói được "mọi phân vùng".

## Consequences

**Được:**

- Mô hình chi nhánh đúng thứ người dùng mô tả: tự đặt tên, tự đặt mã, tự chọn hạch toán độc lập
  hay báo sổ lên mẹ.
- Báo cáo hợp nhất đọc số liệu **tức thời**, không qua một tầng nạp định kỳ.
- Cô lập ngang - phần đáng bảo vệ nhất - không bị nới một chút nào.

**Mất:**

- **R-06 từ một luật không ngoại lệ thành một luật có danh sách ngoại lệ.** Đây là cái giá lớn
  nhất và nó không thu hồi được: từ nay câu hỏi "câu này có nói phạm vi của nó không" cần tra
  một danh sách thay vì đọc một dòng SQL. Rủi ro thật không phải bộ kiểm báo đỏ, mà là **ai đó
  thêm một tên vào danh sách ngoại lệ cho nhanh** - và không gì báo ra điều đó.
- Cơ cấu tổ chức thành một cây, nên mọi màn có phân vùng phải trả lời thêm: hiện cả cây hay chỉ
  một nút.
- Một request của người mang quyền đọc cây phải giải cây trước, tức thêm một vòng truy vấn.
  Chưa đo.

**Nợ để lại:**

- ~~Chưa quyết: cây sâu bao nhiêu tầng.~~ **Đã quyết ở mục 8, xem Phụ lục cuối file.**
- **Chưa quyết: ai sửa được `hach_toan` sau khi phân vùng đã có số liệu.** Đổi `phu_thuoc` thành
  `doc_lap` là làm một báo cáo hợp nhất đã in ra không tái tạo được.
- **Chưa xác minh** bộ kiểm R-06 nhận thêm khuôn `company_id = ANY($n)` khó hay dễ - chưa đọc
  đủ `arch/checks_migration.go`.
- ADR-0019 giai đoạn hai vẫn phải làm trước hoặc song song: chưa có nó thì một người làm ở hai
  chi nhánh vẫn cần hai tài khoản, và cây phân vùng không giải được chuyện đó.
- Ngày cần **ghi** xuyên phân vùng (chuyển kho giữa hai chi nhánh như một nghiệp vụ, không phải
  hai bút toán rời), mục 2 phải được mở bằng một ADR mới - và ADR đó khó hơn ADR này nhiều.

**Constrains:** -

## Phụ lục: mục 8 - độ sâu của cây

Thêm ngày 2026-08-24, sau khi người dùng cho biết họ không làm kỹ thuật và trỏ sang MISA AMIS
làm mẫu. Đây là một quyết định kỹ thuật nên nó không được đẩy sang người dùng.

**8. Lược đồ cho phép cây sâu tùy ý; bộ giải đi đệ quy có trần và có chặn vòng lặp; chỉ HAI
TẦNG được cam kết và được kiểm.**

Bằng chứng cho hai tầng: ảnh chụp MISA AMIS mà người dùng gửi liệt kê khối "Cơ cấu phân vùng
doanh nghiệp (4)" gồm một gốc *Toàn hệ thống (Tổng hợp)* và bốn nhánh phẳng (*CN-HN*, *CN-HCM*,
*NM-TB*, *CN-DN*). Không có nút cháu nào trên ảnh.

Bằng chứng cho việc **không** đóng cứng ở hai tầng: mô tả của người dùng có nhắc "Xưởng May 01"
cạnh "Chi nhánh Miền Bắc", và một xưởng thường nằm dưới một chi nhánh - tức tầng thứ ba là ca
sẽ tới.

Vì `parent_id` vốn không giới hạn độ sâu, viết bộ giải đệ quy ngay từ đầu **không đắt hơn** viết
bộ giải một tầng, mà tránh được một lần đổi lược đồ về sau. Ba ràng buộc kèm theo:

- **Trần độ sâu là một hằng** (đề xuất 5), kiểm ở service. Vượt trần thì từ chối `422` và nói ra
  con số, không âm thầm cắt.
- **Chặn vòng lặp cha-con** lúc GHI `parent_id`, không lúc đọc: một vòng lặp đã vào database thì
  mọi câu đọc sau đó đều treo. Phép kiểm là đi lên từ nút cha đề xuất, gặp lại chính mình thì
  từ chối `422`.
- **Test chỉ khoá hai tầng.** Tầng thứ ba chạy được nhưng không được cam kết, và điều đó phải
  ghi ra chứ không để người sau tự đoán.

# ADR-0022: Bảng `units` có đúng một đường ghi công khai là tạo mới, không sửa và không xoá

**Status:** Accepted (2026-08-21)

## Context

Ở thời điểm quyết, `units` là một trong ba bảng thuộc nhóm `reference_tables` của registry
`C-DB-04` ([ADR-0003](ADR-0003-multi-tenant-ready.md)), cùng `currencies` và `provinces`.
Nhóm đó có hai tính chất, và cả hai đều quan trọng cho quyết định này: bảng trong nhóm
**không có `company_id`** — nó là danh mục dùng chung giữa mọi tenant — và bảng trong nhóm
**được mọi module đọc mà không phải khai** trong `module.yaml`, đúng ngoại lệ mà R-02 và
R-06 cấp.

Ba bảng đó cố ý **không có module chủ**. Lý do ghi ở `99-meta/pham-vi-he-thong.md` mục 3:
đặt một danh mục dùng chung dưới `modules/<A>` là trao quyền sở hữu cho module nào tình cờ
đọc nó trước, và từ đó mọi module sau phải xin phép một module không liên quan gì để đọc một
bảng ai cũng đọc được.

Vì không có module chủ, `units` cũng không có đường ghi nào ở tầng HTTP. Nó có đúng **một**
đường ghi, và đường đó nằm ngoài ứng dụng: lệnh dòng lệnh `cmd/dev seed-units` của
`backend-erp`, ghi qua một repository nhỏ ở `cmd/internal/danhmuc` — chỗ mà quy tắc
`internal/` của Go chặn mọi thứ ngoài cây `cmd/` import tới, cùng lý lẽ mà
[ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md) đã dùng cho bảng vai trò. Lệnh đó nạp
mười bốn đơn vị chuẩn: `cai`, `bo`, `tam`, `cuon`, `thung`, `hop`, `bao`, `g`, `kg`, `tan`,
`m`, `m2`, `m3`, `l`.

Điều đó đủ cho tới chặng có màn hình vật tư thật. Ở đó nó hết đủ: `stock_items.unit_id` là
`NOT NULL`, ô chọn đơn vị trên form vật tư chỉ đọc `GET /api/v1/units`, và người dùng cần một
đơn vị ngoài mười bốn dòng kia thì **không có đường nào đi tiếp** — không nút thêm, không màn
danh mục, và lệnh `seed-units` thì đòi một người có quyền vào máy chủ và một bản Go, mà máy
dev không có Go.

Cùng thời điểm, `CONTEXT.md` đã chốt sẵn nửa còn lại của câu chuyện trong chính định nghĩa
thuật ngữ **Đơn vị tính**: "Dùng chung cho mọi module, nên thêm được nhưng **không sửa và
không xoá** — sửa một đơn vị đang dùng là làm sai toàn bộ số lượng lịch sử trỏ vào nó." Từ
điển nói "thêm được", nhưng hệ thống chưa có chỗ nào để thêm.

Bảng vai trò lúc đó đã theo khuôn `<module>.<vai_trò>` của
[ADR-0021](ADR-0021-vai-tro-theo-module.md), và `units` đã có đúng một permission —
`inventory.unit_list`, mang tiền tố của một module không sở hữu bảng, vì chuỗi permission
phải gọi tên một module có thật.

## Decision

**Bảng `units` có đúng một đường ghi công khai — `POST /api/v1/units` tạo một đơn vị tính mới
— và không bao giờ có đường sửa hay đường xoá.**

Phạm vi:

- Endpoint mang permission mới `inventory.unit_create`, giữ tiền tố `inventory` cùng lý do
  đã dùng cho `inventory.unit_list`: chuỗi permission phải gọi tên một module có thật.
- **Không** `PATCH /units/:id`, **không** `DELETE /units/:id`. Đây là mệnh đề vĩnh viễn, không
  phải "chưa làm ở chặng này". Mở một trong hai cửa đó về sau đòi một ADR thay thế ADR này,
  chứ không phải một PR.
- `units` **vẫn** thuộc `reference_tables` ở registry `C-DB-04` với `adr: ADR-0003`. Phân loại
  không đổi, registry không sửa. Thứ đổi là ai được đẻ ra một dòng, không phải bảng thuộc nhóm
  nào.
- `units` **vẫn không** có tên trong khối `tables` của `modules/inventory/module.yaml`. Khai
  tên nó ở đó là khai quyền **sở hữu**, và quyết định này không cấp quyền sở hữu cho ai.
- Đường ghi cũ `cmd/dev seed-units` **ở lại**. Hai đường cùng sống.
- Quyết định này **không** đổi ADR-0003 và **không** đổi ADR-0010: `reference_tables` vẫn là
  danh mục dùng chung không thuộc tenant nào, và đường nạp dữ liệu nền vẫn ở composition root.

Hệ quả trực tiếp nhất, và nó phải nằm trong chính mục Decision vì nó là thứ người ta sẽ ngạc
nhiên nhất khi đọc lại: **bảng không có `company_id`, nên một đơn vị tính do người dùng của
một phân vùng tạo ra hiện ngay trong ô chọn của mọi phân vùng khác.** Không có bộ lọc nào ở
giữa, và không thêm được bộ lọc nào mà không thêm cột. Quyết định này chấp nhận điều đó.

Vì sao cấm sửa và cấm xoá, nói cho hết: một đơn vị tính đã được vật tư dùng thì `unit_id` của
mọi dòng vật tư và, qua đó, ý nghĩa của mọi con số lượng trong sổ chuyển động đều treo vào nó.
Đổi `kg` thành `tan` không làm hỏng một hàng nào về mặt ràng buộc — khoá ngoại vẫn hợp lệ,
không câu lệnh nào đỏ — nó chỉ làm toàn bộ lịch sử tồn kho nói sai đi một nghìn lần. Đó là
loại sai không ai phát hiện, vì không có chỗ nào để phát hiện: không màn hình nào đỏ, không
log nào kêu, và người duy nhất biết đã đổi là người vừa đổi. Xoá mềm thì nhẹ hơn một bậc mà
vẫn cùng loại: dòng `units` biến khỏi ô chọn trong khi vật tư cũ vẫn trỏ vào nó, và màn hình
phải bày một vật tư không đọc nổi đơn vị của chính nó.

## Alternatives

**Giữ nguyên: chỉ có đường seed, không mở endpoint nào** — loại vì nó bỏ người dùng ở một chỗ
không có đường ra. Đây không phải bất tiện mà là bế tắc: `stock_items.unit_id` là `NOT NULL`,
nên thiếu một đơn vị tính là **không tạo được vật tư**, và đường vòng duy nhất đòi một người
có quyền SSH vào máy chủ cộng một bản Go trên máy đó — mà máy dev không có Go, nên đường vòng
ấy hôm nay cũng không đi được. Thêm nữa, nó đi ngược chính từ điển của dự án: `CONTEXT.md` đã
định nghĩa đơn vị tính là thứ "thêm được", và một hệ thống mà từ điển của nó nói được còn hệ
thống nói không thì một trong hai bản phải sai.

**Làm CRUD đầy đủ cho `units` — thêm, sửa, xoá** — loại. Đây là phương án tốn ít suy nghĩ nhất
và là phương án hỏng nặng nhất, vì cái giá của nó không rơi vào lúc bấm nút mà rơi vào sáu
tháng sau: sửa một đơn vị đang được vật tư dùng làm sai toàn bộ số lượng lịch sử trỏ vào nó,
và trên một bảng **không có `company_id`** thì nó làm sai số lượng lịch sử của **mọi phân
vùng** cùng lúc, do một người của một phân vùng gây ra. Không có hàng phòng thủ nào ở dưới:
khoá ngoại chỉ đòi dòng `units` tồn tại, nó không đòi nghĩa của dòng đó giữ nguyên. Phương án
này cũng kéo theo một câu hỏi không ai muốn trả lời — xoá một đơn vị đang có vật tư trỏ vào
thì màn hình bày cái gì — trong khi cấm hẳn thì câu hỏi đó không tồn tại.

**Chuyển `units` ra khỏi `reference_tables` và làm nó thành bảng nghiệp vụ có `company_id`** —
loại, và đây là phương án đáng cân nhất trong ba cái. Nó xoá đúng khoản "Mất" nghiêm trọng
nhất ở dưới: mỗi phân vùng có danh mục đơn vị riêng, người của phân vùng A không làm bẩn ô
chọn của phân vùng B. Loại vì ba lý do đo được:

1. Nó là một **migration trên bảng đã có dữ liệu**: thêm `company_id NOT NULL` vào `units`
   buộc phải quyết mười bốn dòng seed thuộc về công ty nào, và đổi `uq_units_code` từ unique
   toàn hệ sang unique theo công ty. Chi phí bất đối xứng mà ADR-0003 đã mô tả nằm đúng ở đây,
   chỉ khác chiều.
2. Nó **nhân mười bốn dòng seed lên theo số phân vùng**, và biến `cmd/dev seed-units` từ một
   lệnh chạy một lần thành một lệnh phải chạy lại mỗi lần mở phân vùng mới — tức một bước thủ
   công nữa trong luồng tạo phân vùng, đúng loại việc mà quên là hỏng.
3. Nó **không mua lại được gì hôm nay**. Hệ đang có đúng một khách hàng thật (ADR-0003 mục
   Context), nên "danh mục đơn vị của A lẫn sang B" hôm nay là một rủi ro chưa có B để xảy ra.
   Trả trước một migration đắt cho một rủi ro chưa có người chịu là ngược với chính lối cân
   của ADR-0003.

Ngày một khách hàng thật đòi danh mục riêng, đường đi đã biết và ghi ở mục Nợ để lại.

**Đặt endpoint ghi ở `cmd/internal/danhmuc` thay vì trong module `inventory`** — loại. Nó
nghe hợp lý vì đường ghi hiện có đã ở đó và vì `units` không có module chủ, nhưng nó hỏng ở
chỗ không nhìn thấy ngay: `cmd/` nằm ngoài `modules/`, mà bộ kiểm `arch` nhận tầng của một
file theo **đường dẫn và hậu tố tên file**. Một handler và một phép kiểm quyền sống ở `cmd/`
vì vậy rơi ra ngoài tầm của R-03, R-15 và phần lớn checker còn lại — tức đường ghi công khai
duy nhất vào một bảng dùng chung toàn hệ sẽ là đoạn code **ít được canh nhất** trong repo.
Đó đúng là cái bẫy mà `unit_repository.go` của module đã mô tả khi giải thích vì sao một câu
SQL phải nằm ở `*_repository.go` chứ không ở `*_service.go`: một câu xanh vì không ai nhìn thì
lần sửa sau không có ai canh. Endpoint vì vậy ở lại `modules/inventory`, cạnh ba file `unit_*`
đã có, và đi cùng chúng vào ngày điều kiện chuyển đi được kích hoạt.

## Consequences

**Được:**

- Người dùng tự thêm được đơn vị tính ngay trong form vật tư, nên thiếu một đơn vị không còn
  chặn việc tạo vật tư. Bế tắc ở mục Context biến mất mà không cần ai vào máy chủ.
- Từ điển và hệ thống khớp nhau: `CONTEXT.md` nói "thêm được nhưng không sửa và không xoá", và
  từ nay hệ thống thi hành đúng ba vế đó, không phải hai.
- Cấm sửa và cấm xoá bằng **cách không có endpoint** chứ không bằng một quy tắc phải nhớ. Không
  có gì để lách, và không cần một checker nào canh.
- Mỗi lần thêm để lại dấu vết đầy đủ: bản ghi audit `unit.created` mang `company_id` của actor,
  đúng điều R-17 đòi ở phần Ngoại lệ dành cho `reference_tables`. Bảng `units` tự nó không nhớ
  phân vùng nào đẻ ra một dòng; `audit_logs` là chỗ duy nhất trả lời được câu đó.

**Mất:**

- **Danh mục đơn vị tính trở thành một không gian tên dùng chung mà người dùng cuối ghi được.**
  Một người của phân vùng A gõ `thung-20l` thì mọi phân vùng thấy nó, và không ai gỡ được vì
  không có đường xoá. Danh mục sẽ bẩn dần theo thời gian, và tốc độ bẩn tỉ lệ với số phân vùng.
- **Quyết định này khó đảo, và khó đảo theo nghĩa mạnh nhất:** một khi đường ghi công khai tồn
  tại, dữ liệu do người dùng tạo ra sẽ tồn tại và không rút lại được. Đóng endpoint lại không
  xoá được những dòng đã sinh, và cũng không xoá được những vật tư đã trỏ vào chúng.
- Trùng mã là trùng **toàn hệ**: người dùng của A gặp lỗi trùng vì một mã do người của B tạo,
  và họ không nhìn thấy lý do. Thông điệp lỗi vì vậy không nói được "ai đang giữ mã đó".
- Một mã lỗi nữa phải giữ (`ERR_INVENTORY_UNIT_CODE_DUPLICATED`), vì mã trùng có sẵn của
  `inventory` mang mệnh đề "trong cùng một công ty" — mệnh đề đó sai với bảng này.
- Module `inventory` từ nay **ghi** vào một bảng nó không sở hữu. Ngoại lệ `reference_tables`
  của R-02 nói về vế **đọc**, nên vế ghi được cấp phép bởi chính ADR này chứ không bởi rule.
  Điều kiện chuyển đi của bốn file `unit_*` vì vậy nặng thêm: ngày chúng rời `inventory`, thứ
  phải chuyển gồm cả một đường ghi, một permission ghi và một nhánh dịch lỗi.
- `inventory.thu_kho` nhận `inventory.unit_create` nhưng hôm nay **chưa dùng được**: vai trò đó
  không có `inventory.item_create` nên không mở được form vật tư ở chế độ ghi. Đây là một dòng
  chết trong bảng vai trò, cùng loại với dòng `auth.user_assign_scopes` của `machine.admin` mà
  ADR-0021 đã ghi ra.

  **Đính chính 2026-08-22 khi thi công.** Câu trên nói `inventory.thu_kho` "nhận"
  `inventory.unit_create`. Nó **chưa nhận**, và sẽ không nhận theo đường mà ADR này ngụ ý.
  [ADR-0023](ADR-0023-vai-tro-xuong-database.md) mục Alternatives **loại** phương án thêm
  permission vào hằng Go của `inventory.thu_kho`; việc cấp quyền danh mục cho vai trò đó thuộc
  **bộ nạp dữ liệu** của đợt vai-trò-xuống-database. Nên bản thi công `POST /api/v1/units` chỉ
  cấp `inventory.unit_create` cho `inventory.admin`, và hộp thoại thêm nhanh phục vụ admin lúc
  dựng danh mục. Thủ kho dùng được sau khi ADR-0023 lên — không phải chỗ bỏ sót, là thứ tự.

**Nợ để lại:**

- **Bộ kiểm không phân biệt được câu đọc với câu ghi trên bảng `reference_tables`.** `checkR02`
  của `backend-erp/arch` lấy tên bảng ra khỏi câu SQL rồi bỏ qua nếu bảng thuộc một trong ba
  nhóm dùng chung, không xét câu lệnh là `SELECT` hay `INSERT`. Trong khi đó văn bản R-02 chỉ
  cấp ngoại lệ cho vế đọc. Nghĩa là câu `INSERT INTO units` mới **xanh vì không ai nhìn**, chứ
  không phải vì đã qua kiểm. ADR này là chỗ duy nhất ghi rằng câu ghi đó được cấp phép. Việc
  còn phải làm: hoặc sửa văn bản R-02 cho khớp thực tế bộ kiểm, hoặc dạy `checkR02` phân biệt
  đọc/ghi rồi đòi một danh sách khai tường minh cho vế ghi. Chưa quyết, và không quyết ở đây.
- **Ngày một khách hàng đòi danh mục đơn vị riêng theo phân vùng**, đường đi là thêm cột
  `company_id` cho phép `NULL` (`NULL` nghĩa là dòng dùng chung), đổi `uq_units_code` thành hai
  partial unique index, và đổi phân loại của `units` ở registry `C-DB-04`. Đó là một ADR mới
  thay thế ADR này, và nó chạy trên một bảng **đã có dữ liệu người dùng** — đắt hơn hẳn hôm
  nay. Ghi ra để ngày đó không ai tưởng là việc nhỏ.
- **Chưa có gì dọn được một dòng gõ nhầm.** Không đường xoá là một quyết định có chủ đích, nhưng
  nó để lại một câu hỏi vận hành thật: ai đó gõ `kgg` thì dòng đó nằm trong ô chọn của mọi
  người mãi mãi. Hôm nay đường duy nhất là `UPDATE ... SET deleted_at` bằng tay qua `psql`, và
  nó chỉ an toàn khi chưa vật tư nào trỏ vào dòng đó. Ngày việc này xảy ra đủ nhiều để phiền,
  chỗ đúng để giải là một thao tác **quản trị** có kiểm điều kiện "chưa ai dùng", không phải mở
  `DELETE` cho người dùng thường.
- **`inventory.thu_kho` cần `inventory.item_create` thì chốt "thêm tại chỗ khi đang gõ dở một mã
  hàng" mới thành sự thật với thủ kho.** Nội dung vai trò đó do ADR-0021 mục 2 chốt và ADR là
  bất biến, nên đổi nó đòi một ADR riêng. Chưa quyết.
- **Hai đường ghi cùng sống** — endpoint và `cmd/dev seed-units` — và chúng không đá nhau vì
  chống trùng nằm ở `uq_units_code` chứ không ở tầng Go của bên nào. Một lệch nhỏ còn lại: lệnh
  seed bỏ qua im lặng dòng đã có (`ON CONFLICT DO NOTHING`) còn endpoint trả 409. Đó là hành vi
  đúng của từng bên, nhưng nó nghĩa là hai đường **không** thay thế nhau được và cả hai phải
  được giữ cho khớp khi danh mục chuẩn đổi.

**Constrains:** —

# ADR-0020: Data Scope là một tập bản ghi treo vào một hàng gán vai trò, giải ở tầng service, không đi vào token

**Status:** Accepted (2026-08-20)

## Context

Ở thời điểm quyết, hệ thống đã có ba tầng phân quyền chạy thật và không tầng nào trả lời
được câu hỏi thứ tư.

Tầng danh tính: `shared/middleware/auth` là nơi duy nhất verify JWT (R-14) và cho ra
`auth.Actor{UserID, CompanyID, Roles}`. Tầng cách ly phân vùng: mọi câu SQL mang
`company_id = $1` lấy từ `actor.CompanyID` (R-06), canh bằng một checker tĩnh ở mức
`PARTIAL` — nó thấy được mệnh đề, không thấy được giá trị đến từ đâu. Tầng RBAC:
`authz.Checker.Can(ctx, actor, perm)` với bảng vai trò → permission tiêm từ
`cmd/internal/vaitro` ([ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md)), mặc định CẤM,
và R-15 bắt câu lệnh **đầu tiên** của mọi method public trên `*Service` phải là một lời gọi
`s.authz.Can`.

Câu hỏi thứ tư — *trong số các bản ghi người này có quyền đọc, người này được thấy những bản
ghi nào* — chưa có một dòng code nào, một cột nào, một claim nào. Grep toàn repo cho
`data_scope`, `Scope`, `Filter`, `QueryOption` không ra gì ngoài `shared/db.Option` (mở kết
nối) và `arch/internal/loader.Scope` (của chính bộ kiểm kiến trúc).

Cái giá của khoảng trống đó đã cụ thể. Module `inventory` đã xong với ba bảng `warehouses`,
`stock_items`, `stock_movements` và mười lăm permission. Hai người cùng mang
`inventory.balance_read` — một thủ kho khu vực và một người quản lý toàn bộ kho — nhìn thấy
**y hệt nhau**: toàn bộ kho của công ty. Không có đường nào phân biệt, và chín module còn
lại của [ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) sẽ mang theo cùng khoảng
trống đó.

[ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) mục 4 đã chừa sẵn chỗ treo — *"Data Scope treo
vào `user_company_roles.id`, dù vai trò còn ở code hay sau này chuyển xuống database"* —
nhưng chính hai bảng `user_companies` và `user_company_roles` thuộc giai đoạn hai và chưa
tồn tại. ADR đó cố ý **không** trả lời hình dạng của scope, mặc định khi không có dòng nào,
cách "toàn phạm vi" được biểu diễn, hay nơi scope được giải.

Ba ràng buộc kỹ thuật có sẵn, đều thu hẹp không gian lời giải:

- `C-GO-07` bắt mọi câu SQL là một `const` BasicLit đơn — cấm `fmt.Sprintf`, cấm nối chuỗi,
  cấm query builder. Một danh sách `IN ($3, $4, ...)` dựng động **không viết ra được**.
- R-15 bắt câu lệnh đầu tiên là `authz.Can`. Một cửa `if actor.LaQuanLy` không đi qua được
  luật đó — cùng lý do ADR-0019 mục 5 đã chọn vai trò dẫn xuất thay vì một cờ đọc thẳng.
- ADR-0019 mục 9 đã chốt `AccessTTL = 15m` và đã **loại** blacklist `jti`. Access token là
  JWT stateless, không thu hồi được.

Cuối cùng, `shared/authz/authz.go` ghi sẵn một mệnh đề mà lời giải phải tôn trọng: *"Khi cần
thêm một ca kiểm quyền mới thì mở rộng `Can`, không mở API thứ hai."*

## Decision

**Data Scope là một tập id bản ghi, treo vào một hàng `user_company_roles`, giải ở tầng
service ngay sau `authz.Can`, và đi xuống repository dưới dạng một kiểu đóng.**

Chín điều làm rõ phạm vi:

**1. Một bảng đa hình.** `user_company_role_scopes(company_id, user_company_role_id,
scope_type TEXT, scope_id UUID)`, partial unique trên cả bốn cột nghiệp vụ. Một bảng cho mọi
loại tài nguyên, không phải một bảng cho mỗi loại. `scope_type` là **chuỗi**, không enum,
không CHECK — cùng lập luận ADR-0010 dùng cho `role_code`: một CHECK ở schema là bản thứ hai
của một danh sách vốn sống trong code.

**2. `scope_id` không mang khóa ngoại.** Nó trỏ tới bản ghi của một module khác — hôm nay là
`warehouses.id` của `inventory`. Một FK ở đây là một cạnh phụ thuộc ở tầng database từ `auth`
sang `inventory` mà không ADR nào cấp. Tiền lệ là `audit_logs.entity_id`, không FK vì cùng
lý do.

**3. Mặc định là KHÔNG THẤY GÌ.** Không có dòng scope nào cho một cặp (hàng gán vai trò,
`scope_type`) nghĩa là người đó **chưa được cấp gì**, không phải "được cấp tất cả". Một người
được gán vai trò mà quên gán scope sẽ đăng nhập được và thấy màn hình trống.

**4. "Toàn phạm vi" là một permission, không phải một cột.** Vai trò cần thấy tất cả được cấp
một permission riêng theo khuôn `<module>.<tài_nguyên>_scope_all` trong `vaitro.Bang()`. Ba
lý do: nó đi qua đúng bộ máy `authz` đang chạy nên R-15 không phải nới; bảng vai trò nói thật
ai thấy được gì mà không phải đi đọc một cột boolean trong database; và nó là **cùng một nước
đi** ADR-0019 mục 5 đã dùng khi từ chối `if !actor.SystemAdmin` để chọn vai trò dẫn xuất.

**5. Resolver luôn trả về một danh sách id cụ thể**, kể cả ca toàn phạm vi — lúc đó danh sách
là toàn bộ id đang sống của loại đó trong phân vùng. Nhờ vậy repository có **đúng một** hình
dạng câu SQL, không có nhánh `if toàn bộ` để ai đó quên.

**6. Scope không đi vào JWT và không đi vào `auth.Actor`.** Nó được giải lại ở mỗi request
chạm tài nguyên chịu phạm vi. Không cache ở vòng đầu.

**7. Truyền bằng một kiểu đóng.** `shared/scope.Pham` có field không xuất khẩu, nên không ai
ngoài package đó dựng được một `Pham` mang id, và đường duy nhất có một `Pham` là đi qua
`Resolve`. `shared/scope` chỉ biết chuỗi và `[]string`; hai hợp đồng `Doc` (đọc dữ liệu cấp
phát) và `Nguon` (liệt kê toàn bộ id của một loại trong phân vùng) được cài đặt ở module sở
hữu dữ liệu và **nối dây ở `cmd/api`** — đúng khuôn `vaitro.Bang()` đang chạy, và đúng lý do
R-04 cấm `shared/` import `modules/`.

**8. Canh bằng một Convention, không bằng một Rule mới.** Mỗi module khai khối `scoped_tables`
trong `module.yaml` (bảng nào, lọc theo cột nào), và `C-GO-09` kiểm ba vế: câu SQL chạm bảng
đã khai phải mang mệnh đề lọc; bảng khai mà không câu nào chạm là khai thừa; module nhận
`scope.Pham` vào chữ ký mà không khai `scoped_tables` là dùng lén. Không thêm R-rule nào, nên
`RULES.md` và băm ghim của nó không đổi.

**9. Quyết định này KHÔNG áp lên bảng không có cột trỏ tới tài nguyên phân phạm vi.**
`stock_items` là danh mục vật tư cấp công ty — một vật tư không thuộc kho nào, nó có *tồn* ở
nhiều kho. `units` là `reference_tables`. Cả hai chỉ chịu cách ly phân vùng theo `company_id`.
Phạm vi của một vật tư được nhìn thấy **qua chuyển động của nó**, không qua một cột trên chính
nó.

## Alternatives

**Nhét danh sách id vào JWT** — loại vì nó ép mở lại hai thứ ADR-0019 mục 9 đã chốt. Scope
trong token chỉ đổi được ở lần xoay token kế tiếp, tức thu hồi một kho vẫn còn hiệu lực **tối
đa 15 phút**; muốn ngắn hơn thì phải rút `AccessTTL`, muốn ngắt ngay thì phải có blacklist
`jti` — đúng hai điều ADR đó đã cân và đã loại. Kích thước cũng là một giới hạn đo được:
200 kho × 36 ký tự là khoảng 7 KB sau base64, vượt giới hạn header mặc định của nhiều proxy.
Và với người mang nhiều vai trò, token sẽ mang **kết quả đã tính** thay vì dữ liệu, nên không
ai truy được vai trò nào cấp kho nào.

**Một cột `is_all BOOLEAN` trên `user_company_roles`, hoặc một dòng `scope_id NULL` nghĩa là
tất cả** — loại vì cả hai tạo nguồn sự thật thứ hai cho câu hỏi "ai được thấy tất cả", và cả
hai hỏng về phía **mở**: quên set cờ thì người dùng thấy nhiều hơn được phép, và không có gì
báo. Phương án được chọn hỏng về phía đóng — màn hình trống, người dùng gọi điện ngay trong
ngày đầu.

**Mỗi loại tài nguyên một bảng scope riêng** (`user_warehouse_scopes`,
`user_customer_scopes`, …) — loại vì nó thành mười hai bảng cho mười hai module, và vì
resolver khi đó phải biết tên từng bảng để chọn câu SQL. Biết tên bảng nghiệp vụ là điều
`shared/` không được phép (R-04), nên resolver sẽ phải chuyển xuống từng module, và mỗi module
sẽ có một bản dịch riêng của cùng một quy tắc fail-close. Đổi lại, phương án được chọn mất
khả năng đặt khóa ngoại thật cho từng loại — cái giá đã ghi ở mục 2.

**Mở rộng `authz.Can` thành `Can(ctx, actor, perm, resourceID)`, hoặc thay bằng một policy
engine như Casbin** — loại vì nó trả lời sai câu hỏi. `Can` trả lời *"loại việc này actor có
được làm không"*, một câu hỏi không cần chạm database; câu hỏi phạm vi là *"trên tập nào"*, và
nó phải chạm database ở mọi lần hỏi. Gộp hai câu vào một chữ ký làm mọi lời gọi `Can` hiện có
— hàng trăm chỗ, trong đó phần lớn không có `resourceID` nào để đưa — phải mang một tham số vô
nghĩa, và làm đường kiểm quyền rẻ nhất của hệ thống trở thành đường tốn một round-trip. Ghi
chú ở `shared/authz/authz.go` nói "mở rộng `Can`, không mở API thứ hai" nói về **ca kiểm
quyền**; `Resolve` không phải một ca kiểm quyền, nó là một phép tra cứu — cùng hạng với
`VaiTroTonTai`, thứ đã đứng cạnh `Can` trong chính interface đó vì đúng lý do này.

**Truyền `[]string` thẳng xuống repository thay vì một kiểu đóng** — loại vì nó tốn ngang
nhau lúc viết và khác hẳn lúc **quên**. Một `[]string` ai cũng dựng được, kể cả `nil`, và hai
giá trị `nil` với `[]` lẫn nghĩa. Quên áp phạm vi khi đó cho ra một câu truy vấn chạy đúng,
trả về nhiều dữ liệu hơn được phép, và không ai biết. Với kiểu đóng, quên là một **lỗi biên
dịch**. Data Scope là một lớp an ninh; nó phải hỏng ồn ào.

**Không làm gì — để mỗi service tự viết điều kiện lọc khi cần** — loại vì đó chính là cách
`company_id` đang được bảo đảm, và mức bảo đảm đó đã đo được: R-06 đứng ở `PARTIAL`, và lý do
ghi ngay trong `arch/rules.go` là checker thấy có điều kiện nhưng không thấy giá trị nào được
truyền vào. Lặp lại cùng một cơ chế cho một lớp nữa là nhân đôi một vùng mù đã biết, ở đúng
lúc còn rẻ để không nhân đôi.

## Consequences

**Được:**

- Ba câu hỏi khác nhau có ba nguồn sự thật khác nhau và ba nhịp đổi khác nhau: "có vai trò gì"
  ở `user_company_roles` (vào token, đổi có hiệu lực ≤15 phút), "vai trò áp ở phạm vi nào" ở
  `user_company_role_scopes` (đổi có hiệu lực ngay), "thấy record nào" là kết quả `Resolve`.
- Quên áp phạm vi là lỗi biên dịch, không phải lỗ hổng im lặng. Đây là bảo đảm mà R-06 hôm nay
  **không** có.
- R-15, R-06, `authz.Checker` và `auth.Actor` không phải đổi một chữ. Bộ kiểm không phải nới
  mức nào.
- Cơ chế dùng lại được cho cả mười hai module: module mới chỉ khai `scoped_tables` và nhận
  `scope.Pham`; `shared/scope` không phải biết thêm gì.

**Mất:**

- Một round-trip database cho mỗi request chạm tài nguyên chịu phạm vi. Chưa cache, nên con số
  thật chưa ai biết.
- Không diễn tả được "xem được kho A và B, nhưng chỉ ghi được vào kho A": phạm vi hôm nay là
  một tập chung cho mọi permission của cùng một hàng gán vai trò.
- Không có phạm vi phân cấp. "Khu vực miền Bắc gồm kho A và B" phải khai bằng hai dòng, và hai
  dòng đó không tự đổi khi khu vực đổi.
- Xóa mềm một bản ghi không tự dọn dòng scope trỏ tới nó — hệ quả trực tiếp của việc `scope_id`
  không mang khóa ngoại. Dòng thừa vô hại về đọc, nhưng nó tích tụ.
- Người được gán vai trò mà quên gán phạm vi thấy màn hình trống, không có thông báo nào giải
  thích vì sao. Đây là mặt trái đã chọn có ý thức của mục 3.
- Vai trò có quyền tạo mà bị giới hạn phạm vi sẽ **tạo được** một bản ghi rồi **không đọc lại
  được** nó: bản ghi mới chưa có id nên không có gì để lọc lúc tạo, và cửa duy nhất lúc đó là
  permission tạo.

**Nợ để lại:**

- Chưa có đường API nào để **gán** phạm vi cho một người. Hôm nay việc đó phải làm bằng câu
  `INSERT` trực tiếp. Màn hình phân quyền là việc của một chặng riêng.
- Chưa đo hiệu năng, nên chưa quyết được có cần cache hay không. Nếu cần, hình dạng đầu tiên
  nên thử là cache trong tiến trình với TTL vài giây, đủ ngắn để giữ mệnh đề "đổi có hiệu lực
  ngay" ở mục 6; Redis kéo theo bài toán vô hiệu hóa và phải là một quyết định riêng.
- Mục 5 — resolver trả danh sách id cụ thể — **chỉ đúng khi lực lượng của tập nhỏ**. Một công
  ty có hàng chục kho thì không sao. Ngày có một `scope_type` với hàng chục nghìn phần tử
  (khách hàng, vật tư), quyết định đó phải được cân lại bằng một ADR mới; đây là **điều kiện**,
  không phải khuyến nghị.
- `C-GO-09` vế 1 cố ý nới một chỗ: câu SQL chạm nhiều bảng chịu phạm vi chỉ cần mang mệnh đề
  lọc của **ít nhất một** bảng. Nới vì câu tính tồn kho đã chốt tập hàng bằng bảng chuyển động
  rồi mới `JOIN` sang bảng kho. Cái giá là một câu chạm hai bảng mà chỉ lọc bảng sai sẽ lọt.
- `C-GO-09` không kiểm được câu `WITH`, và không kiểm được rằng giá trị truyền vào mệnh đề lọc
  đúng là `pham.IDs()` — cùng loại vùng mù data-flow mà R-06 đã có.

**Constrains:** —

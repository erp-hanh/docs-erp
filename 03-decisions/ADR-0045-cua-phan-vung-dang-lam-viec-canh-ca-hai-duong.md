# ADR-0045: Cửa "phân vùng đang làm việc" canh cả đường ngừng sử dụng lẫn đường xoá, và so định danh bằng một hàm dùng chung chứ không bằng phép so chuỗi trần

**Status:** Accepted (2026-08-29)

## Context

[ADR-0044](ADR-0044-ngung-su-dung-phan-vung-tach-khoi-xoa.md) được chấp nhận ngày 2026-08-29 và
được thi công ngay trong ngày. Mâu thuẫn dưới đây lộ ra **lúc thi công**, không lúc viết ADR-0044.

ADR-0044 mục 4 chốt cửa "không thao tác được trên phân vùng mà chính actor đang làm việc", và
nói rõ cửa đó **chỉ cần** ở đường ngừng sử dụng, còn `DeleteCompany` **cố ý không** có nó. Lý do
nêu ra ở đó: `DeleteCompany` dựa vào cửa "còn người dùng" bắt trước, còn đường ngừng sử dụng
không có cửa nào bắt trước cả.

**Lập luận đó đúng ở thời điểm nó được viết.** Trước ADR-0044, cửa `SoNguoiDangHoatDong > 0` bắt
gần hết mọi ca thật: actor luôn có một hàng `users` còn sống trong phân vùng của chính mình - họ
vừa đăng nhập bằng nó - nên một phân vùng có actor đang đứng thì luôn còn ít nhất một người, và
`DeleteCompany` từ chối trước khi tới bước ghi. Người viết ADR-0044 mục 4 không bỏ sót một cửa;
họ đọc đúng cửa đang có và kết luận đúng rằng cửa thứ hai là thừa.

**Tiền đề ấy hết hiệu lực ngay trong cùng ADR.** Mục 5 nới chính cửa "còn người dùng" đó: cho xoá
khi số người đang hoạt động bằng 0, hoặc bằng 1 và người đó mang cờ `is_admin`. Sau mục 5, một
actor là người quản trị duy nhất của phân vùng mình đang đứng **đi lọt** cửa đếm người - và tới
thẳng bước xoá. Xoá thì không đảo lại được, còn ngừng sử dụng thì có. Mục 4 kết cục canh đúng
thao tác nhẹ hơn và bỏ ngỏ thao tác nặng hơn.

ADR-0044 là `Accepted`, và ADR bất biến. [ADR-0031](ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md)
mục 6 đã nói thẳng phép đính chính phải nằm ở một ADR riêng chứ không sửa câu chữ ADR cũ, và
[ADR-0038](ADR-0038-admin-phan-vung-dat-ra-vai-tro.md) mục 4 đã đi đúng lối đó khi đính chính tập
quyền "mười sáu thành mười tám" của ADR-0031. Đây là lần thứ ba.

**Dữ kiện thứ hai, phát hiện khi soi lại bản vừa thi công.** Cửa ấy - kể cả bản đã có ở đường
ngừng sử dụng - **đi lọt bằng một định danh viết HOA**. `laUUID` trong
`modules/auth/internal/service/user_service.go` là `uuid.Validate`, và hàm ấy **chấp nhận** hex
viết hoa, nên một id chữ hoa qua được cửa định dạng. Cửa "phân vùng đang làm việc" khi đó so hai
**chuỗi Go**, nên nó trượt. Nhưng `WHERE id = $1` thì Postgres parse tham số sang kiểu `uuid` rồi
mới so, và **vẫn khớp đúng hàng**. Hai phép so bất đồng: cửa nói "không phải phân vùng của bạn",
câu ghi ngay sau nó chạm đúng hàng cần chặn.

Điều **chưa biết** lúc quyết: còn bao nhiêu cửa khác trong hệ đang so định danh bằng `==` trên
chuỗi. Một cái đã thấy tên - `UserService.GoKhoiPhanVung` so `userID == actor.UserID` - nhưng
chưa được rà và không thuộc phạm vi đợt này.

## Decision

**Cửa "không thao tác được trên phân vùng mình đang làm việc" canh CẢ HAI đường - ngừng sử dụng
và xoá - bằng một hàm dùng chung `laCungPhanVung`, hàm này so định danh phân vùng theo đúng cách
Postgres so kiểu `uuid` chứ không bằng phép so chuỗi trần, và cả hai đường trả cùng mã
`ERR_AUTH_COMPANY_IS_CURRENT` với HTTP 409.**

Đây là **một** quyết định chứ không phải hai: một cửa trượt được thì không phải một cửa. Đặt cửa
ở đường thứ hai mà vẫn để nó so chuỗi trần thì đường thứ hai được canh trên giấy và bỏ ngỏ trên
máy - đúng cái khe vừa phát hiện.

**1. Đính chính ADR-0044 mục 4.** Câu *"`DeleteCompany` cố ý không có cửa này"* ở đó không còn
đúng sau chính mục 5 của cùng ADR. Câu chữ ADR-0044 **không sửa tại chỗ**; phép đính chính nằm ở
đây, theo tiền lệ ADR-0038 mục 4. ADR-0044 giữ nguyên `Accepted`: chỉ **một mục** của nó bị đính
chính, mọi mục còn lại vẫn có hiệu lực nguyên vẹn.

**2. Một hàm, hai chỗ gọi, không hai lần chép.** `laCungPhanVung` nằm trong
`modules/auth/internal/service/company_service.go` và được gọi từ `CompanyService.DeleteCompany`
và `CompanyService.DatTrangThaiSuDung`. Hai cửa này phải không bao giờ lệch nhau, và cách rẻ
nhất để chúng lệch là sửa một chỗ rồi quên chỗ kia.

**3. Hàm trả `false` khi một trong hai vế rỗng.** Một actor không mang phân vùng thì không "đang
làm việc" ở phân vùng nào, nên không có gì để chặn; cửa quyền và cửa tồn tại phía sau mới là chỗ
trả lời ca đó.

**4. Cửa chỉ canh chiều TẮT của ngừng sử dụng.** Chiều bật lại không cần nó: không ai đang làm
việc trong một phân vùng đã ngừng, và một cửa canh cả hai chiều sẽ chặn đúng đường cứu hộ.

**Không áp cho:** các cửa so định danh khác trong hệ. Mệnh đề "cửa trạng thái không so định danh
bằng phép so chuỗi trần" đúng ở mọi cửa cùng hình dạng, nhưng ADR này chỉ **thi công** nó ở hai
cửa của `companies`; rà phần còn lại nằm ở mục Nợ để lại.

## Alternatives

**Không thêm cửa ở đường xoá, chấp nhận khe đó** - loại, vì khe ấy đo được và hậu quả của nó
không đảo lại được. Ca cụ thể: một `quan_tri_he_thong` đang đứng ở phân vùng chỉ còn đúng mình
họ mang cờ `is_admin` - đúng hình dạng mà ADR-0044 mục 5 vừa cho phép xoá - bấm Xoá phân vùng và
mất phân vùng đang đăng nhập. Đây không phải ca giả tưởng: bài
`TestCompanyService_DeleteCompany_PhanVungDangLamViec_IdChuHoa_Tra409` dựng đúng một người mang
cờ `is_admin` chính vì cửa đếm người ở hình dạng đó **cho** đi qua. Và cửa nhẹ hơn - ngừng sử
dụng, đảo lại được - thì đã bị chặn: canh thao tác đảo lại được mà bỏ ngỏ thao tác không đảo lại
được là canh nhầm cửa.

**Sửa thẳng câu chữ ADR-0044 mục 4** - loại, vì nó vi phạm luật bất biến ghi ở đầu
`05-templates/ADR-template.md` và ADR-0031 mục 6 đã chốt riêng cho đúng tình huống này. Cái giá
không trừu tượng: sửa tại chỗ thì lập luận "cửa đếm người bắt trước" biến mất khỏi lịch sử, và
sáu tháng sau người đọc không có cách nào biết vì sao mục 4 từng viết như vậy, tức không phân
biệt được "quyết sai" với "quyết đúng trong hoàn cảnh đã khác". Hai lần trước hệ này đã trả lời
cùng một câu hỏi bằng cùng một cách (ADR-0038 mục 4 đính chính ADR-0031, ADR-0044 mục 1 đính
chính ADR-0019); đổi lối ở lần thứ ba là làm hỏng tiền lệ đang chạy.

**Thắt mục 5 của ADR-0044 lại, để cửa đếm người bắt như cũ** - loại, vì nó xoá đúng thứ ADR-0044
sinh ra để giải. Trước mục 5, mọi phân vùng tạo qua `POST /companies` đều mang sẵn một người
([ADR-0039](ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md)), nên `DeleteCompany` từ chối **mọi**
phân vùng tạo qua giao diện, và tạo nhầm một phân vùng thì không còn đường dọn nào ngoài một câu
`UPDATE` chạy tay trên production. Thắt lại là quay về đúng bế tắc đó để tránh một khe mà một cửa
mười dòng đóng được.

**Chuẩn hoá định danh về chữ thường ở tầng handler, rồi giữ phép so chuỗi trần** - loại, vì nó
đặt phép sửa ở xa chỗ hỏng. Cửa nằm ở service và nhận id qua tham số; một service được gọi từ
chỗ khác - test, một handler thứ hai, một job - sẽ nhận id chưa qua chuẩn hoá và cửa lại trượt,
lần này không còn dấu vết nào ở service để đọc ra. Phép so đúng thuộc về chính cửa, không thuộc
về đường đi tới nó.

**Parse cả hai vế bằng `uuid.Parse` rồi so hai giá trị `uuid.UUID`** - loại, dù nó đúng về mặt
kiểu. Nó buộc phải quyết một thứ không có câu trả lời tốt: parse hỏng thì trả gì. Trả `false` là
tái lập đúng khe vừa đóng (một id lạ đi lọt cửa); trả `true` là chặn nhầm. Ở đây id đã qua
`laUUID` ngay trên nó nên vế thứ nhất chắc chắn parse được, và vế thứ hai tới từ token; phép so
không phân biệt hoa thường cộng một cửa rỗng cho cùng kết quả trên **mọi** đầu vào hex mà không
sinh nhánh lỗi thứ ba nào phải test.

## Consequences

**Được:**

- Thao tác không đảo lại được nay được canh ít nhất bằng thao tác đảo lại được. Trước quyết định
  này thì ngược lại, và đó là thứ tự sai.
- Hai đường có **một** phép so, nên chúng không lệch được bằng cách sửa một chỗ quên chỗ kia.
- Khe "id viết HOA" có hai bài test đứng sau, mỗi đường một bài:
  `TestCompanyService_DeleteCompany_PhanVungDangLamViec_IdChuHoa_Tra409` và
  `TestCompanyService_DatTrangThaiSuDung_PhanVungDangDung_IdChuHoa_Tra409`. Cả hai kiểm cả mã lỗi
  lẫn trạng thái database sau khi bị từ chối, nên một cửa trượt mà câu ghi vẫn chạy thì đỏ.
- Mệnh đề "một cửa trạng thái so định danh bằng phép so chuỗi trần là sai ở hệ này" được ghi ra
  một lần, thay vì phải phát hiện lại ở từng cửa.

**Mất:**

- **Không ai còn xoá được phân vùng mình đang đứng, kể cả khi đó là việc đúng.** Muốn dọn một
  phân vùng tạo nhầm thì actor phải chuyển sang phân vùng khác trước rồi mới xoá. Với
  `quan_tri_he_thong` thì đường đó luôn có
  ([ADR-0036](ADR-0036-quan-tri-he-thong-di-duoc-moi-phan-vung.md) cho họ đi được mọi phân vùng),
  nhưng nó là một bước thật mà trước quyết định này không cần, và thông điệp lỗi phải tự dạy
  người dùng bước ấy.
- **ADR-0044 mục 4 từ nay chỉ đọc đúng khi đọc kèm ADR này, và trong file ADR-0044 không có gì
  trỏ tới đây.** ADR bất biến nên không thêm được một dòng dẫn. Ai đọc ADR-0044 một mình sẽ đọc
  ra một mệnh đề đã bị đính chính. Đây là cái giá thật của luật bất biến, và nó cộng dồn: mục 1
  của chính ADR-0044 đã là một phép đính chính ADR-0019.
- Phép so không phân biệt hoa thường **chỉ tình cờ trùng kết quả** với phép so kiểu `uuid` vì
  định danh phân vùng hôm nay là hex. Ngày định danh đổi hình dạng - hoặc ngày một cửa cùng khuôn
  đem hàm này áp lên một chuỗi không phải hex - phép so này sai, và nó sai im lặng.
- Một hàm nữa phải nhớ. Người viết cửa tiếp theo trong `company_service.go` phải biết `==` là sai
  ở đây, và không có gì trong ngôn ngữ nói cho họ biết - chỉ có khối bình luận trên
  `laCungPhanVung` và hai bài test.

**Nợ để lại:**

- **Điều kiện**, không phải khuyến nghị: mọi cửa trạng thái so một định danh lấy từ request với
  một định danh lấy từ actor phải đi qua một hàm so dùng chung, không so `==` trên chuỗi. Quyết
  định này chỉ đứng vững khi ranh giới đó được giữ, và nó **không có checker** - chỉ có hai bài
  test ở hai cửa của `companies`.
- Phần còn lại của hệ **chưa được rà**. Một chỗ đã biết tên: `UserService.GoKhoiPhanVung` so
  `userID == actor.UserID` để chặn "tự gỡ mình", đúng hình dạng vừa hỏng ở đây. Chưa ai đọc xem
  nó có đi lọt bằng id viết hoa không, và hậu quả của nó nhẹ hơn (gỡ người đảo lại được) nên nó
  không được gộp vào đợt này.
- Chưa có bài nào đi qua tầng HTTP cho khe này. Hai bài hiện có gọi thẳng service, nên chúng
  không nói gì về việc handler có tự chuẩn hoá id hay không - và nếu ngày nào đó handler chuẩn
  hoá, hai bài này vẫn xanh trong khi thứ chúng canh đã đổi chỗ.
- Chưa quyết: `laUUID` chấp nhận hex viết hoa là hành vi của `uuid.Validate`, và hệ đang sống
  chung với nó ở **mọi** cửa định dạng. Thắt `laUUID` lại thành "chỉ chữ thường" sẽ đóng cả lớp
  khe này một lần, nhưng nó đổi hành vi của mọi endpoint nhận `:id` và cần một ADR riêng.

**Constrains:** —

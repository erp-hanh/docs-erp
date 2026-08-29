# ADR-0046: Bộ lọc `is_active` trên `companies` chia theo trục "mở lối vào" so với "quét đủ", không theo trục "nghiệp vụ" so với "quản trị"

**Status:** Accepted (2026-08-29)

## Context

[ADR-0044](ADR-0044-ngung-su-dung-phan-vung-tach-khoi-xoa.md) được chấp nhận ngày 2026-08-29 và
được thi công ngay trong ngày, cùng đợt với
[ADR-0045](ADR-0045-cua-phan-vung-dang-lam-viec-canh-ca-hai-duong.md). Mâu thuẫn dưới đây lộ ra
**lúc thi công**, không lúc viết ADR-0044.

Phần "Nợ để lại" của ADR-0044 đặt một **điều kiện**, và nói rõ đó là điều kiện chứ không phải
khuyến nghị:

> mọi câu đọc `companies` phục vụ một đường **nghiệp vụ** phải lọc `is_active`; mọi câu đọc phục
> vụ **mặt quản trị** phải không lọc. Quyết định này chỉ đứng vững khi ranh giới đó được giữ, và
> nó không có checker - chỉ có hai bài test đi hai chiều.

**Câu chữ ấy hợp lý ở thời điểm nó được viết.** Lúc ADR-0044 quyết, hệ chỉ có **hai** loại chỗ
đọc `companies`, và chúng chia đôi gọn gàng đúng theo trục ấy. Một bên là màn chọn phân vùng lúc
đăng nhập - một danh sách để người dùng bấm. Bên kia là `selectCompanyByIDSQL` và ba câu
`listCompanies*` của mặt quản trị - nơi nút bật lại một phân vùng đã ngừng sống. Chính mục Mất
của ADR-0044 đã dùng đúng cặp đó để nói vì sao không được nhét `is_active` vào SQL của
`CompanyRepository.ByID`. Với hai điểm dữ liệu đang có, "nghiệp vụ / quản trị" là đường thẳng đi
qua cả hai, và nó là đường duy nhất ai cũng nghĩ tới.

**Chỗ đọc thứ ba lộ ra lúc thi công, và nó không nằm trên đường thẳng ấy.** Bản vá thêm bộ lọc
trạng thái vào ba câu SQL của `UserCompanyRepository.PhanVungTheoUser` -
`countPhanVungTheoUserSQL`, `listPhanVungTheoUserCodeTangSQL`, `listPhanVungTheoUserCodeGiamSQL`
trong `modules/auth/internal/repository/user_company_repository.go`. Việc ấy đúng cho màn chọn
phân vùng. Nhưng câu đó có **hai** chỗ gọi trong
`modules/auth/internal/service/auth_service.go`, và chỗ gọi thứ hai là
`AuthService.thuHoiPhienMoiPhanVung` - hàm duyệt mọi phân vùng của một người để thu hồi refresh
token khi đổi mật khẩu, thứ mà đính chính 2026-08-27 của
[ADR-0034](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md) mục 3 vừa dựng lên để đóng một lỗ
hổng thật. Bộ lọc chảy sang chỗ gọi ấy thì đổi mật khẩu **không còn thu hồi** phiên ở phân vùng
đang ngừng; mà ngừng sử dụng đảo lại được, nên bật phân vùng lên là refresh token cũ sống lại
nguyên vẹn - đúng thứ lệnh đổi mật khẩu sinh ra để dọn.

Đường thu hồi phiên **là** một đường nghiệp vụ theo mọi cách hiểu thông thường: nó chạy trong
`POST /auth/change-password`, do một người thật bấm, không phải màn quản trị nào. Theo câu chữ
ADR-0044 thì nó phải lọc. Nhưng nó phải **không** lọc. Trục "nghiệp vụ / quản trị" vì thế phân
loại sai, và cái sai của nó không phải một ngoại lệ lẻ - nó cắt nhầm ngay chỗ nguy hiểm nhất, vì
lỗi ở phía "quên quét đủ" thì im lặng.

Điều **chưa biết** lúc quyết: còn bao nhiêu câu đọc `companies` nữa sẽ ra đời, và khuôn "ngừng
sử dụng" khi áp cho các danh mục khác (vật tư, kho, khách hàng) có sinh ra cùng loại chỗ đọc
"quét đủ" này hay không.

## Decision

**Một câu đọc `companies` lọc `is_active` khi và chỉ khi nó MỞ MỘT LỐI VÀO - dựng một lựa chọn
để người dùng bấm, hoặc gác cửa cho một phiên đi tiếp - còn mọi câu phải QUÉT ĐỦ, tức dọn dẹp và
mặt quản trị, thì không lọc.**

- **Phép kiểm cho một chỗ đọc mới** là một câu hỏi, không phải một nhãn: *bỏ sót một phân vùng
  đang ngừng ở câu này thì hỏng cái gì?* Nếu hỏng là "người dùng thấy một lựa chọn chết" hoặc
  "một phiên đi tiếp được vào chỗ đã đóng" thì lọc. Nếu hỏng là "bỏ sót một thứ sẽ sống lại khi
  ai đó bật phân vùng lên" thì không lọc. Ngừng sử dụng đảo lại được (ADR-0044 mục 1), nên vế
  thứ hai không bao giờ là một bỏ sót vô hại.
- **Đính chính ADR-0044 phần "Nợ để lại".** Điều kiện *"mọi câu đọc `companies` phục vụ một
  đường nghiệp vụ phải lọc `is_active`; mọi câu phục vụ mặt quản trị phải không lọc"* được thay
  bằng câu trên. Câu chữ ADR-0044 **không sửa tại chỗ**, theo luật bất biến ở
  `05-templates/ADR-template.md` và tiền lệ [ADR-0038](ADR-0038-admin-phan-vung-dat-ra-vai-tro.md)
  mục 4, ADR-0044 mục 1, ADR-0045 mục 1. ADR-0044 giữ nguyên `Accepted`: chỉ **một điều kiện**
  trong phần Nợ để lại bị đính chính, mọi mục còn lại vẫn có hiệu lực nguyên vẹn - kể cả câu
  ngay sau nó, rằng ranh giới này **không có checker**.
- **Trục mới không đổi một hành vi nào đang chạy.** Bốn chỗ đọc hiện có đã ở đúng chỗ của chúng
  từ lúc thi công; ADR này đổi **cách gọi tên** ranh giới, để chỗ đọc thứ năm phân loại đúng.
- **Không áp cho:** bộ lọc `deleted_at` (R-18 canh riêng, và ADR-0044 mục 1 đã tách hai vế), và
  khuôn "ngừng sử dụng" của các danh mục khác. ADR này chỉ nói về `companies`.

**Bốn chỗ đọc hiện có.** Bảng này là phần chốt của quyết định chứ không phải phụ lục: một mệnh
đề trừu tượng thì không kiểm được, còn một bảng thì kiểm được.

| Chỗ đọc | Lọc `is_active`? | Vì sao theo trục trên |
|---|---|---|
| `AuthService.PhanVungCuaToi` - màn chọn phân vùng lúc đăng nhập | **có** | Mở lối vào: mỗi dòng trả về là một thứ để bấm. Bỏ lọc thì một phân vùng đã ngừng hiện ra để chọn, bấm vào nhận 404 vì `IDByCode` đã lọc sẵn |
| `CompanyRepository.ConSong` - cửa gia hạn phiên `POST /auth/refresh` | **có** | Gác cửa: nó trả lời "phiên này đi tiếp được không". Bỏ lọc thì phiên của một phân vùng vừa bị ngừng sống tiếp tới lúc hết hạn |
| `AuthService.thuHoiPhienMoiPhanVung` - thu hồi phiên khi đổi mật khẩu | **không** | Quét đủ để dọn: bỏ sót một phân vùng đang ngừng là để lại một refresh token sống lại nguyên vẹn khi ai đó bật phân vùng lên |
| `CompanyRepository.ByID` và ba câu `listCompanies*` - mặt quản trị | **không** | Quét đủ để trưng ra: đây là chỗ duy nhất bật lại được một phân vùng đã ngừng; lọc đi thì nút bật lại thành vô dụng |

Hai hàng cuối không lọc theo hai hình dạng khác nhau, và cả hai đều là "không lọc" theo nghĩa
của trục này: `selectCompanyByIDSQL` không có một chữ `is_active` nào, còn ba câu `listCompanies*`
mang một mệnh đề **do người dùng lái** - `($4 = '' OR ($4 = 'dang_dung' AND is_active) OR
($4 = 'ngung' AND NOT is_active))` - và mặt quản trị truyền thẳng lựa chọn xuống, kể cả rỗng.
Ràng buộc là câu SQL không được tự đóng cứng "chỉ đang dùng".

Hình dạng thi công của hai hàng đầu và hàng thứ ba nằm ở một chỗ: ba câu SQL của
`PhanVungTheoUser` mang mệnh đề **có điều kiện** `(c.is_active OR $2)`, và tham số thứ hai đến từ
trường `PhanVungQuery.KeCaPhanVungDaNgung`. Trường đặt ở **thể khẳng định**, nên zero value của
Go - `false` - là hành vi lọc, tức hành vi của màn chọn phân vùng; `PhanVungCuaToi` để mặc định,
còn `thuHoiPhienMoiPhanVung` đặt tường minh `KeCaPhanVungDaNgung: true`. Chiều mặc định chọn như
vậy để một chỗ gọi mới quên đặt trường này rơi vào tập **hẹp** hơn chứ không phải tập rộng hơn.

Ranh giới này vẫn **không có checker**. Hai bài test đứng sau nó, mỗi chiều một bài:
`TestAuthService_PhanVungCuaToi_PhanVungDaNgung_KhongHienRa` và
`TestMatQuanTri_VanDocDuocPhanVungDaNgung`. Riêng chỗ đọc thứ ba có hai bài của nó:
`TestAuthService_ChangePassword_ThuHoiCaPhienOPhanVungDangNgung` và
`TestAuthService_ChangePassword_QuanTriHeThong_ThuHoiCaPhienOPhanVungDangNgung`.

## Alternatives

**Giữ nguyên trục "nghiệp vụ / quản trị" và chỉ ghi chú đường thu hồi là một ngoại lệ** - loại,
vì nó biến điều kiện thành một mệnh đề có ngoại lệ mà không nói được ngoại lệ thứ hai trông như
thế nào. Cái giá đo được ngay: đường thu hồi phiên đã tồn tại **trước** ADR-0044 - nó ra đời từ
đính chính 2026-08-27 của ADR-0034 mục 3 - nên nó không phải một ca lạ mới sinh, mà là một ca đã
có sẵn bị trục cũ đọc nhầm. Một trục đọc nhầm một chỗ đọc đang chạy thì chỗ đọc thứ năm cũng sẽ
được đọc nhầm, và người viết nó không có gì để bám ngoài việc đi tìm dòng ghi chú ngoại lệ. Trục
mới không cần ngoại lệ nào cho cả bốn hàng của bảng trên; đó là toàn bộ lý do đổi nó.

**Tách một method repo riêng cho đường thu hồi, thay vì một tham số bật/tắt bộ lọc** - loại, và
lý do không phải thẩm mỹ. Cách này đã được cân trong lúc thi công: một method mới, chẳng hạn
`MoiPhanVungTheoUser`, kéo theo các hằng SQL mới đọc `user_companies` `JOIN companies` mà
**không** có mệnh đề `company_id = $` nào - tức chúng cần miễn trừ R-06. Phép miễn trừ khớp theo
**tên hằng SQL** tra vào map `hamMienCompanyID` trong `arch/checks_migration.go`, nên một tên hàm
mới nghĩa là một tên mới trong map ấy. Ràng buộc 1 của ADR-0034 mục 3 nói thẳng danh sách đó
**đóng**, và "thêm một hàm mới vào danh sách là một lần sửa ADR, không phải một dòng code".
Đường vòng duy nhất - cố tình đặt hằng mới mang chuỗi `PhanVungTheoUser` trong tên để đi lọt
phép khớp - là qua mặt một danh sách đóng bằng mẹo đặt tên, đúng thứ ràng buộc ấy sinh ra để
chặn. Tham số `KeCaPhanVungDaNgung` giữ nguyên **một** tên hàm được miễn, và giá của nó là một
trường bool phải đặt đúng ở hai chỗ gọi.

**Dựng một checker cho ranh giới này** - loại ở phạm vi ADR này, không loại vĩnh viễn. Checker
phải trả lời được "câu SQL này có mở một lối vào không", và dữ kiện ấy không nằm trong câu SQL:
ba câu của `PhanVungTheoUser` phục vụ **cả hai** phía tuỳ tham số runtime, nên mọi phép kiểm
theo hình dạng câu SQL đều cho cùng một câu trả lời cho hai hành vi ngược nhau. Một checker đúng
ở đây phải là danh sách trắng theo tên **chỗ gọi**, giống `hamMienCompanyID` - và hôm nay danh
sách ấy có bốn hàng, quá nhỏ để trả giá một bộ kiểm trong khi ADR-0040 và ADR-0041 còn đang nợ
một cái cùng hình dạng. Ngày hai danh sách ấy được dựng, dựng chung một lượt.

**Bỏ tham số, luôn quét đủ ở repo rồi lọc ở tầng service bằng Go** - loại, vì `PhanVungTheoUser`
nhận `page`/`page_size` theo R-12 và trả `total`. Lọc sau khi phân trang thì `total` đếm cả phân
vùng đã ngừng trong khi danh sách trả về thì không, và một trang có thể trả về rỗng giữa chừng
trong khi `meta` nói còn dữ liệu - hỏng đúng kiểu im lặng mà phân trang sinh ra. Muốn đúng thì
phải đọc hết mọi trang rồi mới lọc, tức bỏ luôn phân trang ở một endpoint mà R-12 bắt phải có.

**Đặt tên trường ở thể phủ định để mặc định là quét đủ** (`KhongLocTrangThai`) - loại, vì nó
chọn sai chiều an toàn. Với thể khẳng định, một chỗ gọi mới quên đặt trường sẽ **lọc**, và hậu
quả là một phân vùng đang ngừng không hiện ra ở nơi lẽ ra phải hiện - sai thấy được, bấm tay là
biết. Với thể phủ định, quên đặt trường thì một phân vùng đang ngừng lọt vào một danh sách để
bấm, và ca hỏng nặng nhất của cả đợt này - phiên không bị thu hồi - thuộc đúng nhóm im lặng đó.
Khi hai chiều mặc định đều sai được, chọn chiều mà cái sai kêu thành tiếng.

## Consequences

**Được:**

- Bốn chỗ đọc hiện có phân loại đúng bằng **một** câu, không ngoại lệ nào. Trục cũ đọc sai một
  trong bốn, và đó là chỗ hỏng nặng nhất.
- Chỗ đọc thứ năm có một phép kiểm cụ thể để chạy - "bỏ sót một phân vùng đang ngừng ở đây thì
  hỏng cái gì" - thay vì phải dán một nhãn ("cái này nghiệp vụ hay quản trị?") mà bản thân nhãn
  ấy không nói gì về hậu quả.
- Trục mới nêu ra được thứ trục cũ giấu: hai loại lỗi ở hai phía **không** cân nhau. Quên lọc
  thì người dùng thấy một lựa chọn chết và biết ngay; quên quét đủ thì một refresh token sống
  sót và không ai biết cho tới lúc phân vùng được bật lại.
- Lý do **không** tách method repo riêng cho đường thu hồi được ghi ra một lần, nên lần sau ai
  thấy tham số bool ấy chướng mắt sẽ đọc được vì sao nó ở đó thay vì "dọn" nó đi.

**Mất:**

- **Trục mới vẫn không có checker.** ADR-0044 nói ranh giới của nó chỉ có test; ADR này không
  đổi điều đó một ly. Chỗ đọc thứ năm vẫn phải **tự phân loại bằng tay**, và người phân loại sai
  sẽ không bị bộ kiểm nào chặn - chỉ có bốn bài test hiện có, và cả bốn đều gắn vào bốn chỗ đọc
  đã biết chứ không canh chỗ đọc mới.
- **Phép kiểm dựa vào một dự đoán hậu quả, không vào một dữ kiện đọc được từ code.** "Câu này mở
  lối vào hay quét đủ" là câu hỏi về ý định của chỗ gọi. Với `PhanVungTheoUser`, cùng một câu SQL
  cho cả hai câu trả lời tuỳ tham số, nên không có cách nào đọc ra đáp án từ file repository -
  phải đọc chỗ gọi. Một chỗ gọi thứ ba của cùng câu ấy sẽ phải trả lời lại từ đầu.
- **ADR-0044 phần "Nợ để lại" từ nay chỉ đọc đúng khi đọc kèm ADR này, và trong file ADR-0044
  không có gì trỏ tới đây.** Đây là lần thứ hai trong cùng một ngày ADR-0044 bị đính chính từ
  bên ngoài - ADR-0045 mục 1 đã đính chính mục 4 của nó. Ai đọc ADR-0044 một mình sẽ đọc ra hai
  mệnh đề đã bị đính chính chứ không phải một.
- Trục mới dài hơn trục cũ và không gói được vào một cặp từ. "Nghiệp vụ / quản trị" nhớ được sau
  một lần đọc; "mở lối vào / quét đủ" phải kèm câu hỏi kiểm mới dùng đúng được.

**Nợ để lại:**

- **Điều kiện**, không phải khuyến nghị: mọi chỗ gọi mới của một câu đọc `companies` phải trả
  lời câu hỏi "bỏ sót một phân vùng đang ngừng ở đây thì hỏng cái gì" **trước** khi chọn bộ lọc,
  và câu trả lời phải nằm lại trong code dưới dạng một bài test gắn vào chính chỗ gọi đó. Quyết
  định này chỉ đứng vững khi việc ấy được làm, và nó không có checker.
- Checker theo danh sách trắng tên chỗ gọi vẫn chưa có, và nay có **hai** danh sách cùng hình
  dạng đang nợ: các ngoại lệ R-06 mà ADR-0040, ADR-0041 và ADR-0044 ghi nợ, và bốn chỗ đọc
  `companies` của ADR này. Dựng riêng hai bộ là chép cùng một cơ chế hai lần.
- Chưa rà: các bảng khác đã có cột `is_active` - `users` là một - có chỗ đọc nào rơi vào nhóm
  "quét đủ" mà đang lọc không. Chính đường thu hồi phiên đọc `users` qua `ByIDToanHe`, và câu hỏi
  ấy chưa ai đặt cho nó.
- Ngày khuôn "ngừng sử dụng" áp cho danh mục thứ hai (vật tư, kho, khách hàng), phải kiểm xem
  trục này còn đúng không. Bốn hàng của bảng trên đều thuộc `companies`, và `companies` có một
  tính chất riêng mà một danh mục thường không có: nó là thứ người ta **đứng vào**, nên khái
  niệm "lối vào" có nghĩa với nó.

**Constrains:** —

# ADR-0038: Admin của phân vùng đặt ra vai trò, và chỉ tích được những quyền chính họ đang giữ

**Status:** Accepted (2026-08-27)

## Context

Đợt 2b mở đường ghi cho màn Vai trò
(`99-meta/my-specs/2026-08-27-vai-tro-dot-2b-spec.md`). Trước đợt này, backend chỉ có
`GET /api/v1/roles` trả đúng `{ma, nhan}`; màn `/quan-tri/phan-quyen` chạy trên hằng
`VAI_TRO_MAU` với năm dòng bịa và đeo chip "Xem trước". Không có đường tạo vai trò, không có
đường sửa tập quyền của một vai trò.

Người dùng chốt ngày 2026-08-27: mỗi phân vùng có một admin; trong phân vùng của mình, admin
tự đặt ra vai trò mới và **tự tích quyền** cho nhân viên. Về tập quyền admin nhìn thấy, câu
chốt là: **đúng những quyền chính họ đang có**, quyền ngoài tầm hiện mờ và khoá kèm câu nói vì
sao. Về `quan_tri_he_thong`, câu chốt là: *"quản trị hệ thống cũng phải tự thêm được vai trò"*.

**Ba câu chốt đó đụng vào hai thứ hệ đã ghi ra giấy và khoá bằng máy.**

**Thứ nhất, một khối ghi chú trong code frontend nói ngược lại.**
`frontend-erp/src/modules/user/pages/VaiTroFormPage.tsx` có một khối bình luận đặt tiêu đề
*"KHÔNG có ma trận quyền Xem / Thêm / Sửa / Xoá / Duyệt trên màn này"*, với lý do: *"Tick từng
ô quyền là việc của quản trị module, làm trong phân hệ của họ. Vẽ ma trận ở đây là nói sai ai
làm gì."* Đợt 2b vẽ đúng cái ma trận ấy.

**Thứ hai, tập quyền của `quan_tri_he_thong` bị khoá cứng ở mười sáu mã.**
[ADR-0031](ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md) mục Decision 1 chốt con số đó, và
mục Decision 5a biến nó thành một bài test chép tay:
`backend-erp/cmd/internal/vaitro/adr0031_test.go`, hàm `TestQuanTriHeThongDungMuoiSauQuyen`.
Bài đó cố ý không derive từ `Bang()`; thêm một mã mà quên sửa danh sách chép tay là đỏ, và
theo đúng ý định của ADR-0031, đỏ đó là lời nhắc đọc lại ADR trước khi cho một mã mới vào.

**Thứ ba, hệ đã có sẵn một cửa cho việc ghi tập quyền, và nó không nằm ở module.**
[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) mục 2 chốt: muốn sửa tập
quyền của một vai trò, actor phải có `<module>.role_assign` của **mọi** module xuất hiện trong
hiệu đối xứng giữa tập cũ và tập mới. Đọc ngược mệnh đề đó thì thấy ngay một dữ kiện:
`inventory.admin` và `machine.admin` **không** có `auth.role_assign`, mà mọi vai trò đều mang
sàn chung `auth.self_read` / `auth.change_password`. Quản trị module, theo luật đã có, không
ghi nổi một vai trò nào.

Ngoài ra, hai dữ kiện kỹ thuật đã biết trước khi quyết, cả hai đều là ràng buộc chứ không phải
chi tiết cài đặt: nhớ đệm quyền của `shared/authz/nguon_db.go` có nhịp hết hạn 30 giây và
không có API vô hiệu hoá; và `GET /roles` là **một** endpoint duy nhất, đã lọc theo thẩm quyền
theo [ADR-0032](ADR-0032-danh-muc-vai-tro-loc-theo-tham-quyen-cua-actor.md).

## Decision

**Quyền đặt ra vai trò thuộc về admin của phân vùng, gác bằng hai mã `auth.role_create` và
`auth.role_update`; tập quyền bày ra cho actor tích bị cắt đúng bằng tập quyền chính actor
đang giữ; và vai trò do hệ thống tạo khoá tập quyền, chỉ mở tên và mô tả.**

**1. Ai được đặt ra vai trò: admin của phân vùng, không phải quản trị module.**

Cửa là `auth.role_create` (tạo) và `auth.role_update` (sửa tên, mô tả, tập quyền, bật tắt).
Hai mã này vào bộ mặc định của `auth.admin` và của `quan_tri_he_thong`, không vào
`inventory.admin` hay `machine.admin`.

Đặt cửa ở `auth.*` **không phải một luật mới**, nó là đặt cửa đúng chỗ nó đã nằm sẵn. Theo
ADR-0024 mục 2, một `<module>.admin` không có `auth.role_assign` nên không ghi nổi một tập
quyền nào chạm module `auth` - mà mọi vai trò đều mang sàn chung `auth.self_read` và
`auth.change_password`, tức mọi tập quyền đều chạm `auth`. Nếu đặt cửa ở `<module>.role_*` thì
kết quả là một nút bấm được rồi trả `422` ở luật cũ. Cửa ở `auth.*` nói ra bằng lời đúng thứ
mà phép tính thẩm quyền đã quyết từ ADR-0024.

Không có `auth.role_delete`: người dùng chốt "tắt, không xoá", nên không có đường xoá để gác.

**2. Tập quyền bày ra bị cắt theo quyền của chính actor, và đó là hệ quả đọc được của
ADR-0024 chứ không phải một luật thứ hai.**

`GET /api/v1/permissions` trả mỗi mã kèm cờ `cap_duoc`: actor có đang giữ mã đó không. Màn vẽ
dòng `cap_duoc: false` mờ và khoá, kèm lý do đọc được bằng bàn phím.

Vì sao cắt: actor không có `<module>.role_assign` thì theo ADR-0024 mục 2 không ghi nổi một mã
của module đó. Bày ra một ô tick bấm được rồi trả `403` là một vòng mạng để nhận một câu trả
lời đã biết trước, và với người không làm kỹ thuật thì đó là một lỗi không giải thích được.

**Nói thẳng để không ai hiểu nhầm: ẩn nút là UX, không phải bảo mật.** Backend vẫn từ chối một
mã `cap_duoc: false` gửi lên, bằng đúng phép kiểm hiệu đối xứng của ADR-0024 mục 2, chạy trên
mọi lần gọi kể cả `curl`. Đây là đúng thế đứng mà ADR-0032 mục Decision 4 đã chốt: *lọc không
bao giờ thay một phép chặn*.

**3. Vai trò hệ thống khoá tập quyền, mở tên và mô tả.**

Bảy vai trò mặc định mang cờ `is_system = true`. Với chúng, `PATCH /roles/:id` chỉ cho `name`
và `description` đi qua; gửi `permissions` hoặc `dang_dung` thì `422`.

Vì sao khoá: admin sửa tập quyền của chính vai trò đang cho họ quyền quản trị là đường ngắn
nhất để tự khoá mình ra ngoài phân vùng, và **không ai trong phân vùng sửa lại được** - cứu
được chỉ còn một đường đi qua máy chủ. Đây chính là câu hỏi mà ADR-0031 mục "Nợ để lại" đã đẩy
sang đợt 2b, và [ADR-0029](ADR-0029-nhan-ban-quan-tri-trong-cung-module.md) mục "Nợ để lại"
nêu ra trước đó.

Vì sao tên và mô tả vẫn mở: chúng không cấp quyền cho ai. Một phân vùng gọi `inventory.thu_kho`
là "Thủ kho ca đêm" không đổi một dòng nào trong `role_permissions`.

Muốn một tập quyền khác thì tạo một vai trò riêng. Đường đó luôn mở, nên phép khoá này không
chặn nhu cầu nào, chỉ chặn cách rẻ tiền nhất để tự bắn vào chân.

**4. Đính chính ADR-0031 mục Decision 1: tập quyền của `quan_tri_he_thong` là mười tám mã,
không phải mười sáu.**

ADR là bất biến, nên câu chữ của ADR-0031 **không sửa tại chỗ**. Phép đính chính nằm ở đây.

Hai mã được thêm: `auth.role_create` và `auth.role_update`. Lý do bằng lời của người dùng:
*"quản trị hệ thống cũng phải tự thêm được vai trò"*.

**Vì sao hai mã này qua được tiêu chí của ADR-0031 mục Decision 2.** Tiêu chí ở đó là: chỉ
thêm mã thật sự phá một vòng kín, không thêm mã chỉ nới bề mặt, và tuyệt đối không mở một cửa
sau vào dữ liệu vận hành của khách hàng. Hai mã này chỉ ghi vào đúng hai bảng, `roles` và
`role_permissions`, và **chỉ của phân vùng actor đang đứng** - mọi câu đọc và ghi vai trò lọc
theo `company_id` của actor (R-06). Chúng không mở thêm một đường đọc nghiệp vụ nào: không
`items`, không `stock_movements`, không `equipments`. Đối chiếu với hàng rào của ADR-0029 và
ADR-0031 mục Decision 3 thì cũng không có gì đổi chiều: hàng rào ấy nói về `auth.company_*`,
và hai mã mới không mang tiền tố đó.

Bất đối xứng của ADR-0031 mục Decision 3 vì vậy vẫn nguyên: `quan_tri_he_thong` được thêm hai
mã này, `auth.admin` cũng có chúng, và không vai trò nào ngoài `quan_tri_he_thong` chạm được
`auth.company_*`.

**Chỗ phải sửa cùng đợt, ghi đích danh:**
`backend-erp/cmd/internal/vaitro/adr0031_test.go` - danh sách chép tay
`tapQuyenQuanTriHeThong` thêm hai chuỗi, và câu "muoi sau ma" trong bình luận đổi thành "muoi
tam ma". **Tên hàm `TestQuanTriHeThongDungMuoiSauQuyen` giữ nguyên**: ADR-0031 mục Decision 5a
gọi bài test đó đích danh, đổi tên là cắt sợi dây nối giữa một ADR và hiện thân bằng máy của
nó. Tên hàm từ đó là một cái tên riêng, không còn là một phép đếm.

## Alternatives

**Để việc tích quyền cho quản trị module, đúng như khối ghi chú ở `VaiTroFormPage.tsx` đã
viết** - loại vì nó không chạy được, chứ không phải vì nó xấu. Theo ADR-0024 mục 2, một
`inventory.admin` không có `auth.role_assign`; mọi tập quyền đều chứa sàn chung
`auth.self_read` và `auth.change_password`; nên mọi lần ghi của họ đều rơi vào hiệu đối xứng
chạm module `auth` và bị từ chối. Giữ đường này là dựng một màn không ai dùng được, hoặc phải
nới ADR-0024 - và nới nó thì `inventory.admin` ghi được vai trò chạm `auth`, tức mở đúng cửa
mà ADR-0029 dựng hàng rào để đóng.

**Cấp một mã `auth.role_create` cho `<module>.admin` kèm ngoại lệ "được phép chạm sàn chung
`auth.self_read` / `auth.change_password`"** - loại. Nó thêm một ngoại lệ vào phép tính thẩm
quyền, mà phép tính đó là thứ ADR-0024 và ADR-0032 đã cố giữ **một** bản cài đặt duy nhất. Cái
giá thật không phải hai dòng code: nó là mọi lần sau này có người đọc `hieuDoiXungVaiTro` và
phải nhớ rằng có hai mã được miễn. Ngày nào đó sàn chung dài thêm một mã, danh sách miễn trừ
lệch và không ai biết.

**Bày đủ 50 mã quyền cho ai cũng tick được, để backend từ chối khi lưu** - loại. Nó đúng về
bảo mật (backend vẫn chặn) nhưng sai về việc dùng: người không làm kỹ thuật tick mười ô, bấm
Lưu, nhận một câu `422` nói về một mã mà họ không hiểu, rồi phải đoán ô nào là ô sai. Chi phí
để tránh chuyện đó đúng bằng một cờ boolean trong response của `GET /permissions`.

**Khoá cả tên và mô tả của vai trò hệ thống** - loại. Nó đơn giản hơn để cài (một câu `if` cho
cả bản ghi) nhưng chặn một nhu cầu có thật và vô hại: mỗi phân vùng gọi cùng một vai trò bằng
một cái tên khác. Đổi tên không cấp quyền cho ai, nên không có gì để bảo vệ ở đó.

**Không làm gì, giữ màn ở trạng thái dữ liệu mẫu** - loại. Màn đã đeo chip "Xem trước" từ
2026-08-24; giữ thêm một đợt nữa nghĩa là mọi phân vùng vẫn phải nhờ người viết code chèn tay
một hàng `role_permissions` mỗi khi cần một vai trò mới.

## Consequences

**Được:**

- Một phân vùng tự chủ được việc phân quyền của mình, không phải nhờ tới nhà cung cấp. Đúng
  chiều mà ADR-0031 mục Decision 2 đã chọn khi từ chối cho `quan_tri_he_thong` cầm
  `user_update` và `user_delete`.
- Câu chốt "chỉ thấy quyền chính mình có" thành một cờ đọc được từ API, thay vì một quy ước
  sống trong đầu người viết giao diện.
- Khối ghi chú ở `VaiTroFormPage.tsx` được gỡ cùng một lượt với thứ nó mô tả, nên code không
  còn nói ngược lại chính nó.

**Mất:**

- **Nhớ đệm quyền 30 giây làm mọi thay đổi tập quyền có độ trễ - trừ chính đường ghi vai
  trò.** `shared/authz/nguon_db.go` giữ nhịp hết hạn (`nhipHetHan`) 30 giây. Đợt này **nói
  câu đó trên màn** - một dòng cố định dưới khối quyền.

  Nhưng đường ghi vai trò thì **không** được phép chậm như vậy, và đây là chỗ bản đầu của
  ADR này chốt sai. Bản chụp được nạp ở lời gọi `Can` đầu tiên của request - tức TRƯỚC khi
  hàng `roles` mới tồn tại - nên một vai trò vừa tạo sẽ **biến mất** khỏi `GET /roles` và
  `PUT /users/:id/roles` từ chối nó bằng câu "vai trò không tồn tại", cả hai kéo dài tới 30
  giây. Người dùng không đọc triệu chứng đó ra là "chậm"; họ đọc nó ra là mất dữ liệu. Bài
  e2e `TestE2ETaoVaiTroRoiGanChoNguoiThat` lôi ra điều này khi nó phải dựng một router thứ
  hai mới khép được vòng.

  Nên `Checker` nay có `XoaBanChup(companyID)`, và cả `TaoVaiTro` lẫn `SuaVaiTro` gọi nó
  **ngay sau `tx.Commit()`**. Một khoá bị vứt, không phải cả map: một lần ghi ở phân vùng
  này không nói gì về bảng phân quyền của phân vùng khác. Method nằm trong chính `Checker`
  chứ không là một interface tuỳ chọn ở cạnh - một phép ép kiểu `if x, ok := ...` sẽ im lặng
  trở thành không-làm-gì vào ngày ai đó tiêm một `Checker` khác, và chỗ hỏng lại đúng là chỗ
  vừa sửa.

  Câu "chỉ nhìn thấy sau tối đa 30 giây" vì vậy chỉ còn đúng cho các đường ghi KHÁC -
  `PUT /users/:id/roles` và `PUT /users/:id/scopes` chưa gọi `XoaBanChup`. Mở rộng sang hai
  đường đó là việc của đợt sau, và nó cần bàn riêng vì chúng ghi vào bảng gán chứ không vào
  bảng vai trò.
- **Thông điệp từ chối lúc gán một vai trò đã tắt chưa thật đúng.** `is_active = false` cắt vai
  trò khỏi nguồn đọc của `authz` (thêm một mệnh đề vào `selectQuyenTheoVaiTroSQL`), và **cùng
  một dòng đó** làm vai trò tắt không gán mới được. Nhưng câu từ chối khi đó là
  `vai tro khong ton tai` - nói sai nguyên nhân. Sửa cho đúng đòi thêm một lần đọc `is_active`
  cho mỗi vai trò trên đường gán, và đợt này **không** làm. Ghi ra đây để lần sau ai gặp câu
  đó biết nó là một chỗ đã biết, không phải một bug mới.
- **`GET /roles` trả cả vai trò đã tắt**, vì nó là **một** endpoint phục vụ cả màn quản trị lẫn
  màn gán - đúng theo ADR-0032 mục Decision 1, danh mục đi theo phép chặn chứ không có bản thứ
  hai. Màn gán vì vậy phải tự lọc theo trường `dang_dung`. Đó là lọc theo **dữ liệu backend
  trả về**, không phải suy diễn quyền ở frontend, nên nó không vướng luật ESLint
  `erp/c-ts-06-no-role-guess` và cũng không vướng R-19.

**Nợ để lại:**

- Quyết định này chỉ đứng vững khi **mọi đường ghi tập quyền đi qua phép kiểm hiệu đối xứng của
  ADR-0024 mục 2**, sau khi đã loại trừ tập tự tác động theo
  [ADR-0028](ADR-0028-quyen-tren-chinh-minh-khong-keo-theo-cua-module.md) mục 5. Đây là
  **điều kiện**, không phải khuyến nghị: bỏ nó thì cờ `cap_duoc` trở thành phép bảo vệ duy
  nhất, và nó nằm ở frontend.
- Cờ `is_system` phải được đặt ở **cả** đường tạo phân vùng mới lẫn backfill, không chỉ
  backfill. Một phân vùng mở sau đợt này mà `insertVaiTroMacDinhSQL` không đụng `is_system` thì
  bảy vai trò mặc định của nó ra đời với `is_system = false`, và mục 3 của ADR này rỗng ruột ở
  đúng phân vùng đó.
- ADR-0027 nói hệ thống không bao giờ ghi đè `role_permissions` của một vai trò đã tồn tại, nên
  hai mã mới ở mục 4 **không** tự chảy vào các phân vùng đang sống. Không có migration backfill
  thì admin của mọi phân vùng hiện có không mở được màn vừa làm ra.
- Chưa quyết: một `auth.admin` vẫn tạo được một vai trò **không phải** vai trò hệ thống rồi tự
  gán cho mình, nên mục 3 chỉ chặn đường tự khoá mình ra ngoài, không chặn đường tự nới quyền
  mình lên. Đường nới đó đã bị ADR-0024 mục 2 chặn ở tầng khác (không cấp được mã mình không
  giữ), nhưng hai phép chặn ấy chưa từng được đọc cùng nhau trong một bài test.

**Constrains:** —

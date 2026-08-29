# ADR-0044: Ngừng sử dụng một phân vùng là một cột trạng thái riêng, đảo lại được, tách hẳn khỏi `deleted_at`

**Status:** Accepted (2026-08-29)

## Context

[ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) mục 7 chốt "vô hiệu hoá là `deleted_at = now()`",
và mục Mất của chính nó đã nói ra cái giá ngay lúc quyết:

> Vô hiệu hoá dùng chính `deleted_at`, nên không có cách nào tách một phân vùng tạm dừng khỏi
> một phân vùng đã bỏ. Giai đoạn một **không có** đường bật lại một phân vùng qua API; muốn bật
> lại thì phải can thiệp trực tiếp vào database. Ngày cần một trạng thái tạm dừng thật, phải
> có cột trạng thái riêng bằng một ADR mới.

Ngày đó tới vì [ADR-0039](ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md) đổi một tiền đề: từ
2026-08-28 mọi phân vùng ra đời qua `POST /companies` đều mang sẵn một người - chính người
quản trị của nó. Cửa `SoNguoiDangHoatDong > 0` của `DeleteCompany` vì thế chặn **mọi** phân
vùng tạo qua giao diện, và `quan_tri_he_thong` cố ý không cầm `auth.user_delete`
([ADR-0031](ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md) mục 2). Tạo nhầm một phân vùng
thì không còn đường dọn nào.

Ở thời điểm quyết, ba dữ kiện định hình lựa chọn:

- Chữ trên màn hình đã là "Vô hiệu hoá phân vùng" (`CompanyFormPage.tsx`, và nhãn của mã
  `auth.company_delete` ở `nhan_quyen.go`) cho một thao tác **không đảo lại được**. Cái tên đã
  nói sai từ trước khi có ADR này.
- Tra tài liệu MISA AMIS ngày 2026-08-29: MISA tách bạch **Xoá** (chỉ khi chưa phát sinh dữ
  liệu) khỏi **Ngừng sử dụng** (không đụng dữ liệu đã phát sinh, bật lại được), và áp cùng một
  khuôn cờ hai giá trị cho mọi danh mục. Dữ kiện này được ghi lại ở
  [spec 2026-08-29](../99-meta/my-specs/2026-08-29-ngung-su-dung-phan-vung-design.md) mục 2.
- Hệ chưa có phân vùng nhiều cấp ([ADR-0033](ADR-0033-phan-vung-thanh-cay-doc-len-mot-chieu.md)
  chưa thi công), nên chưa có quan hệ cha-con nào để một trạng thái phải lan xuống.

Điều **chưa biết** lúc quyết: hệ này sẽ áp khuôn "ngừng sử dụng" cho bao nhiêu danh mục khác
(vật tư, kho, khách hàng), và khuôn đó có giữ nguyên hình dạng một cột boolean hay không.

## Decision

**Ngừng sử dụng một phân vùng là `companies.is_active = false` - một trạng thái riêng, đảo lại
được qua API, tách hẳn khỏi `deleted_at`.**

**1. Ba trạng thái, không hai.**

| `is_active` | `deleted_at` | Nghĩa | Đảo lại được |
|---|---|---|---|
| `true` | `NULL` | Đang dùng | - |
| `false` | `NULL` | Ngừng sử dụng | **có** |
| bất kỳ | có giá trị | Đã xoá | không |

Mục 7 của ADR-0019 nói `deleted_at` mang **cả hai** nghĩa. Câu đó nay chỉ còn đúng cho nghĩa
thứ hai. ADR-0019 là bất biến nên phép đính chính nằm ở đây, không ở câu chữ của nó - theo
đúng tiền lệ [ADR-0038](ADR-0038-admin-phan-vung-dat-ra-vai-tro.md) đã đặt khi đính chính tập
quyền mười sáu thành mười tám.

**2. Ngừng sử dụng không đụng một hàng gán nào.** Không gỡ người, không hạ cờ `is_admin`. Một
phân vùng ngừng sử dụng rồi bật lại phải trở về **nguyên trạng**; gỡ người là mất dữ liệu
không dựng lại được, và lúc đó "ngừng sử dụng" chỉ là "xoá" đội tên khác.

**3. Phân vùng ngừng sử dụng vẫn chiếm mã.** `uq_companies_code` giữ nguyên mệnh đề
`WHERE deleted_at IS NULL`. Hai phân vùng cùng mã - một đang chạy, một đang ngừng - làm mọi
câu tra lịch sử theo mã không đọc được, và đó là thứ không sửa được sau khi dữ liệu đã sinh ra.

**4. Cửa chặn: không ngừng sử dụng phân vùng mà chính actor đang làm việc.** 409 chứ không 403
- nó nói về trạng thái chứ không về quyền (C-API-05). Cửa này bắt buộc phải có ở đường ngừng
sử dụng dù `DeleteCompany` **cố ý không** có nó: `DeleteCompany` dựa vào cửa "còn người dùng"
bắt trước, còn đường ngừng sử dụng không có cửa đó, nên tự đá mình ra ngoài là chuyện xảy ra
thật.

**5. Xoá được nới đúng một nấc: cho xoá khi phân vùng không còn ai ngoài chính người quản trị
của nó.** Cụ thể: số người đang hoạt động bằng 0, hoặc bằng 1 và người đó mang cờ `is_admin`.
Đây là hiện thân của "chưa phát sinh dữ liệu" - tiêu chí MISA dùng cho cùng việc.

Xoá thì **soft delete mọi hàng `user_companies` còn sống của phân vùng đó** trong cùng
transaction. Mọi hàng chứ không riêng hàng của người quản trị: phép đếm ở trên lọc
`users.is_active`, nên một tài khoản bị khoá không được đếm nhưng hàng gán của nó vẫn còn.

Không đụng hàng `users`: theo [ADR-0034](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md) tài
khoản ấy có thể đang làm ở phân vùng khác.

**6. Cửa "ít nhất một người quản trị" của ADR-0039 mục 3 KHÔNG áp ở đường xoá.**
`GoKhoiPhanVung` và `ThayVaiTro` có cửa ấy vì chúng bỏ lại một phân vùng **đang sống** không
người chịu trách nhiệm. Ở mục 5 phân vùng biến mất, nên vế "ít nhất một" không còn đối tượng.
Ghi ra tường minh vì đọc lướt thì chỗ này trông y hệt lỗ hổng `DeleteUser` bị bắt ngày
2026-08-28.

**7. Câu ghi ở mục 5 là ngoại lệ thứ hai của
[ADR-0041](ADR-0041-duong-ghi-neo-vao-companies-chi-cho-co-quan-tri.md).** ADR-0041 mục 1 cấp
phép theo **từng câu** và chỉ kể tên `UserCompanyRepository.DatNguoiQuanTri`. ADR này kể tên
câu thứ hai: câu soft delete hàng gán trong `CompanyService.DeleteCompany`, neo vào
`companies.id` lấy từ path param `:id`. Không câu thứ ba nào được cấp phép ở đây.

`UPDATE companies SET is_active` thì **không** là ngoại lệ: `companies` thuộc `tenant_root`,
vốn được miễn R-06, và `UpdateCompany` với `SoftDelete` đã đi đúng hình dạng đó từ ADR-0019
mục 6.

**8. Không thêm mã quyền mới.** Cả hai chiều đi qua `auth.company_delete`, nhãn của nó đổi
thành "Ngừng sử dụng / xoá phân vùng". Không áp cho: cascade xuống phân vùng con (chưa có
con), và khuôn ngừng sử dụng của các danh mục khác (vật tư, kho, khách hàng) - ADR này chỉ nói
về `companies`.

## Alternatives

**Không làm gì, giữ nguyên `deleted_at` làm cả hai nghĩa** — loại, vì tiền đề mà ADR-0019 mục
7 dựa vào đã đổi. Lúc ADR-0019 quyết, một phân vùng vừa tạo là rỗng người nên `DeleteCompany`
xoá được nó; từ ADR-0039 thì không. Giữ nguyên nghĩa là mỗi lần tạo nhầm một phân vùng để lại
một hàng vĩnh viễn không ai dọn được, và cách dọn duy nhất là một câu `UPDATE` chạy tay trên
database production.

**Cấp `auth.user_delete` cho `quan_tri_he_thong`** — loại, vì nó phá lập luận ADR-0031 mục 2:
"sửa và xoá một người trong một phân vùng là việc của quản trị phân vùng ấy - nếu nhà cung cấp
cũng làm được, thì mọi lần dọn dẹp sau này sẽ mặc định chảy về nhà cung cấp thay vì về khách
hàng". Và nó mở một quyền trên **mọi** người dùng của **mọi** phân vùng để giải một bài toán
chỉ liên quan tới một phân vùng rỗng.

**Chỉ nới `DeleteCompany`, không làm trạng thái ngừng sử dụng** — loại, vì nó giải đúng ca
"tạo nhầm rồi xoá ngay" và không giải ca thật hơn: một phân vùng đã chạy vài tháng, có dữ liệu,
cần dừng nhận nghiệp vụ mới mà vẫn tra cứu được. Với phân vùng đó thì `DeleteCompany` vẫn từ
chối, và không có nút nào khác.

**Chỉ làm trạng thái ngừng sử dụng, không nới `DeleteCompany`** — loại, vì mục 3 giữ mã bị
chiếm. Tạo nhầm mã `KHO-HN` rồi ngừng sử dụng thì không bao giờ dùng lại được đúng mã đó, và
danh sách dài thêm một dòng mỗi lần gõ nhầm.

**Thả mã ra khi ngừng sử dụng** (đổi `uq_companies_code` thành lọc cả `is_active`) — loại, vì
nó cho phép hai phân vùng cùng mã cùng tồn tại. Mã phân vùng là thứ người ta đọc trong báo cáo
và gõ khi đăng nhập; hai hàng cùng mã biến mọi câu tra theo mã thành nhập nhằng, và đó là loại
hỏng không sửa được sau khi dữ liệu đã sinh ra.

**Bắt chước MISA: bấm Xoá mà không xoá được thì tự chuyển thành ngừng sử dụng** — loại. Đây là
thứ MISA thật sự làm ([help.amis.vn](https://help.amis.vn/kb/co_cau_to_chuc)), nhưng nó im lặng
đổi việc người ta vừa bấm. Đợt 2026-08-28 đã trả giá hai lần cho đúng loại im lặng đó - tám
thông điệp không dấu và một câu viết sẵn nói sai lý do - và cả hai chỉ lộ ra khi bấm tay. Hai
nút riêng, chữ nói thật.

**Thêm mã quyền `auth.company_deactivate`** — loại, vì hôm nay chỉ một vai trò
(`quan_tri_he_thong`) cầm mọi mã `auth.company_*`, nên mã mới không cấp thêm cho ai và không
chặn thêm ai. Giá của nó đo được: sửa danh sách chép tay `tapQuyenQuanTriHeThong`, và đổi tên
`TestQuanTriHeThongCamDuNamQuyenCongTy` vì nó đếm đúng năm. Ngày có một vai trò được ngừng mà
không được xoá, đó là một ADR tách mã.

**Cột trạng thái `TEXT` + `CHECK` thay vì `BOOLEAN`** — loại ở phạm vi ADR này. C-DB cho phép
cả hai và `TEXT` mở đường cho giá trị thứ ba sau này, nhưng hôm nay không có giá trị thứ ba nào
được kể tên, và `users.is_active` đã đặt sẵn khuôn boolean trong chính module này. Ngày cần
trạng thái thứ ba thật, migration đổi kiểu là một câu `ALTER` trên một bảng đếm bằng chục hàng.

## Consequences

**Được:**

- Một phân vùng dừng được mà không mất, và bật lại được qua API chứ không qua một câu `UPDATE`
  chạy tay trên production.
- Chữ "vô hiệu hoá" biến mất khỏi hệ. Hai thao tác, hai cái tên nói đúng việc: "Ngừng sử dụng"
  đảo lại được, "Xoá phân vùng" thì không.
- Tạo nhầm một phân vùng có đường dọn, và tiêu chí dọn là tiêu chí MISA dùng cho cùng việc chứ
  không phải một hàng rào nới ra cho tiện.
- Khuôn cho các danh mục sau (vật tư, kho, khách hàng) - MISA áp cùng một cờ hai giá trị cho
  mọi danh mục, và `companies` là chỗ dựng khuôn đó.

**Mất:**

- Một trạng thái nữa phải nhớ ở **mọi** câu đọc `companies` sau này. `deleted_at IS NULL` không
  còn đủ để nói "phân vùng này dùng được"; hai vế đó nay khác nhau, và quên vế thứ hai là một
  lỗi im lặng.
- Cửa `is_active` phải đặt tại **chỗ gọi** chứ không trong SQL của `CompanyRepository.ByID`, vì
  hàm đó dùng chung giữa đường nghiệp vụ và mặt quản trị. Nhét vào SQL cho gọn thì mặt quản trị
  không đọc được phân vùng đã ngừng, tức nút bật lại thành vô dụng - và không test nào hiện có
  bắt được.
- Phân vùng ngừng sử dụng chiếm mã vĩnh viễn. Gõ nhầm mã rồi phát hiện sau khi đã có dữ liệu
  thì mã đó mất hẳn.
- Ngoại lệ R-06 đi từ ba lên bốn. Checker mà ADR-0040 và ADR-0041 còn nợ nay phải liệt kê thêm
  một tên hàm.

**Nợ để lại:**

- **Điều kiện**, không phải khuyến nghị: mọi câu đọc `companies` phục vụ một đường **nghiệp vụ**
  phải lọc `is_active`; mọi câu đọc phục vụ **mặt quản trị** phải không lọc. Quyết định này chỉ
  đứng vững khi ranh giới đó được giữ, và nó không có checker - chỉ có hai bài test đi hai
  chiều.
- Checker cho bốn ngoại lệ R-06 vẫn chưa có. Nó phải là danh sách trắng theo tên hàm, giống map
  `hamMienCompanyID` của ADR-0034, chứ không phải một mệnh đề theo hình dạng.
- Khuôn "ngừng sử dụng" cho các danh mục khác chưa được chốt. ADR này chỉ nói về `companies`;
  danh mục đầu tiên bám theo khuôn này sẽ phải trả lời câu ADR này không hỏi: cờ boolean có đủ
  cho một danh mục nghìn dòng có phân trang và bộ lọc không.
- Ngày ADR-0033 làm phân vùng nhiều cấp, phải quyết trạng thái này có lan xuống con hay không.
  MISA cascade với danh mục tài khoản và không nói gì về cơ cấu tổ chức.

**Constrains:** R-06

# ADR-0036: Quản trị hệ thống đi được mọi phân vùng mà không cần là thành viên

**Status:** Accepted (2026-08-27)

## Context

[ADR-0034](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md) tách danh tính khỏi phân vùng và
chốt: *"một `users` là một con người; `user_companies` nói người đó làm ở đâu"*. Đăng nhập vì
vậy thành hai bước — `POST /auth/login` trả `identity_token`, rồi `POST /auth/select-company`
đổi lấy access token của đúng một phân vùng.

Câu đó đúng cho nhân viên. Nó **không nói gì** về một người không làm ở đâu cả.

**Đo thật trên máy dev `v0.1.0-rc.58`, ngày 2026-08-27:**

```
companies (deleted_at IS NULL):  3604117302-2026, CN-DN, CN-HCM, DEFAULT, NM-TB   → 5
user_companies của admin@gmail.com:                                    DEFAULT   → 1
```

`admin@gmail.com` là quản trị hệ thống duy nhất (`users.is_system_admin = true`). Ô chọn phân
vùng của người đó hiện **một** dòng, và bốn chi nhánh còn lại không có đường nào vào.

**Hệ quả nghiệp vụ, và nó nặng hơn vẻ ngoài của một ô chọn thiếu dòng.** Màn "Phân vùng" cho
quản trị hệ thống **tạo** được một chi nhánh mới — nhưng tạo xong thì chính người tạo không
bước vào được: không xem được ai đang ở đó, không bổ nhiệm được quản trị phân hệ cho nó, không
sửa được gì bên trong. Một hệ dựng được chi nhánh mà không quản trị được chi nhánh vừa dựng.

**Hai chỗ trong hệ đã nói rằng vai trò này đứng ngoài phân vùng**, và cả hai có trước ADR này:

- Mockup cấp 1 (`mockup-erp/cap1-quan-tri-he-thong.html`) in ngay cạnh tên ứng dụng dòng chữ
  *"Đứng ngoài mọi phân vùng"*.
- `quan_tri_he_thong` là **vai trò dẫn xuất**: nó không nằm trong `user_company_roles` mà được
  `capTokenMoi` suy ra từ cờ `users.is_system_admin` mỗi lần ký ([ADR-0019](ADR-0019-phan-vung-la-cong-ty.md)
  mục 5). Một vai trò không treo vào phân vùng nào, theo định nghĩa, không hỏi được
  `user_companies` xem nó thuộc phân vùng nào.

Nên lỗ hổng không phải một dòng code quên, mà là một câu chưa ai viết ra.

## Decision

**`is_system_admin` là đường vào MỌI phân vùng. Hai câu ở bước chọn phân vùng đọc theo cờ đó
thay vì đọc `user_companies`; mọi thứ SAU khi đã chọn không đổi một dòng nào.**

**1. `GET /auth/companies`** trả toàn bộ `companies` còn sống khi danh tính mang
`is_system_admin = true`; giữ nguyên đường cũ (đọc `user_companies`) cho mọi người khác. Cùng
hình dạng response, cùng phân trang — chỉ khác tập nguồn.

**2. `POST /auth/select-company`** nhận bất kỳ `company_code` nào còn sống khi danh tính mang cờ
đó. Ba phép kiểm khác **giữ nguyên và vẫn chạy**: phân vùng phải tồn tại, phải chưa bị vô hiệu
hoá, và tài khoản phải chưa bị khoá. Cờ này mở thêm một đường vào, nó không bỏ một cửa nào.

**3. Sau khi đã chọn thì KHÔNG có gì đặc biệt.** Token vẫn mang đúng một `company_id`, mọi câu
truy vấn nghiệp vụ vẫn kèm nó, R-06 không có ngoại lệ mới. Đây là chỗ ADR này cố ý hẹp: nó đổi
cách **đi tới** một phân vùng, đúng như ADR-0034 mục Consequences đã khoanh, chứ không đổi
chuyện ở trong đó. Một quản trị hệ thống đứng trong phân vùng `CN-DN` nhìn thấy đúng dữ liệu của
`CN-DN`, không hơn.

**4. Không tự thêm hàng vào `user_companies`.** Phương án "tạo chi nhánh thì tự thêm người tạo
làm thành viên" bị loại ở mục Alternatives, nhưng luật đứng riêng ở đây vì nó là thứ dễ bị lén
đưa vào sau: quản trị hệ thống **không** được có hàng `user_companies` chỉ để đi lại. Hàng đó
nói "người này làm ở đây", và nó sai với một người không làm ở đâu cả.

**5. Cờ đọc từ database mỗi lần chọn, không đọc từ claim của `identity_token`.** Một cờ đã ký
vào token sống tiếp 300 giây sau khi bị thu hồi. Đây là đúng cửa cần đóng nhanh nhất trong hệ,
nên nó phải hỏi lại nguồn.

## Alternatives

**Tạo chi nhánh thì tự thêm người tạo vào `user_companies`** — loại vì hai lý do, và lý do thứ
hai mới là lý do thật. Một: nó không chữa được bốn chi nhánh đã tồn tại, nên vẫn phải có một
đường vá riêng cho chúng. Hai: nó biến một câu **sai về nghiệp vụ** thành dữ liệu — bảng
`user_companies` trả lời "người này làm ở đâu", và một hàng ở đó cho người đứng ngoài mọi phân
vùng là một câu trả lời sai được ghi vào database. Mọi câu đếm "chi nhánh này có bao nhiêu
người" sau đó đều lệch, im lặng.

**Cho quản trị hệ thống một token không mang `company_id`** — loại, và đây là phương án nguy
hiểm nhất trong ba. Nó phá đúng thứ ADR-0034 mục Consequences ghi là "Không đổi": mọi câu truy
vấn nghiệp vụ đều kèm `company_id` lấy từ token, nên một token thiếu nó biến `WHERE company_id
= $1` thành một câu không chạy được, hoặc tệ hơn, thành một câu ai đó sẽ "tạm" bỏ mệnh đề đó đi.
R-06 sẽ mất nghĩa từ đúng chỗ ấy.

**Thêm một permission `auth.company_traverse` thay cho cờ** — loại ở đợt này. Quyền là thứ gán
được cho nhiều vai trò, mà việc đi lại giữa mọi phân vùng thì hôm nay chỉ đúng một vai trò dẫn
xuất được làm. Ngày có ca thật thứ hai — một kiểm toán viên đi mọi chi nhánh mà không sửa gì
chẳng hạn — thì đó là lúc đổi sang quyền, và ADR này là chỗ ghi lại rằng ca ấy đã được nghĩ tới.

## Consequences

**Được:** quản trị hệ thống quản trị được chi nhánh mình vừa tạo. Không có bản vá riêng nào cho
bốn chi nhánh đã tồn tại — chúng vào được ngay khi bản này lên.

**Mất:** một cờ boolean nay mở được cửa vào mọi phân vùng, nên nó thành cột nhạy cảm nhất trong
bảng `users`. Đường ghi cờ đó phải được canh như canh một quyền, và mục 5 (đọc lại từ database
mỗi lần chọn) là chốt chặn duy nhất giữ cho một lần thu hồi có hiệu lực trong vòng vài giây thay
vì vài phút.

**Nợ để lại:** giao diện chưa nói ra sự khác biệt. Ô chọn phân vùng của một quản trị hệ thống
liệt kê năm chi nhánh y hệt cách nó liệt kê hai chi nhánh của một nhân viên làm hai nơi — hai
nghĩa khác nhau, một hình dạng. Ngày danh sách đó dài tới vài chục dòng, nó cần ô tìm và cần nói
rõ "bạn đang thấy mọi phân vùng vì bạn là quản trị hệ thống".

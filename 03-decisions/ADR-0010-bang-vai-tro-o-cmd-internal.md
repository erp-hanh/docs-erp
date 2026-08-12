# ADR-0010: Bảng vai trò sống ở `cmd/internal/vaitro`, dùng chung cho mọi composition root

**Status:** Accepted (2026-08-12)

## Context

`C-GO-08` chốt rằng bảng vai trò → permission sống ở composition root, và nêu đích danh
`cmd/api`. Lý do vẫn nguyên giá trị: đó là nơi duy nhất được biết cả hai phía — danh sách
vai trò của hệ thống, và hằng permission của từng module. Đặt nó ở `shared/authz` sẽ bắt
`shared/` import `modules/`, đúng điều R-04 chặn.

Lúc viết `C-GO-08`, hệ thống có **một** composition root.

Chặng B kết thúc với hai. `go run ./cmd/dev bootstrap-user` — lệnh tạo user đầu tiên, thứ
phá vòng "muốn tạo user phải có actor, muốn có actor phải đăng nhập, muốn đăng nhập phải
có user" — cũng phải gán vai trò, nên nó cũng cần bảng. Hai `package main` không import
được nhau.

Cùng lúc đó, `authz.Checker` có thêm câu hỏi `VaiTroTonTai(role)`: `UserService` hỏi nó
trước mỗi lần gán, nên một tên vai trò gõ nhầm trả `422` thay vì tạo ra một user đăng nhập
được nhưng không làm được gì trong im lặng. Câu hỏi đó chỉ trả lời được bằng bảng đã tiêm
vào — nên **giá trị của nó phụ thuộc vào việc bảng đó có phải bảng thật hay không**.

Trạng thái trước quyết định này: `cmd/dev` khai một bảng riêng, trong đó mọi tên vai trò
người chạy yêu cầu được coi là "có thật". Nghĩa là đường bootstrap tin chính tả của người
chạy, còn đường API thì không. Chưa có khách hàng thật, chưa có vai trò thứ ba, và bảng
mới có đúng hai dòng — nên cái giá của việc để nguyên vẫn còn nhỏ, nhưng nó sẽ lớn theo
đúng tốc độ mà bảng dài ra.

## Decision

**Bảng vai trò sống ở một package `cmd/internal/vaitro`, và mọi composition root đọc
chung nó.**

- Package đó xuất `Bang() authz.Bang` và hằng tên vai trò (`QuanTri`, `ThanhVien`). Nó là
  **nguồn sự thật duy nhất** của tập tên vai trò trong toàn hệ thống.
- `cmd/api` và `cmd/dev` đều import nó. Không root nào khai bảng riêng.
- Một root **được phép** thêm vai trò tạm của riêng nó vào bản sao nhận về — `cmd/dev`
  thêm `bootstrap` với đúng hai permission. Vai trò tạm không nằm trong bảng chung, không
  user nào mang được, không token nào ký ra.
- Quyết định này **không** đổi `C-GO-08` ở chỗ quan trọng nhất của nó: bảng vẫn là **dữ
  liệu ở composition root**, vẫn dựng từ hằng permission của module, và vẫn không được
  xuống `shared/` hay `modules/`.

## Alternatives

**Để nguyên — mỗi composition root một bảng** — loại vì nó giữ lại đúng cái lỗ mà
`VaiTroTonTai` vừa được thêm để đóng, và giữ nó ở chỗ khó thấy nhất. Cái giá không phải
lý thuyết: `bootstrap-user` là lệnh tạo tài khoản **quản trị đầu tiên**, nên một tên vai
trò gõ nhầm ở đó cho ra một hệ thống mà không ai vào quản trị được, và người chạy sẽ đọc
thông báo "đã tạo user thành công". Hai bảng cũng sẽ lệch theo thời gian, và lệch về phía
im lặng: `cmd/dev` chấp nhận mọi tên, nên nó không bao giờ đỏ.

**Package dùng chung ở `internal/vaitro` (gốc repo, ngoài `cmd/`)** — loại vì `checkR01`
bắt đúng chỗ đó: một package không thuộc `cmd/**` và không thuộc module nào mà import
`erp/modules/auth` rơi vào nhánh mặc định của R-01 và thành vi phạm. Muốn dùng phương án
này phải sửa chính `checkR01` để mở một ngoại lệ theo tên đường dẫn — tức nới một rule
đang ở mức FULL để phục vụ một nhu cầu mà `cmd/internal/` đã giải xong mà không nới gì.

**Bảng vai trò thành dữ liệu trong database** (bảng `roles` + `role_permissions`) — loại ở
thời điểm này. Nó là hướng đúng khi người quản trị cần tự định nghĩa vai trò lúc chạy,
nhưng nó **mất** thứ `C-GO-08` mua được: hôm nay xóa hay đổi tên một hằng permission làm
vỡ build ở composition root, còn với bảng trong DB thì một vai trò mất quyền chỉ lộ ra khi
một người dùng thật bấm nút và nhận `403`. Đổi lấy điều đó phải có nhu cầu thật — hiện
chưa có màn hình quản trị vai trò nào, và hệ thống có đúng hai vai trò.

**File cấu hình YAML mà cả hai root đọc** — loại vì cùng lý do trên, cộng thêm một khoản:
tên permission trong file không được trình biên dịch kiểm, nên một lỗi chính tả ở đó tạo
ra một vai trò thiếu quyền mà không gì báo. Nó chuyển một lỗi biên dịch thành một lỗi vận
hành, đúng chiều ngược với điều `C-GO-08` muốn.

**Cho `cmd/dev` gọi API thay vì chạm database** — loại vì nó không giải được bài toán:
`POST /users` đòi một token, mà chưa có user nào để đăng nhập lấy token. Đó chính là vòng
kín mà lệnh bootstrap sinh ra để phá.

## Consequences

**Được:**

- Một tập tên vai trò duy nhất trong toàn hệ thống. `VaiTroTonTai` có cùng câu trả lời ở
  cả hai đường vào, nên một tên gõ nhầm ở `bootstrap-user` làm lệnh **dừng** thay vì tạo
  ra một tài khoản quản trị không quyền gì.
- Không rule nào phải nới, không checker nào phải sửa. `checkR01` đọc đường dẫn file:
  package này nằm dưới `cmd/` nên nó chịu **đúng** ràng buộc của composition root — chỉ
  được import package gốc của module, cấm `api/`, cấm `internal/`.
- Quy tắc `internal/` của Go chặn mọi thứ ngoài cây `cmd/` import nó. Bảng vai trò không
  lọt xuống được `modules/` hay `shared/` — điều R-04 và R-01 muốn, giờ được compiler giữ
  chứ không chỉ được checker canh.

**Mất:**

- Thêm một tầng thư mục: `cmd/` không còn chỉ chứa các `package main`. Người đọc lần đầu
  phải biết `cmd/internal/` là gì trước khi hiểu bố cục — `C-GO-01` phải ghi nó vào cây
  thư mục chuẩn.
- Hai composition root giờ **chia sẻ trạng thái biên dịch**: đổi bảng vai trò làm cả
  `cmd/api` lẫn `cmd/dev` phải build lại. Đó là cái giá đúng cho một nguồn sự thật, nhưng
  nó có thật.

**Nợ để lại:**

- Quyết định này chỉ đứng vững chừng nào tập vai trò còn do **lập trình viên** quyết. Ngày
  người quản trị cần tự tạo vai trò lúc chạy, nó phải được thay bằng một ADR mới chuyển
  bảng xuống database — và ADR đó phải trả lời cho được câu hỏi mà mục Alternatives ở trên
  đã nêu: mất phép kiểm lúc biên dịch thì lấy gì thay.
- Vai trò tạm mà một root tự thêm (`bootstrap` ở `cmd/dev`) **không** được kiểm bởi gì cả.
  Hôm nay có đúng một cái, phạm vi hai permission, đọc được trong một dòng. Nếu danh sách
  đó dài ra thì nó là một bảng vai trò thứ hai đang mọc, và phải bị chặn.

**Constrains:** —

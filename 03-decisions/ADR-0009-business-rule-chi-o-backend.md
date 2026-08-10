# ADR-0009: Backend là nơi duy nhất giữ business rule

**Status:** Accepted (2026-08-10)

## Context

Hệ thống có hai phần chạy ở hai nơi: backend Go và frontend React chạy trong trình
duyệt của người dùng. Câu hỏi đặt ra ngay khi dựng màn hình đầu tiên — màn hình nhập
đơn hàng — là ai tính thành tiền, ai tính thuế, ai quyết đơn này được duyệt hay không.

Sức ép nghiêng về phía frontend, và sức ép đó có lý: tính ngay trong trình duyệt thì
số hiện lên tức thì, không phải chờ mạng, và người dùng nhập liệu cả ngày sẽ cảm nhận
rõ sự khác biệt.

Nhưng ba điều cũng đúng ở thời điểm đó:

- **Frontend chạy trên máy người dùng.** Mã nguồn tải về được, sửa được, và mọi request
  nó gửi đều dựng lại được bằng tay. Không có gì trong trình duyệt là ràng buộc; mọi
  thứ ở đó là gợi ý.
- API là bề mặt công khai. Ngoài frontend chính thức, sẽ còn script import dữ liệu,
  công cụ nội bộ, và có thể là ứng dụng di động sau này. Mỗi client mới là một bản sao
  của cùng bộ quy tắc nếu quy tắc nằm ở client.
- Nghiệp vụ ERP là nghiệp vụ có tiền: giá, chiết khấu, thuế, tồn kho. Sai một quy tắc
  ở đây không phải lỗi hiển thị mà là sai sổ sách.

## Decision

**Mọi quy tắc nghiệp vụ, mọi tính toán tiền/thuế/tồn kho, và mọi kiểm quyền đều nằm ở
backend. Frontend chỉ lo UX.**

Ranh giới cụ thể, để khỏi tranh cãi từng ca:

- Frontend **được** hiển thị số tạm tính (`qty * price`) cho người dùng thấy trong lúc
  nhập — đó là UX chuẩn mực. Frontend **không được** gửi con số đó lên server; nó chỉ
  gửi đầu vào thô và render lại con số backend trả về.
- Frontend **được** validate định dạng và trường bắt buộc để báo lỗi sớm. Mọi validate
  nghiệp vụ vẫn phải có bản ở backend, và bản ở backend là bản có thẩm quyền.
- Frontend **được** ẩn hoặc tắt nút theo quyền, dựa trên field do API trả về. Ẩn nút
  **không tính** là kiểm quyền; kiểm quyền xảy ra ở service, cho mọi lời gọi, kể cả
  lời gọi không đi qua giao diện nào.

## Alternatives

**Validate ở cả hai phía và coi hai bản là tương đương** — loại, và đây là phương án
duy nhất thật sự cạnh tranh vì nó nghe rất hợp lý. Nó hỏng vì hai lý do:

- **Hai bản logic luôn lệch nhau theo thời gian.** Không phải có thể lệch — luôn lệch.
  Quy tắc thuế đổi, người sửa backend không nhớ có bản thứ hai ở frontend, và không có
  gì báo lỗi. Sự lệch đó không lộ ra ở test nào cả, vì mỗi bên tự test bản của mình và
  cả hai đều xanh.
- **Bản ở frontend là bản người dùng sửa được.** Coi hai bản là tương đương nghĩa là
  chấp nhận một trong hai người canh cửa nằm trong tay người đi qua cửa. Khi hai bên
  bất đồng, bên ở backend phải thắng — mà nếu đã vậy thì bên ở frontend không phải một
  bản kiểm, nó là UX, đúng như quyết định trên đã nói.

**Đẩy quy tắc xuống frontend cho nhanh, backend chỉ lưu trữ** — loại. Nó biến API
thành một lớp ghi database không có ý kiến, và mọi client nào cũng ghi được bất kỳ giá
trị nào. Với dữ liệu có tiền thì đây không phải kiến trúc, đây là một cái lỗ.

**Chia sẻ một bộ quy tắc dùng chung cho cả hai phía** — loại. Nó giải được vế "hai bản
lệch nhau" nhưng không giải được vế thứ hai: bản chạy trong trình duyệt vẫn là bản sửa
được, nên backend vẫn phải kiểm lại toàn bộ. Đổi lại, nó ràng hai stack vào một nhịp
phát hành chung, trái với [ADR-0002](ADR-0002-multi-repo.md).

## Vì sao quyết định này ràng buộc cả R-15 lẫn R-19

Hai rule đó nhìn qua thì rời nhau — một nói về vị trí lời gọi kiểm quyền trong service,
một nói về phép tính trong file `.tsx`. Thực ra chúng là **hai hệ quả của cùng một
quyết định**: *không tin frontend*.

- Nếu không tin frontend thì kiểm quyền không thể nằm ở chỗ frontend chạm tới được, và
  cũng không thể chỉ nằm ở handler — vì handler là lớp vỏ HTTP, còn service là chỗ mọi
  đường vào đều phải đi qua. Đó là R-15.
- Nếu không tin frontend thì con số nó tính ra không được dùng làm dữ liệu ghi vào
  database. Đó là R-19.

Ghi rõ điều này ở đây để lần sau có người đề xuất nới một trong hai, họ thấy ngay rằng
nới một cái là nới cả cặp — không có cách nới R-19 mà vẫn giữ nguyên lý do tồn tại của
R-15.

## Consequences

**Được:**

- **Không có đường nào qua mặt quy tắc bằng cách gọi thẳng API.** Đây là điều đổi lấy
  mọi khoản mất ở dưới.
- Một bản logic duy nhất, ở một chỗ, có test và có audit. Sửa quy tắc thuế là sửa một
  chỗ.
- Client thứ hai (script import, ứng dụng di động, đối tác gọi API) tự động chịu cùng
  bộ quy tắc, không phải viết lại gì.
- Ranh giới trách nhiệm rõ: lỗi tính sai luôn ở backend, không phải chuyện phải điều
  tra hai nơi.

**Mất:**

- **Frontend gọi API nhiều hơn** để lấy giá trị tính sẵn, nên có độ trễ mạng ở những
  chỗ trước đây tính được ngay. Phải xử lý bằng thiết kế UX — debounce, trạng thái
  đang tính, tính tạm để hiển thị — chứ không bằng cách gửi con số tự tính lên.
- Nhiều endpoint hơn: những endpoint chỉ để tính thử (xem trước tổng tiền, xem trước
  thuế) mà không ghi gì.
- Trải nghiệm ngoại tuyến hoặc mạng kém xấu hơn, vì không có gì quyết định được ở phía
  client.
- Backend phải trả về đủ thông tin để frontend dựng giao diện đúng (ví dụ danh sách
  hành động được phép), tức là DTO response phong phú hơn.

**Nợ để lại:**

- Chưa chốt khuôn cho các endpoint tính thử: chúng không tạo tài nguyên nên không hợp
  với R-10 ở dạng thuần, và cần một quy ước riêng ở tầng Convention.
- Chưa chốt tên và hình dạng của field mô tả hành động được phép mà API trả về cho
  frontend dùng để bật/tắt nút.
- Chưa có cơ chế kiểm tự động rằng mỗi validate ở frontend đều có bản tương ứng ở
  backend; hiện chỉ kiểm được chiều ngược lại — frontend không được gửi giá trị tự
  tính lên.

**Constrains:** R-15, R-19

# ADR-0004: Không tích hợp IoT/PLC — Machine và Kalmar là module CRUD

**Status:** Accepted (2026-08-10)

## Context

Khách hàng đầu tiên là doanh nghiệp cơ khí và cảng, nên hệ thống phải quản lý hai
nhóm thiết bị có phần điều khiển điện tử: máy công cụ trong xưởng (máy CNC, máy cắt,
máy hàn) và xe nâng container Kalmar ở cảng. Cả hai nhóm đều **có** PLC, và về mặt kỹ
thuật đều có thể đọc số liệu ra qua OPC-UA hoặc Modbus.

Vì vậy câu hỏi được nêu ngay từ buổi khảo sát đầu tiên: hệ thống có nên kết nối thẳng
tới thiết bị để tự động lấy giờ chạy máy, số chu kỳ, cảnh báo lỗi hay không.

Bối cảnh khi cân nhắc:

- Không có mạng công nghiệp sẵn sàng. Máy trong xưởng nằm trên mạng tách rời hoặc
  không nối mạng; xe Kalmar di động, kết nối chập chờn theo vị trí trong bãi.
- Không có ai trong đội có kinh nghiệm vận hành hệ thu thập dữ liệu công nghiệp, và
  không có ngân sách thuê.
- Nghiệp vụ được đặt hàng là quản lý thiết bị theo nghĩa hành chính: lý lịch máy, kế
  hoạch bảo trì, nhật ký sự cố, chi phí sửa chữa. Không phải giám sát vận hành.
- Không ai nêu được một quyết định cụ thể nào của doanh nghiệp sẽ thay đổi nhờ có số
  liệu theo thời gian thực. Câu trả lời khi hỏi đều ở dạng "để sau này phân tích".

## Decision

**Hệ thống không kết nối trực tiếp tới thiết bị.** Machine và Kalmar là module CRUD
thường; dữ liệu vận hành vào hệ thống bằng nhập tay hoặc import file (CSV/Excel), qua
cùng một đường API `/api/v1` như mọi dữ liệu khác.

Đây là một ADR **quyết không làm**. Nó không cấm vĩnh viễn — nó chốt rằng ở phạm vi
hiện tại, việc này đã được cân nhắc và bị loại, và lật lại nó cần một ADR mới.

## Alternatives

**Tích hợp trực tiếp PLC qua OPC-UA hoặc Modbus** — phương án chính đã cân nhắc, và bị
loại vì bốn lý do độc lập, mỗi lý do đủ để loại:

- **Cần hạ tầng biên.** Thiết bị không nói HTTP. Phải có edge gateway đặt tại xưởng và
  tại cảng để gom, đệm khi mất mạng, và đẩy lên. Đó là một hệ thống thứ hai, có phần
  cứng, có vòng đời cập nhật, và nằm ở nơi không ai trong đội phát triển đứng cạnh
  được.
- **Cần người trực.** Mất kết nối, thiết bị lệch giờ, PLC bị thay bo mạch và đổi địa
  chỉ thanh ghi, cảm biến trôi giá trị — đều là sự cố thường ngày của hệ thu thập dữ
  liệu, và tất cả đều cần người xử lý trong ngày. Không có người đó thì dữ liệu tự
  động sẽ sai một cách âm thầm, tệ hơn nhập tay ở chỗ không ai nghi ngờ nó.
- **Ràng buộc thời gian thực mà phần còn lại của hệ thống không có.** Đọc thanh ghi
  theo chu kỳ mili giây, đệm khi mất mạng, chấp nhận dữ liệu tới muộn và tới không
  đúng thứ tự — đó là một mô hình xử lý khác hẳn với request/response HTTP đồng bộ,
  transaction ngắn, và một bản ghi audit cho mỗi thao tác ghi (R-17) mà toàn bộ kiến
  trúc này dựng trên đó. Nhét luồng thiết bị vào cùng một tiến trình
  ([ADR-0001](ADR-0001-modular-monolith.md)) nghĩa là ép một trong hai mô hình chịu
  ràng buộc của mô hình kia, và bên chịu thiệt sẽ là phần nghiệp vụ.
- **Giá trị nghiệp vụ chưa được chứng minh.** Không có một quyết định nào được nêu ra
  mà số liệu thời gian thực sẽ thay đổi kết quả. Xây một đường ống dữ liệu để chờ ai
  đó nghĩ ra câu hỏi cho nó là thứ tự ngược.

**Mua một hệ SCADA/historian rời rồi tích hợp một chiều sau** — loại ở thời điểm này.
Nó tránh được ba lý do đầu bằng cách mua thay vì tự xây, nhưng chi phí giấy phép và
triển khai vẫn phải trả trước, trong khi lý do thứ tư — chưa ai chứng minh được giá
trị — không thay đổi. Đây là phương án nên xem lại **trước** phương án tự tích hợp,
nếu sau này nhu cầu thành thật.

**Nhập liệu bằng mã vạch / QR tại chỗ** — không loại, nhưng cũng không thuộc ADR này:
nó vẫn là nhập tay, chỉ nhanh hơn. Có thể thêm bất cứ lúc nào mà không lật quyết định
này.

## Vì sao một ADR "không làm gì" vẫn cần tồn tại

Quyết định không làm không để lại dấu vết nào trong code. Không có module nào thiếu,
không có file nào trống, không có gì để một người mới nhìn thấy. Vì vậy nó là loại
quyết định dễ bị mở lại nhất — sáu tháng nữa sẽ có người nêu "sao mình không đọc thẳng
từ PLC nhỉ", và nếu không có trang này thì cả đội sẽ tranh luận lại từ đầu, với ít
thông tin hơn lần trước vì bối cảnh khảo sát ban đầu đã quên.

Trang này chuyển cuộc tranh luận đó từ *"ý này có hay không"* sang *"bối cảnh nào ở
mục Context đã thay đổi"*. Câu hỏi thứ hai trả lời được trong mười phút; câu hỏi thứ
nhất thì không.

## Consequences

**Được:**

- Phạm vi hệ thống nằm gọn trong CRUD, workflow và báo cáo. Không có giao thức thứ
  hai, không có tiến trình chạy dài đọc thiết bị, không có hạ tầng biên phải vận hành.
- Machine và Kalmar tuân đúng bộ Rule chung — cùng cấu trúc tầng, cùng cách kiểm
  quyền, cùng cách audit — nên không có "module đặc biệt" nào phải xin miễn trừ.
- Không có dữ liệu tới muộn và tới không đúng thứ tự, nên không phải giải bài toán
  chỉnh hợp dữ liệu lịch sử.

**Mất:**

- Dữ liệu vận hành phụ thuộc con người nhập: trễ (thường theo ca hoặc theo ngày), có
  sai số, và có khoảng trống khi ai đó quên.
- Không có cảnh báo thời gian thực. Máy hỏng thì hệ thống biết khi có người ghi nhật
  ký sự cố, không sớm hơn.
- Chỉ số hiệu suất thiết bị (OEE và tương đương) chỉ tính được ở độ chính xác của dữ
  liệu nhập tay, nên không dùng để so sánh chi tiết giữa các ca.

**Nợ để lại:**

- Nếu sau này cần, **đường vào đã định sẵn**: một adapter riêng nằm ngoài `modules/`,
  đẩy dữ liệu vào qua chính `/api/v1` như một client bình thường — không phải mở một
  cổng thứ hai vào database. Giữ nguyên tắc đó là cách trả trước rẻ nhất cho khả năng
  này, và nó không tốn gì hôm nay.
- Lật quyết định này cần một ADR mới, và ADR đó phải nêu bối cảnh nào ở mục Context đã
  thay đổi.
- Chưa có quy ước về định dạng file import cho dữ liệu vận hành thiết bị; hiện để mở
  cho từng module tự chốt trong tài liệu của mình
  ([ADR-0005](ADR-0005-documentation-follows-code.md)).

**Constrains:** —

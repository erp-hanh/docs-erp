# ADR-0001: Modular Monolith thay vì microservices

**Status:** Accepted (2026-08-10)

## Context

Hệ thống được khởi động cho **một** khách hàng đầu tiên: một doanh nghiệp cơ khí có
xưởng sản xuất và một mảng dịch vụ cảng. Phạm vi nghiệp vụ rộng — bán hàng, mua hàng,
kho, sản xuất, thiết bị, nhân sự — nhưng lưu lượng nhỏ: vài chục người dùng đồng thời,
dữ liệu đếm bằng triệu dòng chứ không phải tỷ.

Đội phát triển ở mức một nhóm nhỏ, không có người vận hành riêng, không có cluster
Kubernetes đang chạy, và không có kinh nghiệm vận hành hệ phân tán trong môi trường
sản xuất. Hạ tầng sẵn có lúc đó là một PostgreSQL và một máy chủ ứng dụng.

Quan trọng hơn cả quy mô: **ranh giới miền chưa chắc chắn**. Ở thời điểm quyết, chưa
ai trả lời được Sales và Inventory nên là hai thứ tách rời hay một, hay Machine và
Kalmar thực chất là cùng một miền nhìn từ hai phía. Ranh giới đặt sai mà đã nằm sau
ranh giới mạng thì sửa rất đắt — phải đổi hợp đồng API, đổi cách triển khai, và
thường là phải viết một lớp đồng bộ dữ liệu để sống qua giai đoạn chuyển.

Đồng thời, nghiệp vụ ERP có nhiều thao tác đòi **nguyên tử xuyên miền**: duyệt một
đơn hàng vừa đổi trạng thái đơn, vừa giữ tồn kho, vừa ghi một bản ghi audit — cả ba
phải cùng thành công hoặc cùng không.

## Decision

Toàn bộ backend chạy trong **một tiến trình duy nhất**, chia thành module theo miền
nghiệp vụ dưới `modules/<tên>/`, và ranh giới giữa các module được cưỡng chế bằng
**cấu trúc package** — `internal/` là riêng tư, `api/` là mặt công khai — chứ không
bằng ranh giới mạng.

Phạm vi của quyết định này:

- Áp lên backend nghiệp vụ. Relay đọc `outbox` (ADR-0006) là tiến trình riêng vì nó
  phải sống độc lập với vòng đời request, không phải vì nó là một service nghiệp vụ.
- Không áp lên frontend, vốn đã là ứng dụng riêng, và không áp lên cách triển khai:
  chạy nhiều instance của cùng một binary sau load balancer vẫn đúng với quyết định này.

## Alternatives

**Microservices ngay từ đầu** — loại. Đội nhỏ và chỉ có một khách hàng, nên toàn bộ
chi phí của mô hình đó phải trả trước mà không đổi lấy được gì trong tầm nhìn thấy:
service discovery, tracing xuyên tiến trình, hợp đồng API giữa các service, một quy
trình release cho mỗi service, và một môi trường dev dựng được cả cụm. Đắt hơn nữa là
phần không đo bằng tiền: mọi thao tác nguyên tử xuyên miền phải viết lại thành saga
với bước bù trừ, và một saga sai thì hỏng theo cách chỉ lộ ra khi có sự cố. Trong khi
lý do người ta chịu chi phí đó — scale từng phần độc lập, đội độc lập release độc lập
— hiện chưa tồn tại ở đây.

**Monolith không phân module** — loại. Nó rẻ hơn ở tháng đầu và đắt hơn ở mọi tháng
sau. Không có ranh giới nào được cưỡng chế thì repository của bất kỳ chỗ nào cũng
JOIN được sang bất kỳ bảng nào, và sáu tháng sau đồ thị phụ thuộc dày tới mức không
tách nổi một miền ra khỏi phần còn lại — kể cả khi có đủ lý do và đủ người để tách.
Chi phí tách lúc đó không phải là viết service mới mà là gỡ hàng trăm chỗ đọc chéo
bảng, việc không ai ước lượng nổi và vì vậy không ai duyệt.

**Modular monolith với ranh giới chỉ bằng quy ước** — loại. Đây là phương án đã suýt
chọn: chia thư mục theo miền, còn việc không đọc chéo thì "mọi người tự giữ". Loại vì
quy ước không có ai cưỡng chế sẽ hỏng ở đúng lúc dự án gấp, và không có gì trong diff
cho thấy nó vừa hỏng. Vì vậy ranh giới phải chốt xuống thành mệnh đề grep được —
đó là R-01 đến R-04.

## Consequences

**Được:**

- Triển khai đơn giản: một binary, một lần deploy, một chỗ đọc log. Môi trường dev là
  `go run` cộng một PostgreSQL.
- **Transaction xuyên module vẫn nguyên tử.** Duyệt đơn hàng, giữ tồn kho và ghi audit
  nằm trong một `BEGIN ... COMMIT` — không saga, không bù trừ, không trạng thái treo
  giữa chừng.
- Refactor ranh giới còn rẻ: chuyển một thứ từ module này sang module kia là đổi
  package và sửa import, không phải đổi hợp đồng mạng và không phải migrate dữ liệu.
- Gọi trong tiến trình nên không có lỗi mạng ở đường đi giữa hai miền, và không có
  tầng retry nào phải nghĩ tới cho đường đó.

**Mất:**

- **Không scale từng phần độc lập.** Module báo cáo ngốn CPU thì cách duy nhất là
  nhân cả tiến trình lên, kể cả những phần đang rảnh.
- Một lỗi nặng ở một module — panic không bắt, rò goroutine, tiêu hết connection pool
  — kéo theo cả hệ thống. Bán kính vụ nổ bằng toàn bộ ứng dụng.
- Cả hệ thống dùng chung một stack và một lịch release: không thể viết một module bằng
  ngôn ngữ khác, và một thay đổi nhỏ vẫn phải deploy toàn bộ.
- Ranh giới module không có gì ở tầng dưới đỡ. Nếu R-01 đến R-04 không được kiểm trong
  CI thì quyết định này tự thoái hóa thành phương án "monolith không phân module" đã
  bị loại ở trên, và không ai nhận ra lúc nó đang xảy ra.

**Nợ để lại:**

- Nếu sau này phải tách service, **`api/` của mỗi module chính là đường cắt**: nó đã là
  tập hợp interface và DTO mà bên ngoài được phép chạm tới, nên việc tách quy về thay
  phần cài đặt của interface đó bằng một client gọi qua mạng. Giữ cho `api/` mỏng và
  không rò kiểu nội bộ ra ngoài là cách trả trước cho khả năng đó.
- Chưa có gì chặn một module chiếm hết tài nguyên chung (connection pool, goroutine).
  Giới hạn theo module là việc còn để mở.
- Ca hai module phải cùng commit nguyên tử trong khi module này không có tên trong
  `allowed_deps` của module kia hiện chưa có đường đi hợp lệ. R-15 nói rõ đó là chỗ
  phải dừng lại hỏi người và cần một ADR mở đường, không phải chỗ lách.

**Constrains:** R-01, R-02, R-03, R-04

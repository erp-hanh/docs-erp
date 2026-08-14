# ADR-0013: `cmd/api` chạy đúng một instance

**Status:** Accepted (2026-08-14)

## Context

[ADR-0001](ADR-0001-modular-monolith.md) chốt kiến trúc modular monolith cho backend
nghiệp vụ, và ghi rõ trong mục Phạm vi của Decision: *"không áp lên cách triển khai:
chạy nhiều instance của cùng một binary sau load balancer vẫn đúng với quyết định
này."* Đó là một câu **cho phép**, không phải một câu **chốt số**. Nó nói kiến trúc
không cấm nhiều instance, chứ không nói hôm nay chạy bao nhiêu — và bốn chặng sau
(B, C, D, E), không ai quay lại trả lời câu hỏi đó.

Trong lúc đó, [ADR-0003](ADR-0003-multi-tenant-ready.md) đã chốt hệ thống
**single-tenant** trên một database dùng chung: đúng một khách hàng, một doanh nghiệp
cơ khí có xưởng sản xuất và mảng dịch vụ cảng, quy mô vài chục người dùng đồng thời.
Không có đội vận hành riêng, không có Kubernetes đang chạy, và tới đầu chặng F,
`infra-erp` còn là bốn thư mục trống — chưa có gì để triển khai nhiều instance vào.
Không có Redis ở bất kỳ đâu trong hạ tầng hiện có.

Chặng F là chặng đầu tiên cần con số thật cho câu hỏi này: nó dựng registry Prometheus
và `/metrics` lần đầu, và mục 2 của spec thiết kế chặng này hoãn việc xây rate limit
`/auth/login` sang chặng G với lý do tường minh — *"chốt tiền đề của nó (ADR-0013: một
instance) nhưng không xây."* Chặng G không thể quyết đúng câu hỏi "bộ đếm rate limit
sống ở đâu — trong tiến trình hay trong một kho chia sẻ" nếu số instance thật của
`cmd/api` chưa có ai chốt bằng văn bản.

## Decision

**`cmd/api` chạy đúng một instance trong mọi môi trường hiện có (dev, staging,
production).**

- Áp dụng cho tiến trình `cmd/api` — tiến trình phục vụ HTTP nghiệp vụ. Không áp dụng
  cho `cmd/relay`: ADR-0006 đã tính trước khả năng nhiều relay chạy song song (`SELECT
  ... FOR UPDATE SKIP LOCKED` tồn tại đúng vì lý do đó), dù hôm nay nó cũng chỉ chạy
  một. Không áp dụng cho PostgreSQL hay bất kỳ thành phần hạ tầng nào khác.
- Không phải một giới hạn kỹ thuật của kiến trúc — `cmd/api` vẫn stateless đủ để chạy
  nhiều instance sau load balancer, và ADR-0001 vẫn đúng nguyên văn. Đây là một quyết
  định về **vận hành hôm nay**, khớp với quy mô thật (ADR-0001) và với tiền đề
  single-tenant (ADR-0003).
- Hệ quả trực tiếp: mọi bộ đếm cần đúng trên toàn hệ thống (rate limit, ngưỡng thử lại,
  bất kỳ giới hạn "N lần mỗi khoảng thời gian" nào) được phép cài **in-process** — một
  biến sống trong bộ nhớ của tiến trình — mà không cần một kho đếm chia sẻ (Redis hay
  tương tự). Rate limit `/auth/login` ở chặng G là ca đầu tiên dùng tiền đề này.

## Alternatives

**Chạy nhiều instance ngay từ chặng này, "phòng hờ"** — loại. Chi phí trả trước không
tương xứng với lợi ích đo được: quy mô thật là vài chục người dùng đồng thời (ADR-0001,
mục Context), một instance `cmd/api` đủ sức phục vụ. Đổi lại phải trả ngay: một kho đếm
chia sẻ (Redis) phải được vận hành và giám sát dù chưa có tải nào cần nó, và mọi state
trong tiến trình phải thiết kế cho đồng bộ đa instance trước khi có bằng chứng cần thật.
Đúng dạng chi phí mà ADR-0003 đã từ chối khi loại "database-per-tenant": trả trước phần
đắt cho một khả năng chưa ai đòi.

**Không chốt gì, để nguyên câu "cho phép" của ADR-0001** — loại. Đây chính là hiện
trạng trước ADR này, và nó là hiện trạng làm chặng G không quyết được: rate limit đúng
chuẩn P-OBS cần biết bộ đếm sống ở đâu, mà câu hỏi đó không trả lời được nếu không có
một con số thật để đối chiếu. Im lặng ở đây không phải trung lập — nó là chọn ngầm một
trong hai phương án (in-process hoặc kho chia sẻ) mà không ai chịu trách nhiệm giải
trình cho lựa chọn đó.

**Chốt số nhiều hơn một ngay bây giờ (ví dụ hai, cho sẵn một bản dự phòng)** — loại. Hai
instance đằng sau một load balancer đổi hoàn toàn bài toán bộ đếm: một hạn mức "5
lần/phút" thi hành bằng bộ đếm in-process trở thành hạn mức thực tế "10 lần/phút" vì
mỗi instance giữ một bản đếm riêng, không instance nào biết instance kia đã đếm bao
nhiêu. Chốt số này bây giờ, khi hệ thống chưa có instance thứ hai thật, là quyết một
chi phí (kho đếm chia sẻ) cho một khả năng chịu tải chưa ai đo — cùng lý do phương án
đầu tiên bị loại.

## Consequences

**Được:**

- Câu hỏi "rate limit ở chặng G cài bộ đếm ở đâu" có câu trả lời rõ ràng: in-process,
  không cần Redis, không cần vận hành thêm một hạ tầng mới cho một tính năng chưa ai đo
  tải thật.
- Vận hành đơn giản đúng như phần "Được" của ADR-0001 đã hứa: một tiến trình `cmd/api`,
  một chỗ đọc log, một chỗ debug khi có sự cố — không phải suy luận qua nhiều instance
  xem một yêu cầu cụ thể đã rơi vào bản nào.

**Mất:**

- **Không chịu được tải cao hơn một tiến trình xử lý nổi**, và không có dự phòng khi
  `cmd/api` crash hay đang restart — mọi request trong khoảng đó thất bại thay vì được
  load balancer chuyển sang một instance khác.
- Deploy bản mới nghĩa là có một khoảng gián đoạn ngắn (trừ khi có cơ chế riêng ở tầng
  hạ tầng để giảm nó), vì không có instance thứ hai để luân phiên.

**Nợ để lại — điều kiện mở lại quyết định này:**

- **Ngày `cmd/api` chạy instance thứ hai, quyết định này hết hiệu lực và mọi bộ đếm
  in-process đang dựa vào nó thành sai.** Cụ thể: một hạn mức "N lần mỗi khoảng thời
  gian" thi hành bằng biến trong bộ nhớ của một tiến trình, khi có hai tiến trình cùng
  chạy, trở thành hạn mức thực tế **N nhân theo số instance** — mỗi instance đếm riêng,
  không instance nào biết instance kia đã đếm bao nhiêu. Đó chính là ngày phải đổi bộ
  đếm rate limit (và mọi bộ đếm in-process khác dựa trên ADR này) sang một **kho đếm
  chia sẻ** giữa các instance. Lựa chọn kho đếm cụ thể (Redis hay tương đương) là việc
  của ADR mở lại đó, không phải của ADR này.
- Điều kiện mở lại là **sự kiện** "có instance thứ hai", không phải một ngưỡng CPU hay
  RPS cụ thể. Quyết định thêm instance thứ hai (vì lý do chịu tải hay vì lý do sẵn sàng
  cao) và quyết định đổi bộ đếm phải đi cùng nhau trong cùng một thay đổi — tách rời
  nghĩa là có một khoảng thời gian hệ thống chạy hai instance với bộ đếm sai mà không
  ai biết.

**Constrains:** —

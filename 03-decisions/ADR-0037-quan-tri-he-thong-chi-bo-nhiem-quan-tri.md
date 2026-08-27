# ADR-0037: Quản trị hệ thống chỉ bổ nhiệm được người bổ nhiệm được người khác

**Status:** Accepted (2026-08-27)

## Context

Chủ dự án chốt phạm vi màn cấp 1 bằng một câu: *"trên màn phân quyền của super admin thì chỉ có
gán vai trò admin cho admin phân hệ"*. Gán thủ kho, gán kỹ thuật viên là việc của chính những
người vừa được bổ nhiệm, không phải việc của quản trị hệ thống.

**Hôm nay hệ không nói câu đó ở đâu cả.** [ADR-0032](ADR-0032-danh-muc-vai-tro-loc-theo-tham-quyen-cua-actor.md)
mục Decision 1 chốt danh mục `GET /roles` = những vai trò actor **gán được**, tính từ thẩm quyền.
`quan_tri_he_thong` giữ cả ba `<module>.role_assign` (`cmd/internal/vaitro/vaitro.go:385-387`) nên
phép tính ấy cho qua **cả bảy** vai trò — và đường `PUT /users/:id/roles` cũng nhận cả bảy.

Bản giao diện ngày 2026-08-24 xếp ba mã quản trị lên trước và đẩy bốn vai trò nghiệp vụ xuống một
nhóm mang tên *"Vai trò nghiệp vụ - việc của quản trị phân hệ"*. Đó mới là cách **sắp xếp**, không
phải một luật: một `quan_tri_he_thong` vẫn tick được `inventory.thu_kho` và backend vẫn nhận.

**Vì sao không chữa ở giao diện.** ADR-0032 mục Decision 4 nói thẳng: *lọc không bao giờ thay một
phép chặn*. Nếu chỉ ẩn bớt ô chọn mà đường ghi vẫn nhận, thì danh mục đang nói dối theo chiều
ngược lại — giấu một thứ vẫn làm được — và người dùng `curl` một phát là qua.

**Định nghĩa "vai trò admin" là chỗ dễ sai nhất, và hệ đã sai một lần rồi.**
[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) chốt `roles.code` là **nhãn do
người quản trị gõ**, nên không phép kiểm nào được đọc tiền tố hay hậu tố của nó; ADR-0032 mục
Alternatives loại thẳng `LIKE 'inventory.%'` vì một vai trò đặt tên `kho-van` sẽ lọt hoặc bị bỏ
sót, im lặng. Một luật cắt đuôi `.admin` mắc đúng bệnh đó: quản trị đặt tên vai trò là
`truong_kho_vung` thì luật không nhìn thấy.

## Decision

**`quan_tri_he_thong` chỉ gán được những vai trò mà TẬP QUYỀN của chúng chứa ít nhất một
`<module>.role_assign`. Phép chặn nằm ở service, và danh mục chỉ đi theo nó.**

**1. Định nghĩa, đọc từ tập quyền chứ không từ mã.** Một vai trò là *vai trò quản trị phân hệ*
khi tập quyền của nó chứa ít nhất một mã `<module>.role_assign` — tức nó cho người giữ khả năng
**bổ nhiệm người khác**. Trên bộ mặc định hôm nay, phép này chọn ra đúng ba: `auth.admin`,
`inventory.admin`, `machine.admin`.

Định nghĩa này không phải một cách gọi tên khác của "ba mã đó". Nó nói ra **tính chất** khiến
chúng là việc của cấp 1: quản trị hệ thống bổ nhiệm những người sau đó tự phân quyền trong phân
hệ của mình. Một vai trò mới mang `role_assign` sẽ tự động vào tập này; một vai trò tên
`machine.admin_backup` mà không mang `role_assign` thì không, và đó là kết quả đúng.

**2. Phép chặn ở service, không ở giao diện.** `kiemGanMotVaiTro` thêm một vế: actor mang vai trò
dẫn xuất `quan_tri_he_thong` thì vai trò được gán phải thoả mục 1. Vế này chạy trên **mọi** lần
`PUT /users/:id/roles`, kể cả `curl`.

**3. Danh mục đi theo phép chặn, không đi trước nó.** `GET /roles` vẫn lọc bằng đúng
`kiemGanMotVaiTro` như ADR-0032 mục Decision 1 đã chốt — không viết một phép lọc thứ hai. Nhờ vậy
hai đường không thể lệch nhau, và danh mục của `quan_tri_he_thong` co lại còn ba mã **như một hệ
quả**, không như một luật riêng.

**4. Ai KHÔNG bị ảnh hưởng.** `auth.admin` và `<module>.admin` giữ nguyên hành vi: thẩm quyền của
họ vẫn tính đúng như ADR-0024 và ADR-0032. Luật này chỉ thu hẹp đúng một vai trò dẫn xuất.

**5. Hệ quả phải nói ra: `quan_tri_he_thong` không còn tự gán cho mình một vai trò nghiệp vụ.**
Muốn đứng ở phân hệ Kho vận với vai thủ kho để thử một luồng, họ phải nhờ một `inventory.admin`
gán — đúng chiều mà [ADR-0029](ADR-0029-nhan-ban-quan-tri-trong-cung-module.md) đã rào ở trục vai
trò, nay lặp lại ở trục người bổ nhiệm.

## Alternatives

**Ẩn bớt ô chọn ở frontend, giữ nguyên backend** — loại. Nó phá ADR-0032 mục Decision 4 (*lọc
không thay chặn*) và tạo ra loại lỗ hổng tệ nhất: một luật chỉ tồn tại trong giao diện. Người
dùng `curl` không biết luật đó có, và người đọc code backend cũng không.

**Liệt kê ba mã thành một hằng số** — loại, cùng lý do ADR-0032 đã loại `LIKE 'inventory.%'`. Một
hằng ba chuỗi đúng cho bộ vai trò mặc định hôm nay và sai vào ngày đầu tiên ai đó tạo vai trò
quản trị thứ tư. Nó cũng không nói được **vì sao** ba mã ấy khác bốn mã kia.

**Cho `quan_tri_he_thong` gán mọi vai trò, chỉ đổi cách sắp xếp trên màn** — chính là hiện trạng,
và nó là thứ ADR này sinh ra để bỏ. Sắp xếp không phải một luật; nó biến mất ngay khi ai đó mở
màn khác hoặc gọi API thẳng.

## Consequences

**Được:** câu của chủ dự án thành một luật kiểm được bằng máy, ở đúng tầng mà mọi đường đi qua.
Giao diện thôi phải nói dối bằng cách sắp xếp.

**Mất:** một quản trị hệ thống muốn tự thử một luồng nghiệp vụ nay phải nhờ người khác gán vai
trò cho mình. Đây là bất tiện thật và nó sẽ gặp ngay ở máy dev, nơi `admin@gmail.com` hay được
dùng để thử mọi thứ.

**Nợ để lại:** định nghĩa ở mục 1 gắn vào tập quyền, nên đổi tập quyền của một vai trò là đổi
luôn việc quản trị hệ thống có bổ nhiệm được nó không — im lặng, không migration nào báo. Cùng
loại nợ mà ADR-0032 đã ghi cho `inventory.admin`, và cách canh cũng như vậy: một bài test đối
chiếu danh sách vai trò quản trị với bộ mặc định.

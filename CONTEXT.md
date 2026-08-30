# ERP cơ khí và bãi container

Ngôn ngữ chung của hệ thống. File này là **từ điển, không phải spec**: nó nói một từ nghĩa
là gì, không nói code hiện thực nó ra sao. Bản đồ mười hai module và lý do đặt tên tiếng
Anh nằm ở `03-decisions/ADR-0017-muoi-hai-module-va-ten-tieng-anh.md`.

Chỉ ghi những từ **đã va nhau thật** khi làm việc. Một từ chưa gây hiểu nhầm lần nào thì
chưa cần có mặt ở đây.

## Language

### Tên gọi các khối việc

**Module**:
Một trong đúng mười hai khối nghiệp vụ của hệ thống, tên thư mục viết bằng tiếng Anh.
_Avoid_: phân hệ, hệ con

**Kho vận**:
Nhãn tiếng Việt của một **nhóm trong menu**, không phải tên một module. Hôm nay nhóm này
chứa các màn của `inventory`.
_Avoid_: module kho vận, phân hệ kho vận

**`inventory`**:
Module trả lời: vật tư hàng hoá đang có bao nhiêu, ở kho nào, vào ra thế nào.
_Avoid_: module kho vận, module kho hàng, warehouse module

**`yard`**:
Module trả lời: container nào nằm ô nào, bao lâu, cước bao nhiêu. Là một **nguồn doanh thu
dịch vụ**, không phải chỗ chứa vật tư hàng hoá của công ty.
_Avoid_: kho bãi, kho container

### Trong `inventory`

**Kho**:
Một địa điểm chứa vật tư hàng hoá của một công ty. Khác hẳn **bãi** — bãi giữ container
của khách, kho giữ hàng của mình.
_Avoid_: nhà kho, warehouse, điểm lưu trữ

**Vật tư hàng hoá**:
Một mã hàng trong danh mục của một công ty. Tên gọi này mang cả cụm bốn chữ vì chữ ngắn
nào cũng đã có nghĩa hẹp hơn: "vật tư" đọc ra nguyên liệu đầu vào, "hàng hoá" là tên của
một **tính chất** cụ thể bên trong chính danh mục này. Cụm bốn chữ là chữ dân kế toán kho
Việt Nam đang dùng, và MISA đặt tên danh mục tương ứng đúng như vậy.
_Avoid_: vật tư, hàng hoá, sản phẩm, mặt hàng, SKU

**Tính chất**:
Vai của một vật tư hàng hoá **trong chính công ty này**: nguyên vật liệu, thành phẩm, hay
hàng hoá. Cùng một món có thể là thành phẩm của xưởng khác mà là nguyên vật liệu ở đây —
tính chất nói về vai, không nói về bản thân món hàng, nên hai công ty xếp khác nhau là
chuyện thường chứ không phải mâu thuẫn.

Nó nói **ý định chính** của mã, không nói từng lần dùng: thép cây thỉnh thoảng bán lại
nguyên trạng vẫn là nguyên vật liệu. Đổi được bất cứ lúc nào kể cả khi đã có chuyển động,
vì nó không đụng vào một con số nào đã ghi — khác hẳn **mã** và **đơn vị tính**.
_Avoid_: loại, nhóm, phân loại, chủng loại, kiểu

**Chuyển động kho**:
Một lần hàng vào hoặc ra **của một mặt hàng ở một kho**, ghi thành **một dòng sổ**. Đây là
thứ duy nhất tồn được tính ra từ đó, và một dòng đã ghi thì **không sửa được, chỉ xoá**.

Dòng nhập và dòng xuất luôn thuộc về một **phiếu**; dòng **điều chỉnh** thì không — điều
chỉnh là việc lẻ, gộp lô làm mờ trách nhiệm.
_Avoid_: giao dịch kho, bút toán kho

**Giá vốn**:
Số tiền một đơn vị hàng đang gánh trên sổ. Tính theo **bình quân tức thời**, phạm vi **từng
kho**: mỗi lần nhập làm giá bình quân của cặp (kho, mặt hàng) đổi ngay, và mọi lần xuất sau đó
lấy con số vừa đổi ([ADR-0049](03-decisions/ADR-0049-gia-von-binh-quan-tuc-thoi-theo-tung-kho.md)).

Đơn giá của dòng **nhập** là số người dùng gõ - giá **chưa thuế**. Đơn giá của dòng **xuất** là
số máy tính, và không ô nào cho gõ đè.

**Cùng một mặt hàng có giá vốn khác nhau ở hai kho.** Đó là tính chất của phương pháp này, không
phải lỗi dữ liệu.
_Avoid_: giá nhập, giá mua, đơn giá tồn

**Giá nhập gần nhất**:
Đơn giá của lần nhập **mới nhất** của một mặt hàng, tính trên **toàn công ty**. Nó **không phải
giá vốn** và không đi vào một phép tính tồn nào: nó trả lời câu "hôm nay mua vào bao nhiêu", và
là số điền sẵn khi **báo giá bán**.
_Avoid_: giá nhập cuối, giá thị trường

**Phiếu**:
Một chứng từ nhập kho, xuất kho hoặc **chuyển kho**: có số, có ngày, có **đối tác**, và mang
**nhiều dòng hàng**. Phiếu là thứ người ta cầm trên tay và ký; dòng sổ là thứ máy tính tồn
từ đó.

Một dòng hàng của phiếu **nhập** hoặc **xuất** sinh ra đúng **một** chuyển động kho. Một dòng
hàng của phiếu **chuyển** sinh ra **hai** - một dòng xuất ở kho nguồn và một dòng nhập ở kho
đích, trong cùng một giao dịch
([ADR-0048](03-decisions/ADR-0048-phieu-chuyen-kho-mot-dong-hai-chuyen-dong.md)).

Phiếu **thuộc `inventory`** kể từ [ADR-0043](03-decisions/ADR-0043-phieu-nhap-xuat-thuoc-inventory.md).
Trước đó nó bị đặt ở `purchasing` và `sales`, và mục từ này ghi ngược lại điều đang thấy.

Phiếu **không có trạng thái duyệt** — ghi là vào sổ ngay. Thứ cần duyệt là **đơn mua** và
**đơn bán**, và chúng vẫn ở ngoài module này.
_Avoid_: chứng từ kho, đơn nhập, đơn xuất, hoá đơn

**Đối tác**:
Bên kia của một phiếu: **nhà cung cấp** ở phiếu nhập, **khách hàng** ở phiếu xuất. Cùng một
danh mục, khác vai theo loại phiếu — y như cách MISA dùng một trường "Đối tượng" cho cả hai.
Phiếu **chuyển kho không có đối tác**: đối tác là bên ngoài công ty, chuyển kho là chuyện
trong nhà.
_Avoid_: đối tượng, bên bán, bên mua, NCC

**Tồn**:
Số lượng còn lại của một cặp (kho, vật tư hàng hoá), **tính ra từ sổ** khi cần chứ không phải một
giá trị được lưu ở đâu đó.
_Avoid_: số dư kho, tồn kho hiện tại, quantity on hand

**Điều chỉnh**:
Một chuyển động đưa sổ về khớp thực tế cho **một dòng**. Khác **kiểm kê** — kiểm kê là
đếm cả kho rồi chốt một lần, và hệ chưa có.
_Avoid_: sửa tồn, cân kho

**Tồn đầu kỳ**:
Số lượng đang có thật trong kho vào ngày hệ bắt đầu được dùng. Nó vào hệ bằng chính những
dòng chuyển động đầu tiên, không bằng một đường riêng nào.
_Avoid_: số dư đầu, tồn ban đầu, tồn khởi tạo

**Đơn vị tính**:
Đơn vị đo của một vật tư hàng hoá. Dùng chung cho mọi module, nên thêm được nhưng **không sửa và
không xoá** — sửa một đơn vị đang dùng là làm sai toàn bộ số lượng lịch sử trỏ vào nó.
_Avoid_: đơn vị, ĐVT, unit

**Kiểm kê**:
Đếm thực tế cả kho rồi chốt một lần, hệ sinh loạt điều chỉnh theo chênh lệch. Hệ **chưa
có** thao tác này; hôm nay chỉ điều chỉnh được từng dòng.
_Avoid_: kiểm kho, đối chiếu kho, cân kho

**Sổ chuyển động**:
Toàn bộ các dòng chuyển động đọc theo thời gian. Đây là nguồn sự thật duy nhất về tồn.
_Avoid_: lịch sử kho, nhật ký kho, thẻ kho

### Người dùng

**Người dùng**:
Một người đăng nhập được vào hệ, thuộc một phân vùng. Là **đối tượng** được phân quyền, nên
đừng lấy chữ này đặt tên cho màn hình làm việc phân quyền.
_Avoid_: tài khoản, nhân viên, nhân sự

**Quản trị hệ thống**:
Vai trò cao nhất, thấy mọi phân vùng. **Không ai gán được** — nó suy ra từ một cờ trên
chính người dùng, nên không bao giờ có một hàng trong bảng gán vai trò.
_Avoid_: super admin, quản trị viên (chữ này chỉ chung, lẫn ngay với quản trị của một ứng dụng)

**Quản trị ứng dụng**:
Người quản trị một ứng dụng, ví dụ quản trị kho vận. Gán được vai trò **của ứng dụng mình**
cho người khác, không đụng được vai trò của ứng dụng khác.
_Avoid_: admin, trưởng phân hệ

**Thủ kho**:
Người ghi chuyển động hằng ngày. Người dùng chính của `inventory`.
_Avoid_: nhân viên kho, người giữ kho

### Phân quyền

**Phân quyền chức năng**:
Trục quyết định một người **được làm gì**. Đi qua Vai trò.
_Avoid_: quyền hạn, RBAC, phân quyền (một mình chữ này không nói được đang bàn trục nào)

**Phạm vi dữ liệu**:
Trục quyết định một người **được làm trên dữ liệu nào**. Hôm nay chỉ có một loại phạm vi
là kho. Nó trả lời **"của ai"**, không trả lời "còn sống không" — một kho đã đóng vẫn nằm
trong phạm vi của người quản nó, và câu hỏi kho đó còn tồn tại hay không được trả lời ở
bảng kho (ADR-0030).
_Avoid_: phân quyền dữ liệu, quyền xem dữ liệu, mức truy cập, data scope

**Phân quyền**:
Từ bao trùm **cả hai** trục trên. Chỉ dùng khi thật sự nói về cả hai; bàn về một trục thì
gọi đúng tên trục đó.
_Avoid_: cấp quyền, quyền truy cập

**Vai trò**:
Một tập quyền chức năng có tên, gán cho một người trong một phân vùng. Sau ADR-0023, vai
trò là **dữ liệu cấp công ty do quản trị tự khai**, không còn là hằng trong code.
_Avoid_: nhóm quyền, chức danh, group

**Quyền**:
Một hành động đơn lẻ hệ kiểm được, ví dụ "tạo vật tư hàng hoá". Không gán trực tiếp cho người —
quyền chỉ tới qua vai trò. Tập mã quyền ở lại trong code kể cả sau ADR-0023.
_Avoid_: permission, chức năng, thao tác

**Toàn phạm vi**:
Trạng thái một người thấy mọi bản ghi của một loại phạm vi, do vai trò của họ mang theo
quyền đó chứ không do được cấp từng cái.
_Avoid_: full quyền, xem tất cả, không giới hạn

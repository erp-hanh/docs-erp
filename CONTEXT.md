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
Module trả lời: vật tư đang có bao nhiêu, ở kho nào, vào ra thế nào.
_Avoid_: module kho vận, module kho hàng, warehouse module

**`yard`**:
Module trả lời: container nào nằm ô nào, bao lâu, cước bao nhiêu. Là một **nguồn doanh thu
dịch vụ**, không phải chỗ chứa vật tư của công ty.
_Avoid_: kho bãi, kho container

### Trong `inventory`

**Kho**:
Một địa điểm chứa vật tư của một công ty. Khác hẳn **bãi** — bãi giữ container của khách,
kho giữ vật tư của mình.
_Avoid_: nhà kho, warehouse, điểm lưu trữ

**Vật tư**:
Một mã hàng trong danh mục của một công ty.
_Avoid_: hàng hoá, sản phẩm, mặt hàng, SKU

**Chuyển động kho**:
Một lần hàng vào hoặc ra, ghi thành **một dòng sổ**. Nó không phải một chứng từ: không có
số phiếu, không có trạng thái duyệt.
_Avoid_: giao dịch kho, phiếu nhập, phiếu xuất, bút toán kho

**Phiếu**:
Một chứng từ có mã, nhiều dòng và trạng thái duyệt. Phiếu **không thuộc `inventory`** —
nó là thứ `purchasing` và `sales` mang tới.
_Avoid_: chứng từ kho, đơn nhập, đơn xuất

**Tồn**:
Số lượng còn lại của một cặp (kho, vật tư), **tính ra từ sổ** khi cần chứ không phải một
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
Đơn vị đo của một vật tư. Dùng chung cho mọi module, nên thêm được nhưng **không sửa và
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
là kho.
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
Một hành động đơn lẻ hệ kiểm được, ví dụ "tạo vật tư". Không gán trực tiếp cho người —
quyền chỉ tới qua vai trò. Tập mã quyền ở lại trong code kể cả sau ADR-0023.
_Avoid_: permission, chức năng, thao tác

**Toàn phạm vi**:
Trạng thái một người thấy mọi bản ghi của một loại phạm vi, do vai trò của họ mang theo
quyền đó chứ không do được cấp từng cái.
_Avoid_: full quyền, xem tất cả, không giới hạn

# TASK: Chốt RBAC + Data Scope theo ADR-0021

Bạn đang làm việc trên repository backend-erp.

Mục tiêu của task này KHÔNG phải xây toàn bộ trang UI phân quyền.

Mục tiêu là:
1. Đọc và hiểu toàn bộ kiến trúc RBAC + Data Scope hiện tại.
2. Đối chiếu với ADR-0021 "Phân vùng".
3. Xác định chính xác mô hình dữ liệu, domain model, authorization flow và các boundary cần chốt trước khi bắt đầu module Kho.
4. Không được tự ý thay đổi các quyết định kiến trúc đã được ADR chốt.

## 1. BẮT BUỘC ĐỌC TRƯỚC

Hãy tìm và đọc:

- ADR-0021
- Các ADR liên quan đến auth / user / company / phân vùng / permission
- CLAUDE.md và các rule của repository
- modules/auth/
- shared/
- migrations/
- arch/
- các test kiến trúc hiện có

Đặc biệt kiểm tra các quyết định đã chốt:

- 1 person có thể thuộc nhiều phân vùng.
- 1 person dùng 1 password.
- Email unique toàn hệ thống.
- Quan hệ user ↔ company/phân vùng phải bám đúng ADR-0021.
- Không đưa roles[] trở lại users nếu ADR đã loại bỏ.
- Data Scope phải gắn với một bản ghi/quan hệ cụ thể, không treo trên roles[].
- role_id chỉ được sử dụng nếu repository thực sự có mô hình roles tương ứng.
- Không tự tạo lại bảng roles nếu repository/ADR hiện tại cố ý chưa có.
- Token lifetime = 5 phút nếu đây là quyết định đã được ADR chốt.
- Không phá Module Boundary.
- Không cho module khác truy cập trực tiếp DB của auth.

## 2. KHÔNG ĐƯỢC CODE NGAY

Trước tiên hãy audit repository.

Xuất báo cáo theo cấu trúc:

### A. Current State

Hiện tại repository đã có gì liên quan đến:

- users
- companies
- user_companies
- phân vùng
- role
- permission
- data scope
- JWT/token
- middleware
- authorization service
- repository
- migration

Với mỗi phần, chỉ rõ:
- file
- struct/table/function liên quan
- đang hoạt động hay chỉ là skeleton
- phù hợp hay mâu thuẫn với ADR-0021

### B. ADR-0021 Compliance

Lập bảng:

| Quyết định ADR-0021 | Code hiện tại | Status | Vấn đề |
|---|---|---|---|

Status chỉ dùng:
- PASS
- PARTIAL
- FAIL
- MISSING

### C. Những thứ còn thiếu để module Kho có thể sử dụng authorization

Phân biệt rõ:

1. Authentication
2. RBAC
3. Data Scope
4. Tenant/company isolation
5. Module permission
6. Resource/action permission

Không trộn chúng thành một khái niệm.

### D. Đề xuất mô hình cuối cùng

Đề xuất:

- database tables
- foreign keys
- unique constraints
- indexes
- Go structs
- service interfaces
- authorization flow
- middleware boundary
- service-layer authorization
- data-scope resolution
- cách truyền authorization context từ request → service → repository

Đặc biệt giải thích:

"User có role gì?" khác với
"Role được áp dụng cho user ở phạm vi nào?" khác với
"User được nhìn thấy những record nào?"

### E. Data Scope

Đây là phần quan trọng nhất.

Hãy thiết kế Data Scope sao cho sau này module Kho có thể làm được các trường hợp:

Ví dụ:

User A:
- được quyền xem tồn kho
- chỉ được xem Kho A và Kho B

User B:
- được quyền xem tồn kho
- chỉ được xem Kho C

User C:
- có quyền quản lý toàn bộ kho của company

Phải chỉ ra:

- scope được lưu ở đâu
- scope gắn với user hay role
- scope gắn với company/phân vùng thế nào
- cách resolve scope
- repository áp scope vào SQL thế nào
- làm thế nào tránh developer quên điều kiện scope

## 3. NGUYÊN TẮC QUAN TRỌNG

Không được thiết kế RBAC theo kiểu:

user.roles[]

Không được tự tạo:

roles[]
permissions[]
data_scopes[]

trong users nếu ADR-0021 không cho phép.

Không được biến Data Scope thành một danh sách ID nhét vào JWT.

Không được để handler tự quyết định quyền.

Không được để repository tự hiểu business permission.

Authorization phải có boundary rõ ràng:

handler
↓
service
↓
authorization
↓
repository

Nhưng hãy kiểm tra kiến trúc thực tế của repo trước khi áp dụng; không được áp đặt máy móc nếu trái với các ADR hiện có.

4. NGUYÊN TẮC CHO MODULE KHO

Thiết kế authorization phải đủ để module Kho sau này có thể khai báo:

inventory.view
inventory.create
inventory.update
inventory.delete
stock_receipt.view
stock_receipt.create
stock_receipt.approve
stock_issue.view
stock_issue.create
stock_issue.approve
stock_transfer.view
stock_transfer.create
stock_transfer.approve
stocktake.view
stocktake.create
stocktake.approve

Nhưng:

KHÔNG implement module Kho trong task này.

KHÔNG tạo UI phân quyền trong task này.

Chỉ cần đảm bảo authorization core đủ khả năng phục vụ module Kho.

5. ARCHITECTURE RULES

Tuân thủ tuyệt đối:

R-01 Module Boundary
R-02 No Cross-Module DB Access
R-03 Layered Structure
R-04 Dependency Direction
R-05 Events for Decoupling
R-06 Tenant Column Everywhere

Nếu phát hiện RBAC/Data Scope hiện tại mâu thuẫn với một rule:

KHÔNG tự sửa.

Hãy báo:

rule nào bị vi phạm
file nào
tại sao
phương án sửa
ảnh hưởng đến ADR nào
6. OUTPUT GIAI ĐOẠN 1

Chỉ trả về:

Current Architecture
ADR-0021 Compliance Matrix
Các vấn đề phát hiện
Proposed RBAC model
Proposed Data Scope model
Authorization flow
Database changes cần thiết
Migration plan
Test plan


### Tôi đặc biệt khuyên bạn chia thành **2 prompt**

Prompt trên là **Giai đoạn 1 — Architecture Audit**.

Sau khi Claude trả kết quả, bạn mới dùng prompt thứ 2:

```text id="70451"
Dựa trên báo cáo audit vừa thực hiện và các quyết định tôi đã approve:

Hãy IMPLEMENT RBAC + Data Scope core theo đúng thiết kế đã được duyệt.

Trước khi sửa file:

1. Liệt kê chính xác các file sẽ tạo/sửa.
2. Liệt kê migration sẽ tạo.
3. Liệt kê các invariant cần bảo vệ.
4. Liệt kê các test cần thêm.

Sau đó mới implement.

Bắt buộc:

- Không thay đổi ADR-0021.
- Không tạo lại roles[] trong users.
- Không tự tạo module mới nếu kiến trúc hiện tại không cho phép.
- Không cho module khác truy cập DB của auth.
- Không phá R-01 → R-06.
- Không implement UI phân quyền.
- Không implement module Kho.
- Không thêm permission nghiệp vụ ngoài phạm vi cần thiết để chứng minh authorization core.
- Không đưa Data Scope vào JWT nếu thiết kế được duyệt không yêu cầu.
- Mọi query tenant phải đảm bảo company_id.
- Mọi Data Scope phải được áp dụng ở service/repository boundary phù hợp và không phụ thuộc vào việc developer nhớ viết thủ công ở từng handler.

Sau khi implement:

1. Chạy unit tests.
2. Chạy architecture tests.
3. Chạy lint.
4. Kiểm tra migration.
5. Kiểm tra race/concurrency nếu authorization cache/context có state.
6. Review lại toàn bộ diff.

Cuối cùng báo cáo:

- Files changed
- Database changes
- Authorization flow
- Tests added
- Commands đã chạy
- Kết quả
- Các điểm còn TODO

kết quả Claude trả về từ Prompt 1, bạn review  theo kiểu Senior Architect
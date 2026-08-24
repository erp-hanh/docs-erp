# ADR-0032: Danh mục vai trò lọc theo thẩm quyền của actor, và module suy từ tập quyền chứ không từ mã vai trò

**Status:** Proposed (2026-08-24)

## Context

Spec `99-meta/my-specs/2026-08-24-phan-quyen-hai-cap-spec.md` chia màn phân quyền thành hai
cấp. Cấp 2 là màn của quản trị phân hệ: trưởng kho mở quyền cho nhân viên **trong phân hệ của
mình**. Bản rút gọn đã lên `main` ở `v0.1.0-rc.39`, và lúc đi thử trên máy dev thì lỗ hổng lộ
ra ngay.

**Dữ kiện đo được.** Ba vai trò mở được màn `/phan-quyen`, đọc từ
`backend-erp/migrations/000025_vai_tro_xuong_database.up.sql`:

| Vai trò | `auth.user_list` | `auth.user_assign_roles` | `auth.user_assign_scopes` |
|---|---|---|---|
| `auth.admin` | dòng 158 | dòng 154 | dòng 155 |
| `inventory.admin` | dòng 165 | có | có |
| `machine.admin` | dòng 210 | có | có |

`quan_tri_he_thong` **không** nằm trong bảng này: nó là vai trò dẫn xuất giữ đúng năm mã
`auth.company_*` ([ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) mục 5), nên hôm nay nó nhận
`403` ở chính màn phân quyền. [ADR-0031](ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md)
(`Proposed`) mới đề xuất mở.

**Hệ quả trên màn hình.** Màn không lọc gì cả. Một `inventory.admin` thấy **toàn bộ bảy** vai
trò của phân vùng, kể cả `machine.viewer`, `machine.ky_thuat` và `auth.admin`, và thấy **toàn
bộ** người dùng. Tick một vai trò của module khác rồi bấm Lưu thì bị từ chối `403`, vì
[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) tính thẩm quyền từ tập quyền:
gán `machine.viewer` đòi `machine.role_assign`, thứ `inventory.admin` không có.

**Quyết định đang đứng chắn.** `frontend-erp/src/modules/user/api/user-api.ts:107-113` ghi rõ
đó là chủ ý:

> `VaiTroKhaDungDTO` là một dòng của `GET /roles`. Backend cố ý KHÔNG trả tên permission cần
> có để gán vai trò đó: câu hỏi "người đang xem có gán được vai trò này không" do đường PUT
> trả lời bằng một 403 thật, không do màn hình tự đối chiếu rồi ẩn bớt ô chọn (c-ts-06).

Câu đó **đúng cho thứ nó nói tới** và ADR này không phủ nhận nó: frontend không được tự suy ra
thẩm quyền. Nhưng nó bị đọc rộng thành "backend cũng không được nói", và đó là chỗ phải tách.
Có ba câu khác nhau đang bị gộp làm một:

1. *Frontend tự đối chiếu permission rồi ẩn ô chọn* — cấm, và giữ nguyên cấm.
2. *Backend trả một danh mục đã lọc theo actor* — chưa ADR nào cấm.
3. *Ẩn một ô chọn thay cho một phép chặn* — cấm, mãi mãi.

**Bất đối xứng của ADR-0024, và nó quyết định cách viết query.** ADR-0024 chốt rằng
`roles.code` là **nhãn định danh do người quản trị gõ**, nên không phép kiểm nào được đọc tiền
tố của nó. Còn `permission_code` thì đến từ danh mục hằng tiêm từ composition root
([ADR-0023](ADR-0023-vai-tro-xuong-database.md) mục 7), nên cắt tiền tố của nó **là an toàn** -
đó chính là điều ADR-0024 mục 1 đã cho phép. Vậy "vai trò này thuộc phân hệ nào" phải đọc từ
`role_permissions`, không đọc từ `roles.code`.

**R-06 không chặn.** `roles` và `role_permissions` đều mang `company_id NOT NULL` (migration
`000025` dòng 47 và 68), `user_company_roles` cũng vậy (ADR-0019 mục 3). Nên câu truy vấn mới
thoả được vế hai của R-06 mà `backend-erp/arch/checks_migration.go:207-249` đòi. Đây là chỗ
khác hẳn ca của ADR-0019 giai đoạn hai, nơi câu "người này vào được phân vùng nào" theo định
nghĩa không có `company_id`.

## Decision

**`GET /roles` trả danh mục đã lọc theo thẩm quyền của actor. Module của một vai trò suy từ tập
quyền của nó, không từ mã của nó. Lọc là chuyện hiển thị và không bao giờ thay một phép chặn.**

**1. Hợp đồng của `GET /roles` đổi.** Nó trả về những vai trò mà actor **gán được**, tính bằng
đúng phép kiểm đã có: lấy tập quyền của vai trò, bỏ tập tự tác động
([ADR-0028](ADR-0028-quyen-tren-chinh-minh-khong-keo-theo-cua-module.md)), gom tiền tố module
của phần còn lại, rồi đòi actor có `<module>.role_assign` của **mọi** module gom được. Đó là
logic của `kiemGanVaiTro` (`backend-erp/modules/auth/internal/service/user_service.go`), và
điểm cốt lõi là **dùng lại nó chứ không viết bản thứ hai**. Hai bản của cùng một phép kiểm là
hai bản sẽ lệch, và lệch ở đây nghĩa là danh mục hiện một vai trò mà đường PUT từ chối.

Response giữ nguyên hình dạng `{ma, nhan}` và **không** thêm cờ `co_gan_duoc`. Không có cờ thì
frontend không có gì để đối chiếu, nên nó không thể tự suy — câu ở `user-api.ts:107` vẫn được
tôn trọng đúng phần cốt lõi.

**2. `GET /users` nhận tham số `module`.** `GET /users?module=inventory` trả người dùng đang
mang **ít nhất một** vai trò mà tập quyền của nó chạm module `inventory`. Không truyền tham số
thì hành vi **không đổi** — đó là điều kiện để bản này không phá màn phân quyền của
`auth.admin`.

Câu truy vấn đi `user_company_roles` → `roles` → `role_permissions`, lọc trên
`permission_code LIKE 'inventory.%'`, và mang `company_id = $1` lấy từ `actor.CompanyID`.

**3. Cấm cắt tiền tố `roles.code`.** Ở cả hai mục trên, module đọc từ `permission_code`. Một
`LIKE 'inventory.%'` trên `roles.code` là thứ ADR-0024 đã loại, và nó sai thật: một quản trị
đặt tên vai trò là `inventory_kho` hay `kho-van` thì phép lọc bỏ sót, im lặng.

**4. Lọc KHÔNG phải chặn, và đây là mệnh đề phải nhắc mỗi lần.** Cửa vẫn nằm ở
`s.authz.Can(...)` tại service theo R-15, và `kiemGanVaiTro` vẫn chạy trên mọi lần PUT. Một
`PUT /users/:id/roles` mang một mã vai trò không có trong danh mục đã lọc vẫn phải bị từ chối
`403` bởi service, **không** phải bởi việc nó vắng mặt trong một danh sách. Ai bỏ phép kiểm ở
service vì "danh mục đã lọc rồi" là mở một lỗ có thể khai thác bằng `curl`.

**5. Ai thấy gì sau khi thi công:**

| Actor | Thấy nhân sự nào | Thấy vai trò nào |
|---|---|---|
| `auth.admin` | Toàn phân vùng | Bảy vai trò — nó có `auth.role_assign`, và ADR-0029 xác nhận nó gán được cả chính nó |
| `inventory.admin` | Người mang vai trò chạm `inventory` | Chỉ vai trò mà tập quyền nằm gọn trong `inventory` |
| `machine.admin` | Người mang vai trò chạm `machine` | Chỉ vai trò thuộc `machine` |
| `quan_tri_he_thong` | `403` hôm nay | `403` hôm nay; đổi khi ADR-0031 được nhận |

Lưu ý một hệ quả không hiển nhiên: `inventory.admin` **không** thấy `inventory.admin` trong
danh mục, vì tập quyền của vai trò đó mượn bốn mã `auth.*` nên phép gom ra hai module và nó
thiếu `auth.role_assign` (ADR-0029 bảng ở mục Context). Nghĩa là trưởng kho không tự nhân bản
được — nhưng đó là **hệ quả của nội dung tập quyền**, không phải một luật, đúng như ADR-0029
mục Mất đã cảnh báo. Đổi tập quyền của `inventory.admin` là đổi luôn danh mục nó thấy, im lặng.

**6. Phạm vi.** ADR này KHÔNG quyết: màn cấp 2 có địa chỉ riêng trong vỏ phân hệ hay không (lỗ
ghi ở spec mục 4b), đường ghi tập quyền của một vai trò (đợt 2b), và việc mở quyền cho
`quan_tri_he_thong` (ADR-0031).

## Alternatives

**Thêm cờ `co_gan_duoc` vào từng dòng của `GET /roles`, frontend tự ẩn** — loại. Nó trả về đúng
hình dạng mà `user-api.ts:107` đã cân và đã loại: frontend nhận một mảnh dữ liệu về thẩm quyền
rồi tự quyết hiển thị. Lần này thì nó chỉ ẩn một ô chọn, nhưng nó tạo tiền lệ cho lần sau có
người dùng cùng cờ đó để ẩn một cái nút — và lúc đó câu "ẩn theo quyền là UX, không phải bảo
mật" bắt đầu bị đọc thành ngược lại. Lọc ở nguồn thì frontend không có gì để đoán.

**Giữ nguyên hiện trạng, dựa vào 403** — loại, và lý do không phải sự bất tiện. Một trưởng kho
thấy `auth.admin` trong danh mục vai trò sẽ đọc ra rằng mình **được phép** gán nó; màn hình đang
nói sai về quyền của chính người đang xem. Cộng thêm: bảy vai trò trong đó bốn cái không dùng
được là bốn cách bấm sai, và mỗi lần bấm sai tốn một vòng mạng cùng một thông điệp lỗi.

**Lọc bằng `roles.code LIKE 'inventory.%'`** — loại. ADR-0024 đã cấm đọc tiền tố mã vai trò, và
ở đây nó sai thật: mã vai trò do người quản trị gõ, nên một vai trò đặt tên khác khuôn sẽ bị bỏ
sót mà không phép kiểm nào báo.

**Viết một phép kiểm riêng cho việc lọc, tách khỏi `kiemGanVaiTro`** — loại. Hai bản của cùng
một phép kiểm sẽ lệch, và hình dạng của lỗi là: danh mục hiện một vai trò mà đường PUT từ chối,
hoặc tệ hơn, danh mục ẩn một vai trò mà đường PUT cho qua.

**Thêm tham số `module` vào `GET /roles` thay vì lọc theo actor** — loại. Nó bắt frontend nói ra
mình đang ở module nào, tức chuyển một quyết định về thẩm quyền thành một tham số do client
chọn. Client chọn `module=auth` thì thấy danh mục của module đó. Lọc theo actor thì không có
tham số nào để chọn sai.

## Consequences

**Được:**

- Màn phân quyền thôi nói sai về quyền của người đang xem.
- Đúng một nguồn sự thật cho câu "actor này gán được vai trò nào": `kiemGanVaiTro`.
- Câu ở `user-api.ts:107` được giữ đúng phần cốt lõi — frontend vẫn không có dữ liệu nào để tự
  suy thẩm quyền.
- Query mới thoả R-06 mà không cần miễn trừ nào.

**Mất:**

- **`GET /roles` từ nay trả kết quả KHÁC NHAU cho hai người gọi khác nhau.** Đó là một endpoint
  danh mục mà không còn là một danh mục cố định, nên nó không cache dùng chung được, và một báo
  lỗi kiểu "vai trò X không hiện" từ nay phải hỏi thêm "bạn đăng nhập bằng ai".
- `inventory.admin` không thấy `inventory.admin` trong danh mục, và điều đó **phải đọc tập
  quyền mới hiểu** — nhìn giao diện thì nó đọc ra như một thiếu sót.
- Thêm một đường mà tập quyền của các vai trò `<module>.admin` ảnh hưởng tới thứ người dùng
  nhìn thấy. Đổi tập quyền là đổi danh mục, im lặng.
- Một câu truy vấn ba bảng cho một danh sách người dùng. Cần index; chưa đo.

**Nợ để lại:**

- **Chưa xác minh** `GET /roles` và `GET /users` hôm nay nằm ở handler nào và ký gì — chưa đọc
  `modules/auth/internal/handler/`. Phải đọc trước khi viết dòng đầu.
- **Chưa xác minh** `kiemGanVaiTro` có tách được phần "actor gán được vai trò nào" thành một
  hàm dùng lại được mà không phá R-15 hay không.
- **Chưa đo** chi phí câu truy vấn ba bảng, và chưa biết có cần index mới trên
  `role_permissions(company_id, permission_code)` hay không.
- Một test phải khoá bất biến mục 4: `PUT /users/:id/roles` với một mã vai trò **không** có
  trong danh mục đã lọc vẫn phải bị từ chối bởi service. Không có test đó thì mục 4 chỉ là một
  câu trong tài liệu.
- Lỗ ở spec mục 4b vẫn còn: bấm mục ở thanh bên Kho vận vẫn đẩy người dùng ra khỏi vỏ phân hệ.

**Constrains:** —

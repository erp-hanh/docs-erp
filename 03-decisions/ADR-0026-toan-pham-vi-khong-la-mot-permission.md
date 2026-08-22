# ADR-0026: "Toàn phạm vi" là một giá trị của phạm vi, treo trên hàng gán vai trò — không phải một permission

**Status:** Accepted (2026-08-22)

## Context

Tại thời điểm quyết, hệ thống trả lời câu hỏi "người này thấy những bản ghi nào" bằng hai cơ
chế đặt ở hai chỗ khác nhau, cộng dồn theo hai luật khác nhau.

**Cơ chế thứ nhất — permission, cộng dồn theo NGƯỜI.** `shared/scope/resolver.go:56-61` là toàn
bộ đường chốt phạm vi:

```go
func (r *resolver) Resolve(ctx context.Context, actor auth.Actor, loai Loai, permToanPham string) (Pham, error) {
	if r.kiemQuyen.Can(ctx, actor, permToanPham) == nil {
		return r.toanPhamVi(ctx, actor.CompanyID, loai)
	}
	return r.theoCapPhat(ctx, actor.CompanyID, actor.UserID, loai)
}
```

`Can` duyệt **mọi** vai trò trong `actor.Roles` và trả `nil` ngay khi một vai trò bất kỳ mang mã
quyền được hỏi (`shared/authz/authz.go:151-165`). Nên nhánh toàn phạm vi mở ra vì **một** vai
trò của người đó, không phải vì vai trò đang được xét. Mã quyền đó là
`inventory.PermWarehouseScopeAll = "inventory.warehouse_scope_all"`
(`backend-erp/modules/inventory/internal/service/permissions.go:96`), nối vào danh mục loại
phạm vi ở `backend-erp/cmd/internal/phamvi/phamvi.go:28`, và bốn method của
`WarehouseService` cùng bốn method của `MovementService` gọi `Resolve` với đúng hằng đó.

[ADR-0023](ADR-0023-vai-tro-xuong-database.md) mục 6 đã chốt luật cộng dồn ấy thành một mệnh
đề: quyền của nhiều vai trò trên cùng một người là **hợp**, không phải giao, và "không có cách
nào cấm một quyền cụ thể cho một người đã có nó qua một vai trò khác".

**Cơ chế thứ hai — phạm vi, treo theo từng HÀNG vai trò.** `user_company_role_scopes`
(`backend-erp/migrations/000023_create_user_company_role_scopes.up.sql`) treo mỗi dòng phạm vi
vào một `user_company_roles.id` cụ thể. [ADR-0020](ADR-0020-data-scope-theo-ban-ghi.md) mục 1b
đã đính chính rằng đường **đọc** lại hợp nhất theo người — câu SQL lọc theo người, phân vùng và
loại, không lọc theo `role_code` — nên hàng vai trò là **mốc vòng đời** của phạm vi chứ không
phải một ngăn chứa riêng.

**Hai cơ chế đó không khớp nhau, và hậu quả đã cụ thể.** Một người mang `inventory.thu_kho` —
vai trò cố ý **không** có `warehouse_scope_all`, lý do ghi ngay tại
`backend-erp/cmd/internal/vaitro/vaitro.go:156-166` — được cấp đúng kho A trong
`user_company_role_scopes`. Gán thêm cho họ `inventory.admin`, vai trò duy nhất trong bộ bảy
mang mã quyền ấy (`vaitro.go:274`), là họ **ghi được vào mọi kho của phân vùng**, kể cả kho chưa
ai cấp cho họ. Hàng phạm vi kho A vẫn nằm nguyên trong database, vẫn còn `deleted_at IS NULL`,
và không còn nghĩa gì.

Đường **ghi** phạm vi đã biết trước điều đó và đã dựng một hàng rào quanh nó chứ không đóng nó:
`backend-erp/modules/auth/internal/service/scope_service.go:405-424` từ chối 422 khi ai đó gửi
id cho một vai trò toàn phạm vi, và ghi chú tại chỗ thừa nhận rằng những hàng phạm vi sinh ra
**trước** bản vá vẫn sống sót cho tới lần `ThayPhamVi` kế tiếp, vì "không có migration nào quét
ngược lại dữ liệu đã có". Đường **báo cáo** thì phải dựng một `auth.Actor` giả tại chỗ để hỏi
ngược bảng phân quyền — `vaiTroToanPhamVi` (`scope_service.go:200-206`) đóng gói
`auth.Actor{CompanyID: companyID, Roles: []string{roleCode}}` chỉ để hỏi "cái TÊN vai trò này
có mang mã quyền kia không", vì `authz.Checker` không có cửa nào khác trả lời được câu đó.

**[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md), Accepted cùng ngày, làm lỗ
này dễ chạm hơn.** Trước ADR-0023 ô `warehouse_scope_all` chỉ nằm trong bộ bảy vai trò do code
khai. Sau ADR-0023 nó là một dòng `role_permissions` trong database, và sau ADR-0024 nó
**tick được bởi bất cứ ai có `inventory.role_assign`** — quyền cửa của việc gán vai trò. Nghĩa
là từ nay việc **mở rộng phạm vi dữ liệu** đi qua `inventory.role_assign`, trong khi
`inventory.scope_assign` — permission mà [ADR-0021](ADR-0021-vai-tro-theo-module.md) mục 4 dựng
ra đúng để trả lời "ai được gán phạm vi cho người khác" — không được hỏi tới. Một người quản
trị kho tick ô ấy vào `inventory.thu_kho` là mở toàn bộ kho cho **mọi** thủ kho của công ty
cùng lúc, và không màn nào liệt kê ra ai vừa bị chạm.

**ADR-0020 mục 4 đã chọn permission, và đã nêu ba lý do.** Nó đi qua đúng bộ máy `authz` đang
chạy nên R-15 không phải nới; "bảng vai trò nói thật ai thấy được gì mà không phải đi đọc một
cột boolean trong database"; và nó là cùng nước đi mà ADR-0019 mục 5 đã dùng khi chọn vai trò
dẫn xuất thay vì đọc thẳng một cờ. Lập luận đó được chép lại và mở rộng thành hai mươi dòng ghi
chú ở `permissions.go:78-95`, dưới tiêu đề "Vì sao một PERMISSION chứ không phải một cột boolean
trên vai trò". Cả ba lý do đứng trên một tiền đề chung: **bảng vai trò là dữ liệu ở code**, do
`cmd/internal/vaitro` khai, theo ADR-0010. ADR-0023 đã lật tiền đề đó — ADR-0010 mang
`Superseded by ADR-0023`, bảng vai trò là hai bảng trong database, do quản trị của từng công ty
tự tạo và tự tick.

**Nửa giao diện, tại thời điểm quyết, im lặng đúng ở chiều nguy hiểm.**
`frontend-erp/src/modules/user/api/user-api.ts:183-196` có vị ngữ `phamViMatKhiGo` trả lời "gỡ
mã vai trò này thì mất những gì", `UserDetailPage.tsx:248-255` dựng danh sách cảnh báo từ tập
vai trò **sẽ gỡ**, và `VE_CANH_BAO_MOC_VONG_DOI` (`user-api.ts:201`) nói ra hậu quả không hoàn
tác được. Chiều **thêm** không có vị ngữ nào: tick thêm một vai trò mang `warehouse_scope_all`
là một cú bấm không sinh ra một dòng chữ nào, và nút lưu vẫn đọc là "Lưu vai trò"
(`UserDetailPage.tsx:341-345`).

Màn phạm vi thì hiển thị trạng thái toàn phạm vi bằng một dòng chữ **chết**:
`UserDetailPage.tsx:626-631` thay cả ô chọn của loại đó bằng câu *"Người này thấy mọi kho nhờ
vai trò X. Gán phạm vi ở đây không đổi điều đó."* Và vì `gomTheoLoai`
(`UserDetailPage.tsx:471-498`) hợp nhất theo **loại** chứ không theo hàng vai trò, chỉ cần một
hàng vai trò toàn phạm vi là ô chọn của cả loại đó biến mất — tức trong đúng ca ở trên, kho A đã
cấp không những mất tác dụng mà còn không sửa được trên màn.

Hai điều chưa biết, và cả hai đều nới không gian lời giải: loại phạm vi thứ hai mà ADR-0020 dự
liệu **chưa tồn tại** — `phamvi.Bang()` có đúng một dòng, `scope.Kho` — nên chưa có dữ liệu nào
của loại khác phải chuyển; và đường ghi vai trò của ADR-0023 đợt 2 **chưa mở**, nên tại thời
điểm quyết chưa công ty nào tick được ô ấy vào một vai trò ngoài bộ nạp mặc định.

## Decision

**"Toàn phạm vi" thôi là một permission và trở thành một giá trị của phạm vi, lưu cùng chỗ với
phạm vi và treo trên từng hàng gán vai trò.**

**1. `inventory.warehouse_scope_all` bị bỏ khỏi tập mã quyền.** Hằng
`PermWarehouseScopeAll` biến mất khỏi `permissions.go`, khỏi bộ nạp mặc định của
`inventory.admin`, và khỏi danh mục hằng mà composition root tiêm xuống module `auth`
(ADR-0023 mục 7). Trường `auth.PhamViKhaDung.PermToanPham` (`modules/auth/module.go:131`) và
tham số `permToanPham` của `scope.Resolve` mất theo. Không mã quyền nào thay chỗ nó.

Điều này **lật mục 4 của ADR-0020**. Ba lý do của mục ấy đứng trên tiền đề "bảng vai trò là dữ
liệu ở code", và ADR-0023 đã lấy tiền đề đó đi. Mệnh đề trung tâm của ADR-0020 — *Data Scope là
một tập id bản ghi, treo vào một hàng gán vai trò, giải ở tầng service, không đi vào token* —
không bị lật mà được siết chặt thêm, nên ADR-0020 **không** mang `Superseded by`; quan hệ ghi
một chiều ở đây, đúng cách ADR-0021 mục 7 đã làm với ADR-0019 mục 5.

**2. Nơi lưu là một bảng thứ tư trong nhóm bảng gán:
`user_company_role_full_scopes(company_id, user_company_role_id, scope_type)`.** Sự **có mặt**
của một hàng còn sống nghĩa là hàng vai trò đó không bị giới hạn theo loại ấy. Thu hồi là xoá
mềm (R-18), và sau khi xoá mềm người đó rơi về đúng tập id đã được cấp — có thể rỗng, và rỗng
nghĩa là **không thấy gì**, không bao giờ nghĩa là tất cả (ADR-0020 mục 3).

Bảng nghiệp vụ theo C-DB-03, không vào registry C-DB-04: đủ `company_id` (R-06), ba cột thời
gian (R-08), hai cột audit (R-17), chịu xoá mềm (R-18). Một partial unique index dẫn đầu bằng
`company_id` theo C-DB-05:
`uq_user_company_role_full_scopes_company_role_scope_type` trên
`(company_id, user_company_role_id, scope_type) WHERE deleted_at IS NULL` — 56 byte, trong giới
hạn 63 byte mà C-DB-01 cảnh báo.

**Một bảng riêng chứ không phải một cột trên `user_company_role_scopes`**, vì hai bảng nói hai
sự thật khác hình dạng: "được cấp đúng bản ghi này" mang một `scope_id`, "không bị giới hạn"
thì không mang gì. Nhét cả hai vào một bảng buộc phải nới `scope_id` khỏi `NOT NULL` — xem
Alternatives. `user_company_role_scopes` vì vậy **không đổi một cột nào**, đúng như ADR-0023
mục 4 đã giữ được khi nó đổi bảng cha.

**3. Cấp và thu hồi toàn phạm vi đi qua `PUT /users/:id/scopes`, gác bằng
`<module>.scope_assign`.** Cùng endpoint, cùng transaction, cùng hai cửa đã có: `Can(actor,
auth.PermUserAssignScopes)` là câu lệnh đầu tiên (R-15), rồi với mỗi loại có mặt trong thân
request là `Can(actor, l.PermGan)` — `inventory.scope_assign` cho loại `warehouse`
(`scope_service.go:401-403`, ADR-0021 mục 4). Và cùng một dòng audit: `user_scope.updated`
(`scope_service.go:210`), mang tên đúng người bị chạm.

Đây là điểm của cả quyết định này: **mở rộng phạm vi dữ liệu từ nay đòi
`<module>.scope_assign`, không còn đòi `<module>.role_assign`.** Một người quản trị chỉ có
quyền gán vai trò không tự nới được tầm nhìn dữ liệu của ai.

**4. Thân request của `PUT /users/:id/scopes` mang thêm `toan_pham_vi` cho mỗi loại.** Đây là
một thay đổi **phá hợp đồng API**, phải ra cùng nhịp với frontend. Luật 422 hiện có giữ nguyên
nguyên văn: gửi `toan_pham_vi = true` kèm một danh sách id không rỗng là 422
(`scope_service.go:406-408`), vì hai vế đó nói hai điều loại trừ nhau.

Chiều **đọc** không đổi hình dạng: `GET /users/:id/scopes` vẫn trả `toan_pham_vi: boolean` cho
mỗi cặp (hàng vai trò, loại) (`user-api.ts:68`). Chỉ **nguồn** của giá trị ấy đổi — từ một câu
hỏi bảng phân quyền thành một câu đọc dữ liệu phạm vi — nên `vaiTroToanPhamVi` và cái
`auth.Actor` giả dựng tại chỗ ở `scope_service.go:200-206` biến mất.

**5. Thứ tự trong `Resolve` giữ nguyên, chỉ đổi vế thứ nhất.** Hỏi "hàng vai trò còn sống nào
của người này có toàn phạm vi loại này không" thay cho `Can(ctx, actor, permToanPham)`; có thì
lấy từ `Nguon`, không thì lấy từ `Doc`; rỗng ở cả hai đường đều cho ra `Pham` rỗng và **không**
đường nào ngả về "tất cả". Ba mệnh đề fail-close ghi ở `resolver.go:46-55` không đổi một chữ.

**6. Phạm vi vẫn hợp theo NGƯỜI.** Một hàng vai trò toàn phạm vi vẫn làm mọi hàng phạm vi khác
của cùng loại thành thừa — quyết định này **không** đổi điều đó và không định đổi. Nó đổi
**cách người ta rơi vào trạng thái ấy**: từ một hệ quả im lặng của việc tick một ô quyền, thành
một thao tác tường minh trên đúng màn phạm vi, gác bằng đúng permission phạm vi, ghi vào audit
với tên người bị chạm.

**7. Chuyển dữ liệu bằng một migration, tự kiểm trước `COMMIT`.** Cùng khuôn ADR-0021 mục 9 và
ADR-0023 mục 10 đã dùng, vì cùng lý do — một migration phân quyền hỏng nửa chừng là một hệ
không ai quản trị được:

1. Tạo `user_company_role_full_scopes`.
2. Với **mỗi** hàng `user_company_roles` còn sống mà vai trò của nó có một dòng
   `role_permissions` còn sống mang `permission_code = 'inventory.warehouse_scope_all'`: chèn
   một hàng full-scope với `scope_type = 'warehouse'`. Điều kiện đọc từ **dữ liệu**, không từ
   tên vai trò — cùng nguyên tắc ADR-0024 đã chốt, và nó cũng là thứ khiến migration đúng cho
   một công ty đã tự tick ô ấy vào một vai trò khác.
   `created_by`/`updated_by` lấy `user_company_roles.created_by` của chính hàng đó: hàng phạm vi
   này là hệ quả trực tiếp của lần gán ấy, không phải một hành động mới của ai.
3. **Xoá mềm** mọi dòng `role_permissions` mang mã đó. Không `DELETE FROM` — R-18 liệt nó là
   dấu hiệu vi phạm trong migration, và ADR này không có mục cấp phép xoá cứng cho bảng nào.

Ba hậu điều kiện, thiếu cái nào thì dừng và không commit một nửa:

- Số hàng full-scope sinh ra **bằng đúng** số hàng `user_company_roles` còn sống thoả điều kiện
  ở bước 2 — không nhiều hơn (một hàng vai trò chỉ được một hàng, partial unique canh), không
  ít hơn.
- Không còn dòng `role_permissions` **còn sống** nào mang mã đó. Thiếu vế này thì phép đối soát
  CI của ADR-0023 mục 7 đỏ ngay khi hằng bị bỏ khỏi code, vì đó đúng là ca "`permission_code`
  trong dữ liệu không khớp hằng nào".
- Tập `(user_id, company_id)` **thấy toàn bộ kho** tính theo đường cũ trước migration và tính
  theo đường mới sau migration phải **bằng nhau**. Đây là hậu điều kiện quan trọng nhất và nó
  là câu trả lời cho câu hỏi ai mất quyền — xem mục 9.

**8. Nửa giao diện là một phần của quyết định này, không phải việc làm sau.** Sửa xong backend
mà màn hình vẫn im lặng thì lỗ chỉ đổi chỗ:

- **Màn vai trò, chiều THÊM:** sau quyết định này việc tick thêm một vai trò **không mở rộng
  được phạm vi nữa**, nên câu cảnh báo cần viết là câu ngược lại. `user-api.ts` phải có một vị
  ngữ thứ hai đối xứng với `phamViMatKhiGo` — trả lời "thêm mã này thì người đó cần phạm vi loại
  nào mà chưa được cấp" — và `UserDetailPage.tsx` hiện nó cạnh `CanhBaoMatPhamVi`
  (`UserDetailPage.tsx:327`). Nó **không** chặn lưu: thiếu phạm vi là fail-close, không phải
  lỗi.
- **Màn phạm vi, ô toàn phạm vi:** dòng chữ chết ở `UserDetailPage.tsx:626-631` thành một ô
  điều khiển bật/tắt cho từng loại. Màn bày theo **loại**, đúng cách `gomTheoLoai` đang làm và
  đúng cách đường đọc hợp nhất; việc phân phối giá trị xuống các hàng vai trò theo đúng quy tắc
  tất định mà tập id đang dùng — về hàng vai trò còn sống **đầu tiên** theo thứ tự backend trả,
  các hàng còn lại nhận `false` (`UserDetailPage.tsx:574-585`).
- **Bật ô đó phải cảnh báo, và cảnh báo bằng con số:** nó nói ra rằng N kho đang cấp cho người
  này trở thành thừa, và rằng người này ghi được vào **mọi** kho kể cả kho mở sau này. Cùng
  hình dạng `role="alert"` mà `CanhBaoMatPhamVi` đang dùng, và nút lưu phải nói ra việc nó sắp
  làm, cùng khuôn `nhanNutLuu` (`UserDetailPage.tsx:341-345`).
- Ô ấy chỉ hiện khi actor có `inventory.scope_assign`, cùng cửa với phần còn lại của màn. Màn
  **không** được đọc tên vai trò để suy ra điều gì — C-TS-06.

**9. Không ai đang có toàn phạm vi bị mất nó.** Bước 2 của migration chuyển **mọi** hàng vai
trò còn sống đang mang mã quyền ấy, và hậu điều kiện thứ ba đo đúng tập người trước/sau. Chỗ
duy nhất có thể mất im lặng là một actor có toàn phạm vi mà **không** có hàng
`user_company_roles` nào để treo — tức vai trò dẫn xuất `quan_tri_he_thong`, thứ không bao giờ
nằm trong bảng gán (ADR-0023 mục 3). Chỗ đó **rỗng**: `vaitro.go` không cấp
`warehouse_scope_all` cho `quan_tri_he_thong`, và vai trò ấy không có permission vận hành nào
của `inventory` để mà thấy kho. Không có ca thứ hai.

**10. Quyết định này không đụng hình dạng bảng `role_permissions`.** Nó bỏ **một** mã quyền
khỏi danh mục và xoá mềm các dòng mang mã đó; nó không thêm cột, không đổi index, không quyết
đường đưa permission của một module mới vào vai trò của công ty đã tồn tại — đó là của
**ADR-0027**. Nếu ADR-0027 dựng một đường đồng bộ danh mục permission tổng quát thì bước 3 ở
trên là một ca của đường ấy, nhưng quyết định này không đợi nó.

Với **ADR-0025**: không đụng gì. Claim `roles` của token không đổi, `GET /auth/me` không đổi,
nhãn vai trò không đổi. Thứ duy nhất đổi là tập quyền của `inventory.admin` bớt một phần tử.

## Alternatives

**Để nguyên backend, chỉ thêm cảnh báo cho chiều thêm vai trò ở màn hình** — loại. ADR-0009 đã
chốt business rule chỉ ở backend, và một dòng chữ không phải một cửa: lỗ thật là
`inventory.role_assign` mở rộng được phạm vi dữ liệu mà `inventory.scope_assign` không được
hỏi tới, và không nhãn nào đóng được cửa đó. Nó cũng để nguyên ca tệ nhất, ca mà ADR-0024 vừa
mở ra: tick ô ấy vào `inventory.thu_kho` là mở toàn bộ kho cho **mọi** người đang giữ vai trò
đó cùng lúc, ở một màn không liệt kê ai bị chạm — cảnh báo trên màn chi tiết của **một** người
không bao giờ hiện ra trong luồng ấy.

**Giữ permission, nhưng giải phạm vi theo từng hàng vai trò rồi hợp lại** — loại vì nó không
đổi một kết quả nào. Trong đúng ca ở Context, hàng `inventory.thu_kho` cho ra `{kho A}` và hàng
`inventory.admin` cho ra toàn bộ kho; hợp hai tập vẫn là toàn bộ kho, vì ADR-0023 mục 6 đã chốt
hợp và quyết định này không lật nó. Đổi lại, `Resolve` phải đọc danh sách hàng vai trò và chạy
một vòng lặp cho mỗi request chạm tài nguyên chịu phạm vi. Trả tiền cho một vòng đọc để nhận
đúng câu trả lời cũ.

**Lấy GIAO thay vì hợp, hoặc "phạm vi hẹp nhất thắng"** — loại. Nó lật ADR-0023 mục 6 cho riêng
một loại dữ liệu, tức hệ có hai luật kết hợp cho hai thứ trông giống nhau và người đọc phải nhớ
thứ nào theo luật nào. Nó cũng đưa lại đúng nghịch lý mà ADR đó nêu làm lý do chọn hợp: gán
thêm một vai trò lại **lấy đi** tầm nhìn. Và nó làm cách duy nhất để nới phạm vi cho một người
là đi **xoá** những hàng phạm vi cũ của họ — một thao tác trông như thu hồi mà tác dụng là mở,
đúng loại thao tác không ai đọc ra được kết quả bằng mắt.

**Bỏ hẳn khái niệm toàn phạm vi, ai cũng phải được liệt kê tường minh** — loại. Kho mở sau
không tự vào danh sách của ai, nên người vừa tạo một kho không đọc lại được cái kho mình vừa
tạo — đúng ca ADR-0020 đã ghi ở mục Consequences ("tạo được rồi không đọc lại được") và đúng lý
do ADR-0021 mục 2 nêu khi giữ `warehouse_scope_all` trong `inventory.admin`. Nó còn biến "mở
một kho" thành hai thao tác ở hai màn, lặp lại cho **mỗi** người đang có toàn phạm vi, và số
lần lặp đó lớn dần theo số nhân sự chứ không theo số kho.

**Một cột `is_all BOOLEAN` trên `user_company_roles`** — loại, và lý do loại lần này khác lý do
ADR-0020 đã dùng. Một cờ trên hàng vai trò là **một cờ cho mọi loại phạm vi**. Ngày có
`scope_type` thứ hai — ADR-0020 đã dự liệu `project`, `cost_center` — mọi hàng đang bật cờ được
cấp luôn toàn bộ loại mới ấy, không ai quyết, không request nào đi qua, và với dữ liệu đã có
sẵn từ trước. Hỏng về phía mở, im lặng, và ở đúng thời điểm không ai đang nhìn.

**Một dòng `scope_id NULL` trong chính `user_company_role_scopes` nghĩa là tất cả** — loại vì
nó phải nới `scope_id` khỏi `NOT NULL`, và partial unique index hiện có
(`uq_user_company_role_scopes_company_role_scope_type_scope`) **không chặn được hai dòng NULL**:
trong unique index của PostgreSQL, NULL không bằng NULL. Tức "toàn phạm vi" ghi được hai lần cho
cùng một cặp và không gì báo. Vá bằng một partial unique thứ hai thì bảng có hai bất biến cho
hai hình dạng hàng khác nhau — đúng dấu hiệu của hai bảng đang bị ép làm một.

**Không làm gì và ghi lỗ vào Nợ để lại một lần nữa** — loại. ADR-0021 đã ghi nợ
"`<module>.admin` tự nhân bản được" và nó nằm đó tới khi ADR-0024 đóng; lỗ này đã được ghi một
lần ở ADR-0024 mục "Chưa đóng", và trong khoảng giữa hai lần ghi thì chính ADR-0024 đã làm nó
rẻ hơn để chạm. Một lỗ mà mỗi quyết định đi qua lại làm nó dễ chạm hơn thì lần hoãn sau tốn hơn
lần hoãn trước.

## Consequences

**Được:**

- Mở rộng phạm vi dữ liệu của một người đòi `<module>.scope_assign`. Lỗ mà ADR-0024 ghi ở mục
  "Chưa đóng, và cố ý không đóng ở đây" đóng lại, và nó đóng ở đúng permission mà ADR-0021 mục
  4 đã dựng cho việc này.
- Một lần mở rộng chạm **đúng một người** và để lại một dòng `audit_logs` mang tên người đó
  (`user_scope.updated`). Hôm nay nó là một dòng audit về một **vai trò**, không nêu ai bị
  chạm, và số người bị chạm bằng số người đang giữ vai trò ấy.
- Phạm vi của một hàng vai trò có một nguồn sự thật. Câu "kho A vẫn còn nguyên trong database
  nhưng không còn nghĩa gì" không phát biểu được nữa: hoặc hàng full-scope có mặt và ai cũng
  đọc thấy nó ở đúng chỗ đọc phạm vi, hoặc không.
- Cái `auth.Actor` giả dựng tại chỗ để hỏi ngược bảng phân quyền biến mất. Báo cáo phạm vi đọc
  từ dữ liệu phạm vi.
- Loại phạm vi thứ hai không đẻ thêm một permission nào. Hôm nay mỗi loại mới cần một mã
  `<module>.<tài_nguyên>_scope_all` phải vào `permissions.go`, vào danh mục hằng, vào bộ nạp mặc
  định, **và** vào `role_permissions` của mọi công ty đã tồn tại — đúng vấn đề ADR-0027 đang mở.
  Sau quyết định này một loại mới là một dòng trong `phamvi.Bang()` cộng những hàng dữ liệu
  mang `scope_type` mới.
- `scope.Resolve` bớt một tham số, và không người gọi nào còn phải cầm theo một chuỗi permission
  để chốt phạm vi.

**Mất:**

- **Gán `inventory.admin` cho một người từ nay KHÔNG kèm toàn phạm vi kho.** Ai gán phải sang
  màn phạm vi bật thêm. Đây là thu hẹp hành vi có thật, cảm nhận được ngay ngày triển khai, và
  phải nằm trong ghi chú phát hành chứ không để người dùng tự phát hiện — cùng loại giá mà
  ADR-0024 mục 4 đã trả.
- Một vế đọc nữa trên đường nóng. `authz.Can` là một phép tra bộ nhớ có cache (ADR-0023 mục 8);
  thứ thay nó chạm database ở **mọi** request chạm tài nguyên chịu phạm vi. Nó gộp được vào cùng
  một vòng tới database với câu đọc phạm vi đang có, nhưng con số thật chưa ai đo — cùng khoản
  nợ đo đạc mà ADR-0020 đã ghi và chưa trả.
- Bảng thứ tư trong nhóm bảng gán, và một khái niệm nữa mà người quản trị phải hiểu: từ nay
  "vai trò" không nói gì về phạm vi, muốn biết ai thấy mọi kho phải đọc màn phạm vi của từng
  người. Bù lại một câu hỏi cũ mất đi: không còn ai phải đối chiếu hai chỗ.
- `PUT /users/:id/scopes` đổi hình dạng thân request. Phá hợp đồng API, phải ra cùng nhịp với
  frontend; chiều đọc thì không đổi.
- Migration chạm `role_permissions`, tức chạm dữ liệu mà từ ADR-0023 tenant sửa được. Công ty
  nào đã tự tick mã đó vào một vai trò khác sẽ được chuyển theo cùng một luật đọc từ dữ liệu, và
  không có cách nào hỏi ý họ. Tại thời điểm quyết chưa công ty nào làm được việc đó vì đường ghi
  vai trò chưa mở, nên cửa sổ này hẹp — nhưng nó hẹp vì **thời điểm**, không vì thiết kế.

**Nợ để lại:**

- **Điều kiện, không phải khuyến nghị:** `cmd/dev bootstrap-user` phải cấp kèm toàn phạm vi cho
  mọi loại trên hàng vai trò nó tạo. Nó là đường vào duy nhất của một hệ chưa có user nào, và
  không có ai khác để cấp phạm vi cho người đầu tiên. Thiếu bước này thì một cài đặt mới đăng
  nhập được, mang `inventory.admin`, và thấy màn kho trống — đúng ca ADR-0020 mục 3 chấp nhận
  có ý thức, nhưng ở chỗ không ai chữa được vì chưa có người thứ hai.
- Nửa giao diện ở mục 8 phải ra **cùng đợt** với backend. Sửa xong backend mà màn phạm vi vẫn
  hiện dòng chữ chết ở `UserDetailPage.tsx:626-631` là một màn mô tả một trạng thái mà nó không
  bật/tắt được, và ô chọn của loại đó vẫn biến mất như hôm nay.
- Chưa quyết cách bày "toàn phạm vi" trong màn tra cứu audit: một dòng `user_scope.updated` từ
  nay có hai loại nội dung, và chúng phải đọc ra khác nhau.
- **Điều kiện để quyết định này đứng vững:** phạm vi tiếp tục hợp nhất theo **người** ở đường
  đọc (ADR-0020 mục 1b). Ngày nào câu đọc lọc theo `role_code` — tức phạm vi thành một ngăn
  chứa riêng của từng hàng vai trò thật — thì "toàn phạm vi treo theo hàng" mang một nghĩa khác
  hẳn và phải được cân lại bằng một ADR mới.
- Ranh giới với ADR-0027 ở mục 10 là một **ranh giới**, không phải một sự chờ đợi: nếu ADR-0027
  ra trước và dựng đường đồng bộ danh mục permission, migration ở mục 7 vẫn giữ nguyên ba bước
  của nó.

**Constrains:** —

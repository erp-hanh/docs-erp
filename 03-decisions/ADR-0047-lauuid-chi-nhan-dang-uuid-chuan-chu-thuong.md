# ADR-0047: `laUUID` chỉ nhận một hình dạng định danh - 36 ký tự theo khuôn chuẩn, viết chữ thường

**Status:** Accepted (2026-08-29)

## Context

Đợt "Ngừng sử dụng phân vùng" ngày 2026-08-29 sinh ra bảy lỗi được ghi lại, và **ba trong số đó
là cùng một lỗ hổng bảo mật lặp lại ở ba cửa khác nhau**: xoá phân vùng, ngừng sử dụng phân vùng,
và tự gỡ mình khỏi phân vùng. Cửa xoá không đảo lại được.

Khuôn của cả ba giống hệt nhau. Cửa chặn so hai định danh bằng phép so **chuỗi Go** nên nó
trượt; câu SQL ngay sau đó truyền cùng chuỗi ấy vào `WHERE id = $n`, Postgres parse tham số sang
kiểu `uuid` rồi mới so, nên nó **vẫn khớp đúng hàng**. Cửa nói "không phải phân vùng của bạn",
câu ghi ngay dưới nó chạm đúng hàng cần chặn.

**Gốc của khuôn ấy là `laUUID`.** Hàm này - phép kiểm định dạng duy nhất mà một định danh lấy từ
`:id` phải đi qua - hôm nay là:

```go
func laUUID(s string) bool {
	return uuid.Validate(s) == nil
}
```

`uuid.Validate` của `github.com/google/uuid` v1.6.0 nhận **bốn** hình dạng cho cùng một mã, và
không phân biệt HOA với thường ở cả bốn:

| Hình dạng | Độ dài | `uuid.Validate` | Postgres kiểu `uuid` |
|---|---|---|---|
| `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | 36 | nhận | nhận |
| `urn:uuid:xxxxxxxx-...` | 45 | nhận | **không** |
| `{xxxxxxxx-...}` | 38 | nhận | nhận |
| 32 hex không gạch ngang | 32 | nhận | nhận |

Chênh lệch ở cột thứ ba đẻ ra hai loại hỏng khác nhau. Ba hàng cuối cho Postgres một mã hợp lệ mà
Go coi là một **chuỗi khác**, và mọi cửa so chuỗi đều trượt trên chúng - đó là ba lỗ vừa nêu.
Riêng hàng `urn:uuid:` đi lọt `laUUID` rồi bị Postgres từ chối bằng lỗi `22P02`, đúng thứ mà khối
bình luận trên `laUUID` nói hàm ấy sinh ra để chặn: một lỗi kỹ thuật rơi vào nhánh mặc định và ra
client dưới dạng `ERR_INTERNAL` 500, trong khi sự thật chỉ là không có bản ghi nào mang định danh
đó.

**Hai vòng vá, mỗi vòng đóng đúng một trục rồi dừng.** Vòng một chữa biến thể HOA/thường bằng
`strings.EqualFold`. Vòng hai - sau khi một bản soi độc lập chạy thật và chứng minh `{uuid}` cùng
32-hex **vẫn lọt** - chữa bằng `uuid.Parse` cả hai vế trong `laCungPhanVung`. Hai hình dạng ấy
lệch nhau ở **độ dài** chứ không ở hoa/thường, nên vòng một không thể bắt được chúng.

Cái giá của khuôn ấy đã được trả hai lần trong một ngày, và
[ADR-0045](ADR-0045-cua-phan-vung-dang-lam-viec-canh-ca-hai-duong.md) là chỗ nó lộ ra rõ nhất:
phần Alternatives của ADR ấy loại phương án "parse cả hai vế" với lý do `EqualFold` cho cùng kết
quả trên **mọi** đầu vào hex. Lý do ấy sai, và nó bị chứng minh sai bằng chạy thật ngay trong
cùng đợt. Bản vá đi theo đúng mục **Decision** của ADR-0045 nên không cần một ADR đính chính;
ADR-0045 giữ nguyên hiệu lực và không bị thay thế.

`laCungPhanVung` trong `modules/auth/internal/service/company_service.go` hôm nay đã đúng:

```go
func laCungPhanVung(a, b string) bool {
	ua, err := uuid.Parse(a)
	if err != nil {
		return false
	}
	ub, err := uuid.Parse(b)
	if err != nil {
		return false
	}
	return ua == ub
}
```

**Nhưng nó chỉ vá ba cửa đã biết.** Mọi endpoint nhận `:id` vẫn chấp nhận cả bốn hình dạng, và
mỗi cửa mới trong tương lai lại phải tự nhớ. Phần "Nợ để lại" của ADR-0045 ghi đúng việc này là
chưa quyết và cần một ADR riêng. Đây là ADR đó.

### Hệ đang đứng ở đâu, đo được

Trước khi quyết, một đợt rà đã chạy trên `backend-erp` và `frontend-erp`. Các dữ kiện dưới đây là
thứ quyết định này dựa vào:

- **Backend chỉ sinh ra dạng chuẩn chữ thường.** Mọi bảng khai
  `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`; DTO trả id là `string` trần không format; chỗ
  sinh định danh ở Go dùng `uuid.NewString()` và không có một lời gọi `uuid.New()` nào. Nên đường
  "đọc id từ API rồi gửi lại" - đường phổ biến nhất và gần như là đường duy nhất trên giao diện -
  **không đổi hành vi một ly** sau khi thắt.
- **Frontend cũng chỉ sinh ra dạng chuẩn chữ thường.** Chỗ duy nhất tự sinh định danh là
  `sinhKhoa()` trong `src/shared/api/sinh-khoa.ts`, dùng cho header `Idempotency-Key`. Đường dự
  phòng `uuidV4TuGetRandomValues()` - đường thật sự chạy trên máy dev, vì dev là HTTP thuần nên
  `crypto.randomUUID` là `undefined` - ghép chuỗi bằng `toString(16)`, mà hàm ấy luôn trả hex chữ
  thường, rồi chèn gạch ngang theo khuôn 8-4-4-4-12.
- **Ba trường DTO đã dùng `binding:"uuid"`** của `go-playground/validator`, mà regex của tag ấy
  đúng bằng hình dạng sắp thắt: `DatNguoiQuanTriRequest.UserID` trong `company_handler.go`,
  `ThayPhamViVaiTroRequest.UserCompanyRoleID` và `ThayPhamViLoaiRequest.IDs` trong
  `user_scope_handler.go`. Ba trường ấy nằm trên hai endpoint đang chạy tốt, tức **không client
  nào gửi hình dạng lệch qua chúng**. Đây là bằng chứng mạnh nhất rằng việc thắt an toàn: hai
  endpoint đã sống với đúng luật này rồi.
- **Ba kênh còn mở**, cả ba đều là "người dùng dán tay một định danh lấy từ công cụ ngoài": ô
  nhập tự do "Người phụ trách" (`assigned_to`) của `MachineEditForm` trên màn `MachineDetailPage`;
  ba bộ lọc đọc thẳng từ URL (`parseMovementListParams`, `parseBalanceListParams`,
  `parseStockItemListParams`) mà thân hàm đọc id đúng một dòng `return raw ?? ''`; và route param,
  nơi `matchSegments` trong `src/app/routes.tsx` chỉ `decodeURIComponent` chứ không kiểm dạng.
  Không chỗ nào trên frontend lowercase, cắt dấu ngoặc, hay `trim` một định danh trước khi gửi.
- **Có BA bản `laUUID`**, thân hàm giống hệt nhau, ở
  `modules/auth/internal/service/user_service.go`, `modules/inventory/internal/service/errors.go`
  và `modules/machine/internal/service/errors.go`. Không luật kiến trúc nào canh chúng: `arch/`
  không có một dòng nào nhắc tên hàm này. Thắt một bản không đóng hai bản kia.
- **Không có phép kiểm định dạng nào ở tầng HTTP.** Mọi handler truyền thẳng `c.Param("id")`
  xuống service; phép kiểm duy nhất là `laUUID` bên trong từng method service, đặt ngay sau lời
  kiểm quyền theo R-15, trả 404. Ở `inventory`, các bộ lọc query đi qua `chuanHoaLocChuyenDong`
  và `chuanHoaLocDonVi` - hai hàm này cũng gọi `laUUID`, và chúng trả 422.

Điều **chưa biết** lúc quyết: có người dùng thật nào đang dán định danh bằng tay qua ba kênh trên
hay không. Không có log nào trả lời được câu ấy, và không ai từng báo một quy trình làm việc như
vậy.

## Decision

**`laUUID` chỉ trả `true` cho đúng một hình dạng định danh - 36 ký tự theo khuôn
`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`, mọi chữ cái hex viết thường - và từ chối ba hình dạng còn
lại mà `uuid.Validate` cho qua.**

- **Nhận:** đúng 36 ký tự, gạch ngang ở vị trí thứ 9, 14, 19 và 24, 32 ký tự còn lại nằm trong
  `[0-9a-f]`. **Từ chối:** `urn:uuid:...` (45 ký tự), `{...}` (38 ký tự), 32 hex không gạch ngang,
  và mọi biến thể có ít nhất một chữ cái hex viết HOA. Từ chối nghĩa là `laUUID` trả `false`, và
  mã lỗi ra client vẫn đúng như hôm nay: 404 ở đường theo `:id`, 422 ở các bộ lọc của `inventory`
  đi qua `chuanHoaLocChuyenDong` và `chuanHoaLocDonVi`.

- **Áp cho cả BA bản `laUUID`**, không riêng bản `auth`:
  `modules/auth/internal/service/user_service.go`, `modules/inventory/internal/service/errors.go`,
  `modules/machine/internal/service/errors.go`. Ba bản này phải khớp nhau. Thắt một bản mà để hai
  bản kia rộng là dựng lại đúng khuôn lỗi của đợt này ở quy mô module: một mệnh đề đúng ở chỗ
  người ta nhìn, sai ở chỗ người ta quên nhìn.

- **`laCungPhanVung` giữ nguyên `uuid.Parse` cả hai vế, làm lớp phòng thủ thứ hai.** Không bỏ lớp
  nào. Lý do không phải cẩn thận thừa mà là hai lớp canh **hai vế khác nhau**: `laUUID` canh vế
  đến từ request, còn vế thứ hai của `laCungPhanVung` đến từ token (`actor.CompanyID`,
  `actor.UserID`) và **không bao giờ đi qua `laUUID`**. Bỏ lớp `Parse` thì cửa chỉ đúng chừng nào
  mọi chỗ gọi nhớ gọi `laUUID` trước, đúng thứ tự, trên đúng tham số - và `laCungPhanVung` hôm
  nay đã có **ba** chỗ gọi (`CompanyService.DeleteCompany`, `CompanyService.DatTrangThaiSuDung`,
  `UserService.GoKhoiPhanVung`), tức ranh giới ấy đã phải nhớ ở ba nơi. Ngược lại, bỏ lớp `laUUID`
  để chỉ dựa vào `Parse` cũng không được: `uuid.Parse` **rộng hơn cả `uuid.Validate`** ở hình dạng
  ngoặc nhọn - với chuỗi dài 38 nó cắt `s = s[1:]` rồi không bao giờ đọc ký tự cuối, nên `{` cộng
  36 ký tự chuẩn cộng một ký tự bất kỳ đều parse trót lọt. Một hàm dùng để **so** thì được phép
  rộng; một hàm dùng để **gác cửa** thì không. ADR-0045 mục 2 đã chốt rằng phép so đúng thuộc về
  chính cửa chứ không thuộc về đường đi tới nó; quyết định này không đụng vào mệnh đề đó, nó chỉ
  thắt đường đi.

- **Không áp cho:** ba tag `binding:"uuid"` đang có (chúng đã đúng, giữ nguyên); định danh do
  backend tự sinh (`gen_random_uuid()`, `uuid.NewString()`); các chuỗi không phải định danh
  (`code`, `email`, `Idempotency-Key`); và cách Postgres parse kiểu `uuid` - quyết định này thắt
  phía Go, không đổi một dòng SQL nào.

## Alternatives

**Giữ nguyên `uuid.Validate`, vá từng cửa khi phát hiện** - loại, và lý do là số liệu của chính
đợt này chứ không phải một nguyên tắc. Cùng một khuôn lỗi lọt qua **hai vòng soi và hai lần vá**
trong một ngày: vòng một vá cửa xoá và cửa ngừng sử dụng bằng `EqualFold` rồi dừng, và người vá
tin rằng đã xong - ADR-0045 phần Alternatives ghi lại niềm tin ấy thành chữ, rằng `EqualFold` cho
cùng kết quả trên mọi đầu vào hex. Một đợt rà chủ động sau đó tìm ra cửa thứ ba
(`UserService.GoKhoiPhanVung`) ở một hàm chẳng liên quan gì tới đợt việc, rồi một bản soi độc lập
chạy thật mới chứng minh hai hình dạng còn lại vẫn lọt cả ba cửa. Ba lần liên tiếp, thứ chặn được
lỗi là một người đi rà lại, không phải một bộ kiểm. Vá từng cửa nghĩa là đặt cược rằng lần sau
vẫn có người rà - trong khi bộ kiểm kiến trúc đã xanh trọn vẹn trên cây có đủ ba lỗi, và 900 dòng
test của đợt cũng không bắt được cái nào.

**Chuẩn hoá thay vì từ chối** - nhận cả bốn hình dạng rồi đưa về dạng chuẩn chữ thường trước khi
dùng. Đây là phương án đáng cân nhất, và nó có hai điểm mạnh thật. Thứ nhất, nó **không làm gãy
ba kênh dán tay** - ô "Người phụ trách", ba bộ lọc URL, route param - nên không màn nào đổi hành
vi với người dùng. Thứ hai, nó xoá **toàn bộ** chênh lệch ở bảng trên chứ không chỉ ba hàng: kể
cả `urn:uuid:`, thứ hôm nay đi lọt `laUUID` rồi nổ thành `ERR_INTERNAL` 500, cũng thành một định
danh chạy được. Từ chối chỉ đổi 500 thành 404; chuẩn hoá làm nó chạy đúng.

Loại, vì **chuẩn hoá phải xảy ra ở mọi chỗ nhận định danh, còn từ chối chỉ cần ở một cửa** - và
"mọi chỗ" ở đây là một con số đo được, không phải một lo xa. Hôm nay `laUUID` đã là điểm thắt cổ
chai có sẵn: mọi handler truyền thẳng `c.Param("id")` xuống, và mỗi method service nhận id gọi
`laUUID` ngay sau lời kiểm quyền. Thắt hàm ấy là sửa **ba thân hàm**, và mọi chỗ gọi hưởng ngay.
Chuẩn hoá thì không dùng lại được điểm thắt ấy: `laUUID` trả `bool`, nên nó không trả về được
chuỗi đã chuẩn hoá; muốn giá trị chuẩn hoá tới được `WHERE id = $n` thì phải đổi chữ ký hàm **và**
sửa từng chỗ gọi để dùng giá trị trả về thay cho biến gốc. Bỏ sót một chỗ gọi thì chỗ đó im lặng
giữ nguyên hành vi cũ - và im lặng giữ nguyên hành vi cũ chính là hình dạng của cả ba lỗ hổng
đang bàn.

Còn hai cái giá nữa, cả hai đều kiểm chứng được. Một: đặt phép chuẩn hoá ở tầng handler đã bị
ADR-0045 phần Alternatives loại rồi, với lý do vẫn đúng nguyên - service được gọi từ chỗ khác
(test, một handler thứ hai, một job) sẽ nhận định danh chưa qua chuẩn hoá và cửa lại trượt, lần
này không còn dấu vết nào ở service để đọc ra. Hai: chuẩn hoá làm hai chuỗi khác nhau cùng trỏ
một bản ghi, nên nhật ký kiểm toán và thông điệp lỗi phải chọn ghi chuỗi nào - chuỗi người dùng
gửi hay chuỗi hệ dùng - và mọi phép so định danh trong hệ lại phải hỏi "vế này đã chuẩn hoá
chưa". Từ chối không sinh câu hỏi đó: sau khi thắt, một định danh đã qua `laUUID` **là** dạng
chuẩn, nên phép so chuỗi trần trở lại đúng, và cái đúng ấy không phụ thuộc vào ai nhớ gì.

Cái mất khi loại phương án này là thật và không nhỏ: ba kênh dán tay gãy. Nó được ghi ở mục Mất
chứ không giấu vào đây.

**Dùng `binding:"uuid"` ở tầng handler thay vì thắt `laUUID`** - loại, vì tag ấy không với tới
được thứ cần canh. `binding` của `go-playground/validator` chạy qua `ShouldBindJSON` /
`ShouldBindQuery` trên một struct, nên nó canh được **trường DTO** - đúng ba trường đang dùng nó
hôm nay - nhưng không canh được `c.Param("id")`, và `c.Param("id")` là đường mà cả ba lỗ hổng của
đợt này đi qua. Muốn phủ nó thì phải dựng thêm một struct hoặc một lời gọi validate cho **từng**
handler nhận `:id`, tức đổi từ ba thân hàm sang mấy chục chỗ phải nhớ - đúng bài toán "phải nhớ ở
nhiều nơi" mà phương án chuẩn hoá vừa bị loại vì nó. Thêm nữa, hai lớp trả **hai mã lỗi khác
nhau**: `binding` hỏng trả 422, còn `laUUID` cố ý trả 404 vì một định danh sai định dạng thì chắc
chắn không tồn tại, nên nó cho ra đúng câu trả lời với "không có bản ghi" và "bản ghi của công ty
khác", và vì vậy không lộ thêm điều gì (C-API-02). Dời phép kiểm lên handler là đổi 404 thành 422
trên mọi route `:id` - một thay đổi hành vi rộng hơn hẳn thứ đang quyết, và nó xoá một tính chất
về lộ thông tin mà khối bình luận trên `laUUID` đã ghi rõ lý do.

**Gộp ba bản `laUUID` thành một hàm dùng chung ở `shared/`** - loại ở phạm vi ADR này, không loại
vĩnh viễn. Nó chữa đúng một nửa vấn đề: thân hàm hết trôi, nhưng thứ thật sự phải nhớ là **chỗ
gọi** - mỗi method service nhận id phải tự gọi nó, và gộp một hàm không thêm được một chỗ gọi
nào. Đổi lại, nó dựng một symbol xuất khẩu mới ở `shared/` mà cả ba module cùng phụ thuộc, tức
một thay đổi ranh giới module nằm ngoài phạm vi một quyết định về định dạng đầu vào. Thắt ba thân
hàm giống hệt nhau là ba lần sửa và kiểm lại được bằng một lệnh grep; gộp chúng là một đợt tái
cấu trúc riêng, và nó nên đi cùng phương án dưới đây chứ không đi một mình.

**Dựng một luật kiến trúc canh ba bản `laUUID` không lệch nhau** - đây là phương án **bổ sung**
chứ không thay thế: nó không thắt được bản nào, nó chỉ canh cho ba bản đã thắt khỏi trôi ra xa
nhau. Không đưa vào Decision của ADR này vì hai việc có hai điều kiện nghiệm thu khác nhau - thắt
`laUUID` nghiệm thu bằng test hành vi, còn một checker nghiệm thu bằng chính bộ kiểm kiến trúc -
và vì [ADR-0046](ADR-0046-truc-loc-is-active-la-loi-vao-so-voi-quet-du.md) đã ghi nợ **hai** danh
sách trắng cùng hình dạng chưa dựng (các ngoại lệ R-06 mà ADR-0040, ADR-0041 và ADR-0044 ghi nợ,
và bốn chỗ đọc `companies`), nên dựng bộ kiểm thứ ba riêng lẻ là chép cùng một cơ chế lần thứ ba.
Việc này nằm ở mục Nợ để lại, kèm điều kiện của nó.

## Consequences

**Được:**

- Cả lớp khe đóng một lần ở gốc, thay vì từng cửa một. Sau khi thắt, một định danh đã qua
  `laUUID` **là** dạng chuẩn chữ thường, nên phép so chuỗi trần ở mọi cửa phía sau trở lại đúng -
  kể cả cửa do người viết sau này dựng lên mà không đọc ADR-0045.
- Ba lỗ hổng của đợt này mất luôn đường vào, không phải nhờ ba bản vá riêng mà nhờ đầu vào không
  còn tới được. Cửa xoá phân vùng - thao tác duy nhất không đảo lại được trong đợt - được canh
  bởi hai lớp độc lập.
- Hình dạng `urn:uuid:` thôi sinh `ERR_INTERNAL` 500. Hôm nay nó đi lọt `laUUID` rồi để Postgres
  ném `22P02` ra nhánh mặc định; sau khi thắt nó nhận 404, đúng thứ khối bình luận trên `laUUID`
  nói hàm ấy sinh ra để làm.
- Hệ chỉ còn **một** khái niệm "định danh hợp lệ", và nó trùng đúng thứ hệ tự sinh ra
  (`gen_random_uuid()`, `uuid.NewString()`, `sinhKhoa()`) và trùng đúng regex của
  `binding:"uuid"` đang chạy trên hai endpoint. Bốn nguồn, một hình dạng.

**Mất:**

- **Ba kênh dán tay gãy, và cả ba đều gãy im lặng với người đang dán.** Ô "Người phụ trách"
  (`assigned_to`) của `MachineEditForm` trên màn `MachineDetailPage` không `trim`, không
  lowercase - một lần dán kèm dấu ngoặc nhọn hoặc một id chữ HOA từ công cụ ngoài nay bị từ chối
  thay vì chạy. Ba bộ lọc `parseMovementListParams`, `parseBalanceListParams`,
  `parseStockItemListParams` đọc thẳng `warehouse_id` / `stock_item_id` / `unit_id` từ URL và gửi
  nguyên văn; một URL chép tay hay một bookmark cũ mang hình dạng khác nay ăn 422. Route param
  của các trang chi tiết nay ăn 404. Không màn nào trong ba nhóm này có thông điệp riêng cho ca
  "đúng bản ghi nhưng sai hình dạng", nên người dùng đọc được "không tìm thấy" chứ không đọc được
  "sửa lại dạng id".
- **Sáu hàm test phải sửa, và chúng là test hồi quy của chính ba lỗ vừa vá.**
  `TestCompanyService_DeleteCompany_PhanVungDangLamViec_IdChuHoa_Tra409`,
  `TestCompanyService_DatTrangThaiSuDung_PhanVungDangDung_IdChuHoa_Tra409`,
  `TestCompanyService_DeleteCompany_PhanVungDangLamViec_HinhDangKhac_Tra409`,
  `TestCompanyService_DatTrangThaiSuDung_PhanVungDangDung_HinhDangKhac_Tra409` trong
  `company_service_test.go`, và `TestGoKhoiPhanVung_ChinhMinhIdChuHoaTra422`,
  `TestGoKhoiPhanVung_ChinhMinhHinhDangKhacTra422` trong `user_service_kiem_nhiem_test.go` - tổng
  chín ca tính cả subtest. Cả sáu khẳng định "chuỗi hình dạng lạ đi qua `laUUID` rồi bị cửa khác
  chặn bằng 409/422"; sau khi thắt, `laUUID` chặn trước và câu trả lời là 404. Sửa chúng nghĩa là
  **bỏ đi bằng chứng chạy được** rằng cửa `laCungPhanVung` tự nó chặn đúng - lớp phòng thủ thứ
  hai vẫn còn trong code nhưng không còn bài nào chứng minh nó làm việc, trừ khi ai đó viết bài
  gọi thẳng `laCungPhanVung` với đầu vào chưa qua `laUUID`.
- **Một cái bẫy nằm trong chính bộ test.** Helper `hinhDangDoDuoc` ở `company_service_test.go` -
  lưới an toàn dựng lên để bài không xanh nhờ nhầm cửa - gọi `uuid.Validate` chứ không gọi
  `laUUID`. Khi hai thứ đó tách nhau, lưới **vẫn xanh** trong khi bài đỏ, và thông điệp `t.Fatalf`
  của nó sẽ chỉ sai chỗ hỏng. Ai sửa sáu bài trên phải sửa helper này trước, nếu không sẽ đi tìm
  lỗi ở đúng nơi không có lỗi.
- **Ba bản `laUUID` phải giữ khớp nhau và không có checker.** `arch/` không có một dòng nào nhắc
  tên hàm này, nên ba bản lệch nhau là một PR xanh. Hậu quả của việc lệch không đối xứng: bản
  rộng hơn là bản mở lại khe, và module nào rộng hơn thì không có gì trên màn hình nói ra.
- **Quyết định này đổi hành vi của mọi endpoint nhận `:id`, ở cả ba module, chứ không riêng
  `auth`.** Phạm vi thật rộng hơn hẳn đợt việc sinh ra nó: ba lỗ hổng nằm trong `auth`, còn thứ
  thắt lại chạm `inventory` và `machine` y hệt. Ở `inventory` nó còn chạm hai đường không phải
  `:id` - `chuanHoaLocChuyenDong` và `chuanHoaLocDonVi` gọi `laUUID` cho bộ lọc query và trả 422.

**Nợ để lại:**

- **Điều kiện**, không phải khuyến nghị: ba bản `laUUID` phải có cùng một thân hàm. Quyết định
  này chỉ đứng vững khi ranh giới đó được giữ, và hôm nay nó không có checker - chỉ có một lệnh
  grep mà không ai bị bắt phải chạy. Cho tới khi có checker, mọi PR thêm một module mới có hàm
  cùng tên phải chép đúng thân hàm ấy.
- Chưa dựng: một luật kiến trúc canh ba bản khớp nhau, và phương án gộp chúng thành một hàm dùng
  chung ở `shared/`. Hai việc này đi cùng nhau - gộp trước thì luật canh còn rất ít việc để làm.
  Điều kiện để làm: nó nên đi chung đợt với hai danh sách trắng mà ADR-0046 đang ghi nợ, vì cả ba
  là cùng một cơ chế.
- **Chưa rà: có người dùng thật nào đang dán định danh bằng tay qua ba kênh trên không.** Không
  có log trả lời được, và quyết định này đặt cược rằng câu trả lời là không. Nếu sau khi thắt có
  người báo một quy trình gãy, thứ phải xem lại là phương án chuẩn hoá **cho đúng kênh đó** -
  chuẩn hoá tại một ô nhập cụ thể, ở frontend, trước khi gửi - chứ không phải nới `laUUID` ra lại.
- Chưa có bài nào đi qua tầng HTTP cho khe này. ADR-0045 đã ghi món nợ ấy và quyết định này không
  trả nó: sáu bài hiện có gọi thẳng service, nên sau khi thắt chúng vẫn không nói gì về việc
  handler làm gì với một `:id` sai hình dạng.
- Chưa quyết: thông điệp lỗi cho ca "sai hình dạng định danh". Hôm nay nó lẫn vào 404 "không tìm
  thấy" và 422 chung, và ba kênh dán tay gãy sẽ đọc ra đúng thông điệp ấy. Tách một mã riêng thì
  dễ dùng hơn nhưng lộ ra rằng định danh đó sai dạng chứ không phải không tồn tại - đúng thứ
  `laUUID` cố ý không lộ.

**Constrains:** —

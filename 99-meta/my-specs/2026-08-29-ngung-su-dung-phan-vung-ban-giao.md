# Bàn giao: "Ngừng sử dụng" phân vùng, tách khỏi xoá

Ngày 2026-08-29. Việc số 1 trong ba việc còn nợ của
[bàn giao 2026-08-28](2026-08-28-quan-tri-phan-vung-ban-giao.md).

**Đã vào `main` và đang chạy trên dev.** Cập nhật 2026-09-01.

| Repo | Đã vào `main` | Tag |
|---|---|---|
| `backend-erp` | `7083dca` rồi `397565e` | `v0.1.0-rc.106`, `v0.1.0-rc.107` |
| `frontend-erp` | `f4f3906` | `v0.1.0-rc.106`, `v0.1.0-rc.107` |
| `docs-erp` | nhánh `spec/ngung-su-dung-phan-vung`, **chưa merge** | — |

Nhánh mang đợt việc chính đã cũ ba ngày so với `main` trước khi merge (backend 24 commit,
frontend 43). Hợp nhất bằng `git merge`, không rebase — nhánh đã công bố. Backend có bốn
file cả hai bên cùng sửa, và cả bốn là ca "hai bên thêm hai thứ khác nhau vào cùng một danh
sách" nên **giữ cả hai**; frontend chỉ một file golden. Không bài test nào phải sửa vì mâu
thuẫn hành vi.

**Bài học vận hành, đắt hơn nó đáng:** lần deploy đầu chọn deploy **nhánh** thay vì tag rc.
Máy dev được nhiều phiên deploy liên tục bằng tag, nên một bản nhánh không tag bị đè mất.
Cộng thêm ổ đĩa dev đầy 96% — do chính script chạy test trên VPS bung mã nguồn ra thư mục
tạm mà không dọn, để lại 128 thư mục và 8.1G cache build. Hậu quả: một lần build mất **2 giờ
32 phút**, lần sau chết hẳn với `no space left on device`. Đã dọn (còn 9.5G trống) và sửa
script tự dọn bằng `trap` để nó dọn cả khi test đỏ.

Nền: [ADR-0044](../../03-decisions/ADR-0044-ngung-su-dung-phan-vung-tach-khoi-xoa.md),
[ADR-0045](../../03-decisions/ADR-0045-cua-phan-vung-dang-lam-viec-canh-ca-hai-duong.md),
[ADR-0046](../../03-decisions/ADR-0046-truc-loc-is-active-la-loi-vao-so-voi-quet-du.md).
Thiết kế: [design](2026-08-29-ngung-su-dung-phan-vung-design.md),
kế hoạch: [plan-backend](2026-08-29-ngung-su-dung-phan-vung-plan-backend.md).

## Đã có gì

Hệ nay có **ba** trạng thái phân vùng thay vì hai:

| `is_active` | `deleted_at` | Nghĩa | Đảo lại được |
|---|---|---|---|
| `true` | `NULL` | Đang dùng | - |
| `false` | `NULL` | **Ngừng sử dụng** | **có** |
| bất kỳ | có giá trị | Đã xoá | không |

| Đường | Việc |
|---|---|
| `PUT /companies/:id/active` | bật / tắt một phân vùng. Body `{"is_active": false}`, trả 204 |
| `GET /companies` | trả thêm `is_active`, nhận `?trang_thai=dang_dung\|ngung` |
| `DELETE /companies/:id` | **đổi hợp đồng** — xem mục dưới |

Migration `000038`: `companies.is_active BOOLEAN NOT NULL DEFAULT true`. Không backfill, không
index (bảng đếm bằng chục hàng, cột hai giá trị).

Mã lỗi mới: `ERR_AUTH_COMPANY_IS_CURRENT` (409) — thao tác lên chính phân vùng mình đang làm
việc. Ra ở **cả hai** đường ngừng sử dụng lẫn xoá.

Chữ **"vô hiệu hoá" đã bị gỡ khỏi cả backend lẫn frontend.** Nó gọi một thao tác không đảo lại
được bằng một cái tên nghe như tạm thời. Hai cái tên nay là **"Ngừng sử dụng"** và **"Xoá phân
vùng"**. Nhãn quyền `auth.company_delete` đổi thành "Ngừng sử dụng / xoá phân vùng" — mã đó
gác cả hai đường, ADR-0044 mục 8 chốt không thêm mã mới.

## Đổi hợp đồng — đọc trước khi mở dev

`DELETE /companies/:id` **nới một nấc**: nay cho xoá khi phân vùng không còn ai **ngoài chính
người quản trị của nó**. Trước đợt này nó từ chối mọi phân vùng còn người, mà từ ADR-0039 mọi
phân vùng ra đời đều mang sẵn một người — nên không có đường dọn một phân vùng tạo nhầm.

Xoá thì **gỡ mọi hàng `user_companies` còn sống** trong cùng transaction. Mọi hàng chứ không
riêng hàng người quản trị: câu đếm lọc `users.is_active`, nên một tài khoản bị khoá không được
đếm nhưng hàng gán của nó vẫn còn.

Không đụng hàng `users` (ADR-0031 mục 2). Hệ quả phải biết: nếu đó là hàng gán duy nhất của
họ, tài khoản ấy còn đăng nhập được nhưng không chọn được phân vùng nào.

## Bằng chứng

Toàn bộ chạy trên **PostgreSQL thật** ở VPS dev, không phải `go build`:

```
ok  	erp/modules/auth                     1.156s
ok  	erp/modules/auth/internal/handler   24.738s
ok  	erp/modules/auth/internal/repository 2.626s
ok  	erp/modules/auth/internal/service   56.967s
ok  	erp/cmd/api                          7.606s
ok  	erp/cmd/internal/vaitro              0.007s
```

`cmd/dev check` **0 dòng FAIL**. Frontend `1539` test xanh, `tsc`/`lint`/`arch`/kiểm giao diện
đều sạch. `check-ids: OK`.

**Mọi bài test mới đều có phép thử đột biến làm bằng** — kể cả những bài xanh ngay lần chạy
đầu. Bài không có đột biến làm bằng là bài chưa xong; đó là luật đã áp cho cả đợt.

Ba phép đo đáng kể nhất:

- **Trả cửa xoá về bản cũ** → **đúng một** bài đỏ, bảy bài `DeleteCompany` khác vẫn xanh. Tức
  bộ test cũ thật sự không phủ ca đó, và bài mới không ăn theo bài nào.
- **Bỏ mệnh đề lọc khỏi ba câu SQL của `PhanVungTheoUser`** → bài "màn chọn phân vùng" đỏ, bài
  "thu hồi phiên" vẫn xanh. Hai chỗ gọi **thật sự rời nhau**.
- **Nối một câu viết sẵn của frontend vào thông điệp backend** → ba bài đỏ. Đợt trước đã phải
  gỡ đúng loại câu ấy, và lúc đó 1276 test xanh không bắt được.

## Bảy lỗi mà vòng soi bắt được, và chúng đến từ đâu

Bộ kiểm kiến trúc **xanh trọn vẹn** trên cây có đủ ba lỗi Critical đầu tiên. R-06, R-15, R-17
không bắt được cái nào — đúng như ADR-0044 phần Mất đã đoán khi nói ràng buộc này không có
checker, chỉ có test. Và 900 dòng test của đợt cũng không bắt, vì cả ba nằm ở đúng chỗ không
bài nào chạm.

| # | Lỗi | Nguồn |
|---|---|---|
| 1 | `PhanVungTheoUser` **không SELECT** `is_active` → mọi phân vùng trả `false` cho người thường | có từ trước; đợt này **làm nó tệ hơn** khi thêm field vào `model.Company` |
| 2 | `PhanVungTheoUser` không lọc `is_active` → màn chọn hiện phân vùng đã ngừng, bấm vào ăn 404 | có từ trước |
| 3 | Cửa xoá hỏi "phân vùng **có** ai mang cờ `is_admin` không" thay vì "người duy nhất còn hoạt động **có phải** người đó không" | plan viết sai: hai câu SQL bất đồng về ai được đếm |
| 4 | Cửa "phân vùng đang làm việc" lọt bằng id **chữ HOA** | thêm cửa mà không nghĩ tới chuẩn hoá đầu vào |
| 5 | Đổi mật khẩu thôi thu hồi phiên ở phân vùng đang ngừng | **hồi quy do bản vá lỗi 2 gây ra** |
| 6 | `GoKhoiPhanVung` — cửa "không tự gỡ mình" cũng lọt bằng id chữ HOA | cùng khuôn lỗi 4, tìm ra bằng một đợt rà chủ động |
| 7 | Ba cửa vẫn lọt bằng **`{uuid}`** và **32-hex không gạch ngang** | **bản vá lỗi 4 và 6 vá đúng một trục rồi dừng** |

Hai dòng cuối là bài học đắt nhất của đợt và nó lặp lại **hai lần**:

> Bản vá đúng ở trục nó nhìn, và không ai hỏi trục còn lại.

Lỗi 5: vá "màn chọn phân vùng hiện phân vùng đã ngừng" bằng cách thêm bộ lọc vào câu SQL — mà
câu đó có **hai** chỗ gọi, và chỗ thứ hai cần đúng hành vi ngược lại.

Lỗi 7: vá cửa lọt bằng chữ hoa bằng `strings.EqualFold` — nhưng `uuid.Validate` nhận **bốn**
hình dạng UUID (36 chuẩn, `urn:uuid:`, `{...}`, 32-hex), Postgres nhận ba, và hai hình dạng
lệch nhau ở **độ dài** chứ không ở hoa/thường. Đã chữa bằng `uuid.Parse` cả hai vế.

**Việc rà chủ động một khuôn lỗi trả công thật.** Sau lỗi 4, một đợt rà quét 209 dòng có `==`,
lọc còn 41 dòng đọc bằng mắt, và tìm ra lỗi 6 ở một hàm chẳng liên quan gì tới đợt việc này.
Rà một khuôn rẻ hơn nhiều so với đợi nó lộ ra lần nữa.

## Hai chỗ code đi ngược ADR — đã ghi lại, không giấu

**1. ADR-0044 mục 4 tự mâu thuẫn.** Mục đó viết đường xoá **cố ý không** cần cửa "phân vùng
đang làm việc", vì `DeleteCompany` đã có cửa "còn người dùng" bắt trước. Tiền đề ấy hết hiệu
lực **ngay trong cùng ADR**: mục 5 nới chính cửa đó. Nhánh thêm cửa vào cả hai đường;
[ADR-0045](../../03-decisions/ADR-0045-cua-phan-vung-dang-lam-viec-canh-ca-hai-duong.md) ghi
phép đính chính.

**2. ADR-0044 phần Nợ để lại phân loại sai.** Nó đặt điều kiện "câu đọc phục vụ đường **nghiệp
vụ** phải lọc `is_active`; câu phục vụ **mặt quản trị** thì không". Đường thu hồi phiên **là**
đường nghiệp vụ mà phải **không** lọc — trục ấy sai, và nó đã gây lỗi 5.
[ADR-0046](../../03-decisions/ADR-0046-truc-loc-is-active-la-loi-vao-so-voi-quet-du.md) thay
bằng trục **"mở lối vào" so với "quét đủ"**, kèm một phép kiểm chạy được thay cho một cái nhãn:

> *Bỏ sót một phân vùng đang ngừng ở câu này thì hỏng cái gì?*

**Một chỗ thứ ba, chưa có ADR:** mục **Alternatives** của ADR-0045 loại phương án "parse cả hai
vế" với lý do `EqualFold` cho cùng kết quả trên mọi đầu vào hex. Lý do đó **sai** — đã chứng
minh bằng chạy thật. Bản vá lỗi 7 đi theo mục **Decision** của chính ADR ấy nên không cần ADR
mới, nhưng câu chữ ở Alternatives thì đã sai và ADR là bất biến. Ghi ở đây.

## Frontend

`frontend-erp` 6 commit, `1539` test xanh.

- **Màn danh sách** — cột trạng thái có chip, bộ lọc ba lựa chọn đi qua URL, cặp nút "Ngừng sử
  dụng" / "Sử dụng lại" đổi chữ theo trạng thái. **Mặc định hiện cả hai**: phân vùng đếm bằng
  chục, và một mặc định ẩn đi sẽ làm người tạo nhầm rồi ngừng nó không bao giờ thấy lại nó.
- **Màn chi tiết** — khối "Vô hiệu hoá phân vùng" tách làm hai. Khối Ngừng sử dụng **không có**
  bước xác nhận; khối Xoá **giữ** bước xác nhận hai nhịp. Bắt xác nhận một việc đảo lại được là
  dạy người dùng bấm qua hộp thoại cho nhanh, và đến lúc gặp hộp thoại nguy hiểm thật thì họ đã
  quen bấm qua.
- Nhánh SỬA của màn chi tiết được kéo vào hệ giao diện: khung xương thay chữ "Đang tải...",
  `BangThongBao` thay `<p>` trần. Đó là ba mục Important mà bản soi đợt trước còn để lại.
- Banner lỗi của **đường ghi** nay mang mã tra cứu. Trước đó chỉ đường đọc có.

**Test đo bằng vai trò, nhãn và thuộc tính — không đo chữ nằm đâu đó trong DOM.** Chip đọc qua
`[data-sac]`, nút lấy theo vai trò `<button>`, banner qua `[role="alert"]`. Repo này từng có
1276 test xanh trong khi bốn thông điệp bị CSS giấu.

## Ba việc còn nợ, và một trong đó cần một quyết định

**1. `laUUID` vẫn nhận bốn hình dạng UUID.** Bản vá lỗi 7 đóng ba cửa đã biết, nhưng **gốc còn
hở**: mọi endpoint nhận `:id` đều chấp nhận cả bốn. Thắt `laUUID` về đúng dạng chuẩn 36 ký tự
chữ thường sẽ đóng cả lớp khe ở mọi màn, nhưng nó đổi hành vi **toàn hệ** nên cần một ADR
riêng — đúng thứ ADR-0045 phần Nợ để lại ghi là "chưa quyết".

**Điều kiện trước khi thắt:** phải rà frontend xem có chỗ nào đang gửi hình dạng khác không.
Thắt mà chưa rà thì màn đó gãy ngay.

**2. Bảng "bốn chỗ đọc" của ADR-0046 thiếu năm hàng.** Cả năm nằm **đúng** phía của trục
(`IDByCode`, `countCompaniesSQL`, hai câu nạp vai trò mặc định, hai công cụ ở `cmd/dev`), nên
ADR không sai. Nhưng nó tự nhận bảng ấy là "phần chốt kiểm được", mà một bảng đóng thiếu năm
hàng thì không kiểm được điều nó hứa. ADR bất biến nên ghi ở đây.

**3. Bộ tài liệu module đã trôi xa hơn đợt này.** `Permission.md` tự đặt luật "mọi method public
phải có đúng một dòng" rồi **thiếu tám** method; bảng route `README.md` liệt kê 21 trong khi
module đăng ký **31**; bảng migration ở `Database.md` thiếu năm dòng. Đợt này sửa những chỗ
**sai**, để lại những chỗ **thiếu**. Đây là chỗ duy nhất trong bộ doc có một ràng buộc tự kiểm
được nhưng không có checker, nên nó sẽ trôi tiếp mỗi đợt.

Ngoài ra: `inventory/hooks/mutation-errors.ts` mang đúng lỗi hụt mà một phép đột biến phơi ra —
`thongDiep = err.message` nuốt mất tên ô lệch ở nhánh 422, và bảy hook ghi của module kho dùng
nó. Bản `company` đã chữa; bản `inventory` thì chưa.

## Đợt siết an toàn tiếp theo (2026-09-01)

Sau khi đợt trên vào `main`, làm tiếp hai việc đã duyệt. Nhánh `feat/that-dinh-dang-uuid`,
đã vào `main`, tag `v0.1.0-rc.107`.

**1. Thắt `laUUID` theo [ADR-0047](../../03-decisions/ADR-0047-lauuid-chi-nhan-dang-uuid-chuan-chu-thuong.md).**
Nay chỉ nhận dạng chuẩn 36 ký tự chữ thường; từ chối `urn:uuid:`, `{...}`, và 32-hex.

**ADR-0047 có một chỗ đã lạc hậu ngay khi thi công: nó viết "BA bản `laUUID`" ở ba chỗ,
thực tế có BỐN.** Bản thứ tư ở `modules/production/internal/service/errors.go` với chín chỗ
gọi. Đã thắt cả bốn. ADR là bất biến nên phép đính chính ghi ở đây; ngày ai mở lại chủ đề
này thì đó là một ADR mới.

Mã lỗi sau khi thắt được **đo thật**, không suy diễn: `404 / ERR_COMMON_NOT_FOUND`, khớp
dự đoán của ADR. Chín ca test hồi quy đổi tên từ `_Tra409`/`Tra422` sang `_Tra404` — một
cái tên khẳng định 409 trong khi đo 404 là đúng loại tên nói dối mà dự án này đã bị đốt
nhiều lần. Đầu vào và mọi phép kiểm trạng thái database giữ nguyên, vì mệnh đề chịu lực
của chúng chưa bao giờ là "409" mà là "một id hình dạng lạ trỏ đúng phân vùng đang sống
thì không được xoá nó".

ADR-0047 tự nhận một cái Mất: thắt `laUUID` sẽ làm mất bằng chứng chạy được cho
`laCungPhanVung`, *"trừ khi ai đó viết bài gọi thẳng nó với đầu vào chưa qua `laUUID`"*.
Bài đó **đã được viết** (`la_cung_phan_vung_internal_test.go`), nên lớp phòng thủ thứ hai
vẫn có bằng chứng.

**2. `CompanyOf` kiểm định dạng — lỗi 500 ở `/auth/refresh`.**
`token.CompanyOf` chỉ **cắt** chuỗi trước dấu chấm, không **kiểm**, rồi giá trị đó đi thẳng
vào `WHERE company_id = $1` trên một cột `uuid`. Một tiền tố không parse được làm PostgreSQL
ném `22P02`, và nó ra tới client thành **500** thay vì **401**. Đắt hơn bình thường một bậc
vì `POST /auth/refresh` **không cần đăng nhập**.

Lỗi có ở **ba** đường, không một: `Refresh`, `Logout`, và `thuHoiPhienCu` (gọi từ chọn phân
vùng — ca này nặng nhất, lỗi kiểu làm hỏng cả transaction). Cửa đặt ở `CompanyOf` chứ không
ở ba chỗ gọi.

Bản vá này **do một phiên khác viết** và để lại trong cây làm việc chung ở dạng chưa commit.
Phiên này chỉ kiểm chứng rồi đóng gói, vì để một bản vá cho lỗi 500 nằm không commit là để
mất nó.

**Món nợ chưa trả:** bốn bản `laUUID` phải giữ khớp nhau và **không có checker nào canh**.
Đó đúng là cách lỗi này sống sót qua hai vòng vá. ADR-0047 phần Nợ để lại ghi việc dựng một
luật kiến trúc cho nó.

**Ba kênh sẽ gãy sau khi thắt**, đều là ca người dùng dán tay một mã từ công cụ ngoài: ô
"Người phụ trách" ở form sửa máy, ba bộ lọc đọc thẳng từ URL, và mã dán vào đường dẫn.
Không đường tự động nào của hệ sinh ra dạng lạ, nên đây là toàn bộ rủi ro.

## Đợt 2026-09-02: bấm tay, và ba việc còn nợ đã trả

`v0.1.0-rc.108`. Ba việc mà bản bàn giao trước để lại cho phiên sau đều đã làm.

**1. Bấm tay trên dev — bắt được ba lỗi mà 2069 test xanh không thấy.** Cả ba đều là loại
"chạy đúng nhưng nói sai chỗ", nên một bài test khẳng định "có banner với chữ X" sẽ xanh ở cả
ba:

- Cùng một luật, hai màn nói hai kiểu: màn danh sách để banner **vàng** ở **đầu trang**, cách
  nút vừa bấm ~380px; màn chi tiết để banner **đỏ** ngay trong khối. Khác cả vị trí, chữ, lẫn
  mức nghiêm trọng. Nay thống nhất: thông điệp về **đúng hàng vừa bấm** (một hàng phụ dưới
  hàng đó), mức **cảnh báo** ở cả hai màn, và chữ lấy từ **một nguồn duy nhất**.
- **`Mã tra cứu` hiện ở ca không có gì để tra.** Đây là lỗi do một chỉ thị quá rộng của chính
  đợt trước: "mọi banner đường ghi phải mang mã tra cứu". Mã tra cứu sinh ra cho ca **hệ thống
  hỏng** - người dùng cầm nó đi hỏi người trực. Ở ca "bạn đang đứng trong phân vùng này" thì
  không có sự cố nào để tra. Ranh giới nay cắt ở một chỗ: **4xx có mã nghiệp vụ thì giấu, còn
  lại thì hiện**.
- **Nút vẫn sáng dù chắc chắn không bấm được.** Nay khoá mềm kèm lý do, đúng lối nút vai trò
  hệ thống đã có sẵn ở màn Phân quyền.

**2. Ba kênh dán tay không còn gãy.** Frontend chuẩn hoá mã định danh trước khi gửi (bỏ ngoặc,
bỏ `urn:uuid:`, thêm gạch, hạ chữ thường). Chuẩn hoá ở **frontend** không mâu thuẫn với việc
ADR-0047 loại chuẩn hoá ở **backend**: lý do ADR loại là "phải rải ra mọi chỗ nhận id", mà ở
frontend tập đó **đóng** - đúng bốn cửa nhập tay. Danh sách ba kênh của bản bàn giao trước
**thiếu một**: `voucher-list-params.ts` cũng đọc thẳng mã từ URL.

**3. Đã có checker canh bốn bản `laUUID`.** Luật so **thân hàm** sau khi chuẩn hoá, lấy nhóm
đông nhất làm bản chuẩn, không dùng danh sách tên file - nên **module thứ năm bị bắt tự động**.
Template sinh module chỉ *gọi* `laUUID` chứ không *khai* nó, nên module mới không biên dịch
được cho tới khi có người chép thân hàm vào, và ngay giây đó luật nhìn thấy. Có thêm chặn
chiều ngược: một bản bị xoá thì luật kêu chứ không im lặng thu hẹp tầm.

## Hai bài học vận hành, ghi để đợt sau khỏi vấp lại

**1. Tách nhánh từ `origin/main`, KHÔNG từ `main`.** Một phiên khác giữ `main` checked out
trong git worktree, nên git **từ chối** cập nhật con trỏ `main` cục bộ:

```
fatal: refusing to fetch into branch 'refs/heads/main'
       checked out at '.../scratchpad/wt-m2'
```

`main` cục bộ vì thế bị ghim ở bản cũ, và **hai agent liên tiếp** tách nhánh từ đó rồi kết
luận sai về trạng thái hệ (một con báo "việc thắt chưa vào main" trong khi nó đã vào).
`origin/main` là con trỏ theo dõi remote, không ai checkout được nên nó luôn đúng sau `fetch`.

**2. Deploy nhánh không tag thì không giữ được.** Máy dev được nhiều phiên deploy liên tục
bằng tag rc; một bản nhánh sẽ bị đè bất cứ lúc nào. Chuyện này xảy ra **hai lần** trong đợt.
Muốn soi thứ gì trên dev thì merge vào `main` rồi tag một rc.

## Việc tiếp theo

Deploy rc lên dev rồi **bấm tay** đủ ba đường: ngừng sử dụng rồi bật lại, xoá một phân vùng
tạo nhầm, và bấm ngừng lên chính phân vùng đang đứng để xem thông điệp 409 hiện ra sao.

Đợt trước bấm tay bắt được **hai** lỗi mà 1276 test xanh không thấy, và đợt này bấm tay là
việc duy nhất chưa làm.

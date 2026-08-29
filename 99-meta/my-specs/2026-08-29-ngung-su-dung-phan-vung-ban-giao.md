# Bàn giao: "Ngừng sử dụng" phân vùng, tách khỏi xoá

Ngày 2026-08-29. Việc số 1 trong ba việc còn nợ của
[bàn giao 2026-08-28](2026-08-28-quan-tri-phan-vung-ban-giao.md).

Ba nhánh, **chưa push, chưa merge**:

| Repo | Nhánh | Số commit |
|---|---|---|
| `backend-erp` | `feat/ngung-su-dung-phan-vung` | 25 (28 file, +2269/−139) |
| `frontend-erp` | `feat/ngung-su-dung-phan-vung` | 6 |
| `docs-erp` | `spec/ngung-su-dung-phan-vung` | 10 |

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

## Việc tiếp theo

Deploy rc lên dev rồi **bấm tay** đủ ba đường: ngừng sử dụng rồi bật lại, xoá một phân vùng
tạo nhầm, và bấm ngừng lên chính phân vùng đang đứng để xem thông điệp 409 hiện ra sao.

Đợt trước bấm tay bắt được **hai** lỗi mà 1276 test xanh không thấy, và đợt này bấm tay là
việc duy nhất chưa làm.

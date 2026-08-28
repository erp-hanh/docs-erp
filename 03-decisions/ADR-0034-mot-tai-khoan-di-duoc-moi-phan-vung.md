# ADR-0034: Một tài khoản đi được mọi phân vùng, và hai câu truy vấn chạy trước khi có phân vùng

**Status:** Proposed (2026-08-25) — đính chính mục 3 ngày 2026-08-25 và 2026-08-27, xem hai khối trích ở đó

## Context

Người quyết nhìn màn thật ở `v0.1.0-rc.53`, bấm vào cụm `DEFAULT · Trụ sở` trên dải đầu trang,
và nói đúng một câu: *"1 tài khoản dùng chung cho tất cả các phân vùng chứ"*.

Hôm nay không phải thế. Hệ nhận diện một người bằng cặp **(phân vùng, email)**:

```sql
-- migrations/000002_create_users.up.sql:50-51
CREATE UNIQUE INDEX uq_users_email_active
    ON users(company_id, email) WHERE deleted_at IS NULL;
```

Nên `hanh@erp.test` ở Trụ sở và `hanh@erp.test` ở Hà Nội là **hai người khác nhau**, hai mật
khẩu, hai bộ vai trò, hai lần đổi mật khẩu khi hết hạn. `POST /auth/login` bắt buộc
`company_code` (`modules/auth/internal/handler/auth_handler.go:69`), và token lấy phân vùng từ
cột `users.company_id` của chính hàng user (`service/auth_service.go:742-743`) chứ không từ một
lựa chọn của người đăng nhập.

[ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) đã hẹn chữa ở "giai đoạn hai" và chốt sẵn schema.
Kiểm lại code ngày 2026-08-25:

| Việc ADR-0019 GĐ2 chốt | Trạng thái thật |
|---|---|
| Dựng `user_companies`, `user_company_roles` | **XONG** — migration `000021`, `000022`, đã backfill, đang được ghi khi tạo user |
| Bỏ `uq_users_email_active` | **chưa có migration nào** |
| Đăng nhập hai bước | **chưa một dòng** |
| Đường đổi phân vùng + thu hồi refresh token | endpoint **chưa có**; cơ chế thu hồi thì **đã có sẵn** (`SoftDeleteByUser`, `SoftDeleteByHash`, đang chạy ở `Refresh`/`Logout`) |

Tức phần chuẩn bị đã xong, phần luồng thì chưa bắt đầu. Kể cả index phục vụ màn chọn phân vùng
cũng đã nằm sẵn trong database từ giai đoạn một — `migrations/000021:60-61`,
`idx_user_companies_user_id_company_id`, cố ý **không** dẫn đầu bằng `company_id` — index đứng
chờ một câu truy vấn chưa ai viết.

### Bức tường thật

Mô hình mới bắt buộc phải có đúng hai câu truy vấn, và **cả hai đều không thể có `company_id`**:

- **(a)** *"ai là người có email này"* — chạy lúc đăng nhập, khi chưa biết phân vùng nào.
- **(b)** *"người này làm ở những phân vùng nào"* — chạy để dựng danh sách cho họ chọn.

R-06 vế hai (`arch/checks_migration.go:207-249`) báo đỏ mọi SELECT/UPDATE/DELETE ở tầng
repository chạm bảng nghiệp vụ mà `WHERE` không khớp `company_id\s*=\s*\$`. Không có cơ chế
miễn trừ cho câu lẻ.

Hai ngoại lệ đang có **không phủ được ca này**:

- ADR-0019 mục 6 bỏ qua nhóm `tenant_root`, mà nhóm đó chỉ có `companies` — không có `users`,
  không có `user_companies`.
- [ADR-0033](ADR-0033-phan-vung-thanh-cay-doc-len-mot-chieu.md) mục 4 mở hình dạng
  `company_id = ANY($1)` cho câu đọc lên cây. Câu (a) và (b) ở đây **không có `company_id` ở
  bất kỳ hình dạng nào** — chúng chạy trước khi phạm vi tồn tại.

Nên đây là một ngoại lệ **thứ ba**, khác chất với hai cái kia, và phải được nói ra riêng.

## Decision

**Danh tính tách khỏi phân vùng. Một `users` là một con người; `user_companies` nói người đó
làm ở đâu. Hai câu truy vấn chạy trước khi có phân vùng được miễn R-06, và danh sách miễn trừ
đó đóng, kiểm được bằng máy.**

### 1. Email và số điện thoại duy nhất toàn hệ thống

```sql
DROP INDEX uq_users_email_active;   -- (company_id, email)
DROP INDEX uq_users_phone_active;   -- (company_id, phone)

CREATE UNIQUE INDEX uq_users_email_active ON users(email) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_users_phone_active ON users(phone)
    WHERE deleted_at IS NULL AND phone IS NOT NULL;
```

**Số điện thoại đi cùng email, không để lại sau.** ADR-0019 chốt ngày 2026-08-17 chỉ nói về
`email`; cột `phone` vào hệ ở `000019`, sau đó. Nếu email toàn hệ thống mà phone thì không, thì
đăng nhập bằng số điện thoại lại không xác định được một người — đúng cái bệnh vừa chữa, chỉ
đổi cửa.

Migration **bắt buộc mang khối tự kiểm `RAISE EXCEPTION`** đếm trùng trước khi drop, theo mẫu
đã dùng ở `000024` và `000025`. Phép đo trên dev ngày 2026-08-24 ra 0 email trùng, 0 phone
trùng — **và phép đo đó không thay được khối tự kiểm**: nó nói về một máy, một ngày, còn
migration chạy trên mọi máy, mọi ngày sau đó.

### 2. `users.company_id` GIỮ NGUYÊN

Cột thành "phân vùng nơi tài khoản này được tạo ra" — một mẩu lai lịch, không còn là phạm vi.

Cân nhắc và loại phương án bỏ cột: bỏ thì phải đưa `users` vào registry C-DB-04 bằng một ADR
nữa, và đổi chữ ký **mọi** method của `UserRepository`. Đắt gấp nhiều lần phần thu được, trong
khi phần thu được chỉ là "cột không còn ý nghĩa cũ".

**Nợ để lại, nói ra để lần sau khỏi bàn lại:** một cột mang tên nói phạm vi mà không còn là
phạm vi là một cái bẫy đọc nhầm. Chốt chặn duy nhất là comment tại chỗ trong migration và
trong `model.User`. Nếu có lần thứ hai ai đó dùng nhầm nó làm phạm vi, thì đó là lúc bỏ cột,
không phải lúc thêm comment thứ ba.

**Vùng mù phải biết:** `checkR06` chỉ quét `CREATE TABLE`, nên một `ALTER TABLE users DROP
COLUMN company_id` **không** làm bộ kiểm đỏ. Bộ kiểm im lặng đúng chỗ nó nên nói to nhất.

### 3. Ba câu truy vấn được miễn R-06, và danh sách miễn trừ ĐÓNG

> **Đính chính 2026-08-25** — mục này ra đời với **hai** câu, hàng (c) được thêm cùng ngày.
> Lý do phát hiện: đo thật trên máy dev `v0.1.0-rc.54` sau khi cả bảy bước đã merge.
> `qa-admin@erp.test` thuộc hai phân vùng; `POST /auth/select-company` trả `200` với phân
> vùng gốc và **`404`** với phân vùng còn lại. Nguyên nhân là `ChonPhanVung` đọc hàng
> `users` bằng một câu còn lọc `company_id`, mà sau mục 2 thì cột ấy chỉ còn là lai lịch.
> Tức bức tường thật ở phần Context có **ba** viên gạch chứ không phải hai, và viên thứ ba
> chỉ lộ ra khi có người đầu tiên thuộc nhiều hơn một phân vùng.
>
> Cùng một câu đọc ấy còn nằm ở ba đường nữa — `POST /auth/refresh`, `GET /auth/me`,
> `POST /auth/change-password` — và cả ba trả `401` cho cùng người đó. Ba đường ấy không đo
> được trên `rc.54` vì `select-company` chặn trước: không ai lấy nổi một token của phân
> vùng thứ hai để mà đi tiếp. Chữa một mình `select-company` sẽ mở chúng ra thành ba lỗi
> mới, nên cả bốn đổi cùng một lượt.

| Câu | Hàm | Vì sao không thể có `company_id` |
|---|---|---|
| (a) tra người theo email/phone | `UserRepository.ByEmailToanHe`, `ByPhoneToanHe` | Chạy lúc đăng nhập, chưa ai chọn phân vùng |
| (b) liệt kê phân vùng của một người | `UserCompanyRepository.PhanVungTheoUser` | Kết quả của nó CHÍNH LÀ danh sách phân vùng |
| (c) đọc hàng `users` lúc cấp token cho phân vùng vừa chọn | `UserRepository.ByIDToanHe` | Chạy **sau khi** đã xác minh người này có hàng `user_companies` còn sống ở phân vùng được chọn, nhưng **trước khi** token mang phân vùng đó tồn tại. Và sau mục 2 thì `users` là bảng DANH TÍNH, không còn là bảng thuộc-về-phân-vùng: lọc nó theo `company_id` là hỏi sai câu hỏi, không phải hỏi thiếu điều kiện |

Câu (c) khác (a) và (b) ở một chỗ đáng nói ra: hai câu kia chạy khi **chưa có** phân vùng
nào trong tay, còn (c) chạy khi **đã có** một `congTyID` đọc ra từ bảng `companies` và đã
kiểm. Cám dỗ là truyền giá trị ấy vào cho "đúng R-06". Làm thế thì câu quay lại đúng lỗi
vừa chữa: nó đi hỏi bảng danh tính một câu về phân vùng, và trả lời "không có người này"
cho một người có thật. Phân vùng được kiểm ở `user_companies` — nơi mệnh đề ấy có nghĩa —
và ở đúng một chỗ.

Ba ràng buộc, và cả ba kiểm được bằng máy:

1. **Đúng ba hàng của bảng trên, không hàm nào khác.** `arch/checks_migration.go` mang một danh sách
   tên hàm cứng. Thêm một hàm mới vào danh sách là một lần sửa ADR, không phải một dòng code
   — đính chính ở trên chính là lần sửa ấy cho hàng (c).
2. **Các hàm này chỉ được gọi từ `AuthService`.** Vế kiểm được bằng máy là vế đó, và chỉ
   vế đó: một danh sách endpoint chép tay trong ADR thì không bộ kiểm nào đọc, nên nó lệch
   ngay lần thứ hai ai đó thêm một đường. Gọi từ ngoài `AuthService` là một câu xuyên phân
   vùng trá hình. Ràng buộc này áp cho `ByIDToanHe` y như ba tên kia.

   Tính đến 2026-08-25, `ByIDToanHe` được gọi ở năm đường: `POST /auth/select-company`,
   `POST /auth/refresh`, `GET /auth/me`, `POST /auth/change-password`, và không đường nào
   khác. Bốn đường sau đều từng đọc `users` bằng một câu lọc `company_id`, và cả bốn đều
   trả lỗi cho một người đang làm việc ở phân vùng khác phân vùng gốc — 404 ở
   `select-company`, 401 ở ba đường còn lại. Con số này là **ghi chú**, không phải ràng
   buộc: thứ ràng buộc là dòng ngay trên.
3. **Chúng chỉ ĐỌC.** Không có đường ghi nào được miễn R-06, theo bất kỳ ADR nào, mãi mãi.

   > **Đính chính 2026-08-27** — ràng buộc này nói một lệnh cấm mà không nói đường ra, và
   > sự im lặng ấy đã tốn một lỗ hổng thật. `AuthService.ChangePassword` cần thu hồi refresh
   > token của một người **ở mọi phân vùng**; `SoftDeleteByUser` là đường GHI nên nó không
   > xin miễn trừ được, và đợt viết mục 4 đã dừng lại ở chỗ đó — để nguyên câu thu hồi cũ
   > chỉ chạy cho phân vùng đang mở, kèm một ghi chú "đó là một quyết định riêng". Kết quả:
   > từ `rc.54` (lượt đầu tiên có người thật sự thuộc hai phân vùng), đổi mật khẩu ở Trụ sở
   > **không** giết phiên ở phân vùng khác, và refresh token kia sống tiếp 30 ngày — đúng
   > cái mà đổi mật khẩu sinh ra để chặn.
   >
   > **Đường ra đúng cho một đường ghi cần chạm nhiều phân vùng: LẶP, không miễn trừ.** Đọc
   > danh sách phân vùng bằng đúng câu ĐỌC đã được miễn ở hàng (b), rồi gọi câu GHI một lần
   > cho mỗi phân vùng — mỗi lời gọi vẫn mang `company_id = $`, nên không có gì phải miễn.
   > Tất cả nằm trong **cùng một transaction** với lệnh ghi chính: một lệnh đổi mật khẩu
   > thành công mà thu hồi hỏng giữa chừng để lại trạng thái tệ hơn cả hai đầu.
   >
   > **Hai cái bẫy của đường ra ấy, cả hai đều hỏng im lặng:**
   >
   > - **Phân trang.** Câu đọc nhận `page`/`page_size` theo R-12. Gọi nó một lần với cỡ
   >   trang mặc định thì chỉ trang đầu bị thu hồi, và thao tác vẫn trả `204`. Phải lặp
   >   **hết** mọi trang; một trần cứng kiểu "chừng này là quá đủ" vẫn là cùng một lỗi.
   > - **Tập nguồn của quản trị hệ thống khác.** ADR-0036 mục 2 cho họ vào mọi phân vùng
   >   còn sống mà **không** cần hàng `user_companies`, và mục 4 cấm thêm hàng ấy. Nên với
   >   họ, `PhanVungTheoUser` trả về ít hơn hẳn tập phân vùng họ thật sự có phiên, và một
   >   vòng lặp chỉ đọc bảng ấy sẽ bỏ sót đúng những phiên mạnh nhất trong hệ. Tập nguồn của
   >   họ là danh sách phân vùng còn sống — đúng tập mà `PhanVungCuaToi` dùng cho họ theo
   >   ADR-0036 mục 1.
   >
   > Lệnh cấm ở dòng trên **không đổi**: vẫn không đường ghi nào được miễn R-06.

Ràng buộc 2 là ràng buộc quan trọng nhất và cũng là ràng buộc dễ trôi nhất. Nó phải có một
test kiến trúc riêng, không dựa vào code review.

> **Đính chính 2026-08-28** — bảng trên có **bốn** hàng kể từ hôm nay. Hàng (d) được thêm
> theo đúng cơ chế mà ràng buộc 1 đặt ra: thêm một hàm vào danh sách miễn trừ là một lần sửa
> ADR, và đây là lần sửa ấy.
>
> | Câu | Hàm | Vì sao không thể có `company_id` |
> |---|---|---|
> | (d) tra người theo email để trả lời "đã có trong hệ chưa" | `UserRepository.ByEmailToanHeRutGon` | Câu hỏi tự nó là câu hỏi toàn hệ. Lọc theo phân vùng thì luôn trả "chưa có" cho đúng ca cần phát hiện: một người đang làm ở phân vùng khác |
>
> **Vì sao cần nó.** Một người kiêm nhiệm hai đơn vị phải là MỘT hàng `users` với NHIỀU hàng
> `user_companies`. Hôm nay không có đường nào tạo ra hàng gán thứ hai, nên quản trị gõ email
> của người đã có trong hệ thì nhận `409` trống và bế tắc. Để màn hình mời được "thêm người
> này vào đơn vị của bạn", service phải tra được người đó — và câu tra ấy chạy khi chưa biết
> người đó ở phân vùng nào. Thiết kế đầy đủ ở
> `99-meta/my-specs/2026-08-28-kiem-nhiem-nhieu-phan-vung-design.md`.
>
> **Ba ràng buộc, đặt hẹp hơn ba hàng cũ:**
>
> - **Chỉ `UserService` gọi.** Không phải `AuthService` như ba hàng kia, và bộ kiểm phải phân
>   biệt được hai chỗ gọi đó chứ không nới thành "service nào cũng được".
> - **Chỉ trả `id` và `full_name`.** Hậu tố `RutGon` nằm trong tên để chính cái tên nói ra
>   điều đó. Một hàm trả `*model.User` đầy đủ sẽ được dùng lại cho việc khác trong sáu tháng
>   nữa, và lúc ấy nó là một câu đọc toàn hệ không ai còn nhớ là đã được miễn trừ vì lý do gì.
> - **Chỉ đọc.** Ràng buộc 3 không đổi một chữ: không đường ghi nào được miễn R-06. Đường ghi
>   của đợt này — gán và gỡ một người khỏi một phân vùng — lấy `company_id` từ actor nên
>   không xin miễn trừ gì cả.
>
> **Cái giá, nói ra chứ không giấu:** quản trị của một phân vùng bây giờ xác nhận được rằng
> một email có tồn tại ở đâu đó trong hệ. `409` hiện tại đã làm đúng việc ấy rồi — khác biệt
> là bản mới kèm họ tên. Đó là lượng thông tin tối thiểu để hỏi "có phải người này không";
> phân vùng họ đang làm, vai trò, số điện thoại đều KHÔNG được trả.

### 4. Đăng nhập hai bước

```
POST /auth/login            {email|phone, password}
   -> token danh tính, sống 5 phút, KHÔNG mang company_id
GET  /auth/companies        (token danh tính hoặc access token thường)
   -> danh sách phân vùng của người này
POST /auth/select-company   {company_code}
   -> TokenPairDTO đầy đủ, access token mang company_id
```

**Không có endpoint thứ ba cho "đổi phân vùng".** Hai đường trên nhận cả token danh tính lẫn
access token thường, nên đổi phân vùng giữa chừng là gọi lại đúng hai đường đó. Một endpoint
`switch-company` riêng sẽ là bản sao của `select-company` chỉ khác loại token đầu vào — và hai
đường làm cùng một việc thì sớm muộn lệch nhau.

**`select-company` thu hồi refresh token của phân vùng cũ** bằng `SoftDeleteByHash`, đúng mẫu
`Refresh` và `Logout` đang chạy. Không viết cơ chế mới.

**Đặt tên, và đây là bẫy có thật:** `arch/checks_migration.go:276-306` (`dtoNhanCompanyID`) báo
đỏ **mọi** struct có tag `json:"company_id"`, kể cả DTO trả về. Nên `GET /auth/companies` trả
field tên `id`, và `select-company` nhận `company_code` chứ không `company_id`.

### 5. Access token cũ còn sống tối đa 15 phút sau khi đổi phân vùng

Đổi phân vùng không giết được access token đang cầm — nó là JWT, không tra database. Người vừa
đổi sang Hà Nội vẫn còn một token đọc được Trụ sở cho tới khi nó hết hạn.

**Chấp nhận, không vá ở ADR này.** ADR-0019 mục 9 đã cân và nhận trước; vá nó là dựng blacklist
`jti`, và ADR-0019 mục 147 đã loại `session_id`/`token_version`. Ngày cần vá thật thì đó là một
ADR riêng.

Điều này **không** phải một lỗ hổng leo thang: token cũ chỉ mở đúng phân vùng mà người đó vốn
đã có quyền vào. Nó là một cửa sổ trễ, không phải một cửa mở thêm.

## Consequences

**Được**

- Một người một tài khoản, một mật khẩu, dù làm ở mấy chi nhánh. Đây là thứ người quyết yêu
  cầu, và là thứ mọi người dùng cuối mặc định tưởng đã có.
- Popover đổi phân vùng dựng ở `rc.53` thành thật, thay vì bốn dòng khoá mềm.
- Bỏ được `VITE_COMPANY_CODE` và hằng `cau-hinh.ts` ở frontend — một bản triển khai thôi bị
  đóng đinh vào một phân vùng.
- `users.roles TEXT[]` bỏ được, vì vai trò đã sống ở `user_company_roles` từ giai đoạn một.

**Mất**

- `POST /auth/login` **phá tương thích**: bỏ `company_code`, đổi hình dạng response. Mọi thứ
  gọi nó phải sửa cùng lúc — frontend, `cmd/api/e2e_test.go`.
- Frontend có thêm **trạng thái phiên thứ tư**: "đã xác thực nhưng chưa chọn phân vùng". Hôm
  nay `session.ts` chỉ có `checking / anonymous / …`.
- Hai migration chạm dữ liệu đang có, và chúng có thứ tự bắt buộc so với code. Cửa sổ hẹp nhất
  là giữa lúc repository thôi đọc cột `roles` và lúc migration bỏ cột: lùi backend về trước bước
  một sau khi migration đã chạy là vỡ ngay câu SELECT đầu tiên.
- R-06 có ngoại lệ thứ ba. Ba ngoại lệ là ngưỡng mà một luật bắt đầu đọc ra như một gợi ý. Nếu
  có ngoại lệ thứ tư, việc phải làm là viết lại R-06 cho đúng, không phải nối thêm một dòng.
  Đính chính 2026-08-25 **không** tạo ngoại lệ thứ tư: nó nới chính ngoại lệ thứ ba từ hai
  hàng lên ba, cùng một lý do và cùng một bộ ràng buộc. Con số phải theo dõi vẫn là ba.

**Không đổi**

- Ranh giới dữ liệu giữa các phân vùng. Sau khi chọn xong, token mang đúng một `company_id` và
  mọi câu truy vấn nghiệp vụ vẫn kèm nó. ADR này đổi cách **đi tới** một phân vùng, không đổi
  chuyện ở trong đó.
- Chiều ngang và đường ghi xuyên phân vùng vẫn cấm, theo ADR-0033 mục 2.

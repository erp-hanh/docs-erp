# C-API — Quy ước HTTP API

Convention nằm **giữa** Rule và Code. Rule nói *"lỗi validate trả 422"*; file này nói
*"body của 422 có hình dạng nào, mã lỗi viết ra sao"*. Rule trả lời **cái gì bắt buộc
đúng**, Convention trả lời **viết ra như thế nào**.

File này **không phải nguồn sự thật** cho thứ mà Rule đã quyết. Khi nó lệch với
[../01-rules/RULES.md](../01-rules/RULES.md), bản ở RULES.md thắng và file này là thứ phải
sửa.

Một mục ở đây khác các mục còn lại về bản chất: **C-API-07 là sổ đăng ký**. Năm Rule và
Principle khác nhau đều nói ngoại lệ của chúng "phải được ghi vào `04-conventions/C-API-http.md`";
C-API-07 là chỗ đó. Nó là dữ liệu chứ không phải văn bản quy ước, và nó dài ra theo từng
PR.

| Mục | Nội dung | Neo về |
|---|---|---|
| C-API-01 | Cấu trúc URL | R-10, R-13 |
| C-API-02 | Mã status theo tình huống | R-10 |
| C-API-03 | Struct envelope | R-11 |
| C-API-04 | Tham số phân trang, sắp xếp, lọc | R-12 |
| C-API-05 | Bảng mã lỗi nghiệp vụ | R-11 |
| C-API-06 | Quy tắc versioning | R-13 |
| C-API-07 | Sổ đăng ký ngoại lệ | R-10, R-11, R-12, R-16 |

---

### C-API-01 — Cấu trúc URL

**Implements:** R-10, R-13

Mọi route nghiệp vụ nằm dưới `/api/v1`, đăng ký qua `router.Group("/api/v1")` chứ không
gõ tiền tố vào từng route.

| Hình dạng | Method | Ý nghĩa | Ví dụ |
|---|---|---|---|
| `/api/v1/<tai-nguyen>` | GET | Danh sách, có phân trang (R-12) | `GET /api/v1/orders` |
| `/api/v1/<tai-nguyen>` | POST | Tạo mới | `POST /api/v1/orders` |
| `/api/v1/<tai-nguyen>/:id` | GET | Chi tiết một bản ghi | `GET /api/v1/orders/:id` |
| `/api/v1/<tai-nguyen>/:id` | PUT | Thay toàn bộ bản ghi | `PUT /api/v1/orders/:id` |
| `/api/v1/<tai-nguyen>/:id` | PATCH | Sửa một phần bản ghi | `PATCH /api/v1/orders/:id` |
| `/api/v1/<tai-nguyen>/:id` | DELETE | Xóa mềm (R-18) | `DELETE /api/v1/orders/:id` |
| `/api/v1/<tai-nguyen>/:id/<tai-nguyen-con>` | GET, POST | Tài nguyên con | `GET /api/v1/orders/:id/items` |
| `/api/v1/<tai-nguyen>/:id/actions/<verb>` | POST | Hành động không map được vào CRUD | `POST /api/v1/orders/:id/actions/approve` |

Quy ước viết:

- **Danh từ số nhiều, chữ thường, kebab-case** cho từ ghép: `/orders`, `/order-items`,
  `/price-lists`, `/work-orders`. Không snake_case trong path, không camelCase.
- **Cấm động từ trong path**: `/getUser`, `/createOrder`, `/orders/search` đều sai. Chỗ
  duy nhất động từ được xuất hiện là sau `/actions/` — và đó là ngoại lệ phải đăng ký ở
  C-API-07.
- Tên tài nguyên trên path **khớp tên bảng** khi có thể, để đọc một URL là biết nó chạm
  bảng nào.
- Path param `:id` luôn là `UUID`. Không nhận id dạng số, không nhận mã nghiệp vụ ở vị trí
  `:id` — tra theo mã là một filter trên endpoint list (`GET /api/v1/orders?code=PO-001`).
- **Không lồng quá hai tầng.** `/orders/:id/items` được;
  `/customers/:id/orders/:oid/items/:iid` thì không — tầng thứ ba trở đi tách thành tài
  nguyên gốc riêng (`/order-items/:id`).
- Query param dùng **snake_case**, khớp với quy ước field JSON: `page_size`,
  `created_from`.
- **Cấm `company_id` xuất hiện ở path, query, hay body** (R-06). Công ty của người gọi lấy
  từ actor, không lấy từ request.

Ba nhóm nằm ngoài quy ước trên, cả ba đều đã được Rule cho phép sẵn nên **không** cần đăng
ký ở C-API-07:

- `/health`, `/ready`, `/metrics` — endpoint hạ tầng, nằm ngoài `/api/v1`. Đây là danh
  sách đóng của R-13; thêm endpoint hạ tầng mới phải sửa chính R-13.
- `/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/auth/logout` — nhóm `auth` được
  R-10 cho phép dùng path không theo dạng tài nguyên.
- Endpoint dạng `/actions/<verb>` thì **phải** đăng ký ở C-API-07.

---

### C-API-02 — Mã status theo tình huống

**Implements:** R-10

| Tình huống | Status | Body |
|---|---|---|
| GET chi tiết, GET list, PUT/PATCH thành công | `200` | envelope có `data` |
| POST tạo mới thành công | `201` | envelope có `data` là bản ghi vừa tạo |
| DELETE thành công | `204` | không có body |
| JSON sai cú pháp, body rỗng, hoặc query param sai kiểu (`page=abc`) | `400` | envelope có `error` mã `ERR_COMMON_MALFORMED_REQUEST`, **không** có `error.fields` |
| Chưa xác thực, token sai hoặc hết hạn | `401` | envelope có `error` |
| Đã xác thực nhưng không đủ quyền | `403` | envelope có `error` |
| Không tìm thấy bản ghi | `404` | envelope có `error` |
| Xung đột trạng thái: trùng mã, đơn đã duyệt, hết tồn, xung đột phiên bản | `409` | envelope có `error` |
| Validate thất bại — sai hình dạng request | `422` | envelope có `error.fields` |
| Vượt hạn mức gọi | `429` | envelope có `error` |
| Lỗi kỹ thuật | `500` | envelope có `error` mã `ERR_INTERNAL` + `request_id` |
| Phụ thuộc ngoài không sẵn sàng | `503` | envelope có `error` |

Bốn ranh giới hay bị làm sai, mỗi cái đều có hệ quả thật:

**`400` và `422`.** Từ chặng E, ranh giới không còn gói gọn trong một câu "đã đọc được hay
chưa" — nó tách theo **đường bind**. Thân JSON hỏng cú pháp hoặc body rỗng thì chưa đọc
được gì cả, `400`. Thân JSON đọc được về mặt cú pháp nhưng **sai kiểu một field**
(`"repair_cost": 1500000` — số JSON thay vì chuỗi) hoặc vi phạm ràng buộc `binding:"..."`
(thiếu field bắt buộc, `quantity` âm) là `422` kèm danh sách field lỗi — sai kiểu và sai
ràng buộc giờ đi chung một mã, cùng mang `error.fields`. Query param sai kiểu (`page=abc`)
đi qua một đường bind khác thân JSON (`ShouldBindQuery`) và **vẫn** là `400`, cố ý ngoài
phạm vi của thay đổi này — xem C-API-05. Trả `400` cho lỗi validate hay lỗi sai kiểu trong
thân JSON là dấu hiệu vi phạm R-10: frontend cần phân biệt hai loại này để quyết có
highlight ô hay không.

Handler **không** tự chọn giữa hai mã đó: mọi lỗi bind thân JSON đi qua
`response.BindFailed(c, err)`, và hàm đó chốt ranh giới một lần cho cả hệ thống. Quy tắc nó
dùng, sau chặng E: `validator.ValidationErrors` → `422` kèm field theo từng phần tử;
`*json.UnmarshalTypeError` **có `Field` khác rỗng** → `422` kèm đúng một field, tên lấy từ
thuộc tính `Field` sẵn có của chính lỗi đó; **mọi thứ còn lại** (JSON sai cú pháp, body
rỗng) → `400` không field. Đây là đúng **một** kiểu lỗi phân tích được nhận thêm vào danh
sách được nhận diện tên, không phải một bảng phân loại lỗi phải giữ cho đầy đủ theo từng
phiên bản của gin hay `encoding/json` — mở rộng danh sách đó là lặp lại đúng rủi ro mà bản
thân `BindFailed` từng tránh khi chỉ nhận `validator.ValidationErrors`.

Điều kiện "`Field` khác rỗng" không phải chi tiết vặt: `*json.UnmarshalTypeError` cũng sinh
ra khi cả **thân request** — không phải một field bên trong nó — không phải object mà
`ShouldBindJSON` đang chờ, ví dụ thân là `[1,2,3]`, `"chuoi"`, hay `123` thay vì
`{...}`. Trong ca đó `Field` là chuỗi rỗng, vì lỗi nằm ở hình dạng của cả thân request chứ
không ở một ô nào cụ thể — và ca đó **ở lại `400`**, không được suy ra `422`. Mệnh đề
"`422` luôn có `error.fields`; `400` không bao giờ có" (xem hộp cuối C-API-05) mạnh hơn
đúng ca ngoại lệ này, và không được phép có ngoại lệ ngược lại.

Một hệ quả kèm theo, phải biết để không tưởng nhầm là lỗi: **`planned_date`,
`commissioned_date` và `occurred_at` không còn là `time.Time` trong DTO, mà là `string`.**
`*time.ParseError` sinh ra từ `UnmarshalJSON` của `time.Time` không mang tên field của
struct cha — nó chỉ biết layout và value, không biết mình đang nằm ở đâu — nên không có
cách nào lấy tên ô ra khỏi nó. Ba trường ngày đi theo đúng khuôn đã có sẵn trong repo từ
trước (`repair_cost` bind vào `RepairCostText string` rồi handler tự chuyển): DTO nhận
chuỗi, handler tự parse và tự đặt tên field khi hỏng. Cái giá là DTO mất kiểm tra kiểu tĩnh
ở ba trường đó; chỉ trường **người dùng gõ ngày** đi lối này, và mỗi lần thêm một trường
mới vào danh sách đó phải có dòng giải thích tại chỗ.

`occurred_at` khác hai trường kia ở đúng một điểm, và điểm đó **quyết định định dạng chuỗi
mà mỗi trường nhận**: cột của nó là `TIMESTAMPTZ` (migration `000008_create_breakdowns`),
không phải `DATE` như `planned_date` và `commissioned_date`.

| Trường | Cột | Nhận |
|---|---|---|
| `planned_date`, `commissioned_date` | `DATE` | `"2026-09-01"` **hoặc** RFC 3339 đầy đủ |
| `occurred_at` | `TIMESTAMPTZ` | chỉ RFC 3339 đầy đủ |

Ranh giới chạy giữa **kiểu cột**, không giữa các endpoint. Ở `occurred_at`, phần giờ là dữ
liệu nghiệp vụ thật — thời điểm trong ngày sự cố xảy ra — nên một `"2026-09-01"` gửi vào đó
vẫn ra `422` kèm field: nhận nó nghĩa là ghi 00:00 cho một sự cố lúc 14:30, và không client
nào phát hiện được điều đó. Ở hai trường trên cột `DATE` thì phần giờ bị bỏ sau khi parse,
nên dạng ngắn không mất gì.

**Bản đầu của mục này đòi RFC 3339 đầy đủ cho cả ba** và gọi đó là chủ ý. Lý do đổi không
phải tiện lợi: dạng đầy đủ buộc client tự nối phần giờ vào ngày người dùng chọn, và **chọn
múi giờ nào để nối là một quyết định ngữ nghĩa** — nó quyết định ngày nào rơi vào cột `DATE`.
Bàn giao chặng E ghi lại chính lập luận đó khi giải thích vì sao frontend chọn UTC. Một
quyết định ngữ nghĩa sống ở frontend là thứ `R-19` và [ADR-0009](../03-decisions/ADR-0009-business-rule-chi-o-backend.md)
đóng lại, nên nó phải về backend.

**`403` và `404`.** Bản ghi tồn tại nhưng thuộc công ty khác thì trả **`404`**, không phải
`403`. Với R-06, "không tồn tại" và "tồn tại nhưng của công ty khác" cho ra cùng một
`sql.ErrNoRows`, và chúng **phải** cho ra cùng một câu trả lời: trả `403` là xác nhận với
người ngoài rằng bản ghi đó có tồn tại
([../02-principles/P-ERR-error-handling.md](../02-principles/P-ERR-error-handling.md)).
`403` chỉ dành cho ca người gọi có quyền truy cập dữ liệu nhưng không có quyền *thao tác*
(R-15).

**`409` và `422`.** Phân biệt bằng: **có cần đọc database mới biết sai hay không.** Sai
hình dạng biết được chỉ bằng cách nhìn request → `422`. Sai trạng thái — mã trùng, đơn đã
duyệt, vượt hạn mức tín dụng, hết tồn kho — phải đọc DB mới biết, và cùng một request có
thể hợp lệ lúc 10h rồi không hợp lệ lúc 10h01 → `409`. Frontend xử lý hai loại khác hẳn
nhau: `422` giữ form, `409` phải tải lại dữ liệu.

**Idempotency.** Ba ca, ba status khác nhau
([../02-principles/P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md)):

- Endpoint có tên trong bảng 5 của C-API-07 mà request thiếu header `Idempotency-Key` →
  `422`, mã `ERR_COMMON_IDEMPOTENCY_KEY_MISSING`.
- Cùng khóa, **cùng payload** (client retry sau timeout) → trả lại **chính response của
  lần đầu**: cùng status (`201`), cùng body, cùng id. **Không** trả `409` — từ phía client,
  `409` không phân biệt được "trùng với request của chính tôi" (thành công, đi tiếp) với
  "trùng mã đơn do người khác tạo" (thất bại, phải sửa input).
- Cùng khóa, **payload khác** → `422`, mã `ERR_COMMON_IDEMPOTENCY_KEY_REUSED`. Đây là lỗi
  phía client, không phải chỗ để âm thầm trả lại kết quả cũ.

Ngoài ra: `200` với `data` là mảng rỗng và `meta.total` bằng `0` là câu trả lời **đúng**
cho một danh sách không có bản ghi nào. Danh sách rỗng không phải `404`.

---

### C-API-03 — Struct envelope

**Implements:** R-11

Mọi response đi qua đúng một struct envelope trong `shared/response`. Handler và
middleware **không** gọi `c.JSON` với `gin.H{}` hay struct khai tại chỗ.

Envelope có bốn field, và luôn đúng một trong hai field `data`/`error` có mặt:

- `data` — thân dữ liệu. Object với response một bản ghi, mảng với response list.
- `meta` — chỉ có ở response list, chứa `total`, `page`, `page_size` (R-12).
- `error` — chỉ có ở response lỗi, chứa `code`, `message`, và `fields` khi là lỗi validate.
- `request_id` — có ở **mọi** response, kể cả thành công.

`request_id` đồng thời đi qua header `X-Request-Id` cho mọi response. Bản sao trong
envelope chỉ là tiện ích cho client; header mới là đường chính thức, để endpoint trả file
(ngoại lệ của R-11, đăng ký ở bảng 2 của C-API-07) vẫn có chỗ mang `request_id` (R-17).

#### 1. Thành công, một bản ghi

```json
{
  "data": {
    "id": "9f1c0a6e-4b2d-4f8a-9c33-2b7d8e5a1f04",
    "code": "PO-2026-000123",
    "status": "approved",
    "total_amount": "15750000.0000",
    "ordered_at": "2026-08-10T09:15:00+07:00",
    "created_at": "2026-08-10T09:14:52+07:00",
    "updated_at": "2026-08-10T10:02:11+07:00"
  },
  "request_id": "01J9Z8XK7QW3V6M2NB4TY5RC8D"
}
```

`total_amount` là **chuỗi**, không phải số JSON. Cột là `NUMERIC(18,4)` (C-DB-01 và
C-DB-02); tuần tự hóa nó thành số JSON là đưa nó qua `double` của JavaScript và trả lại
đúng cái sai số mà `NUMERIC` sinh ra để tránh.

#### 2. Thành công, danh sách kèm `meta`

```json
{
  "data": [
    {
      "id": "9f1c0a6e-4b2d-4f8a-9c33-2b7d8e5a1f04",
      "code": "PO-2026-000123",
      "status": "approved",
      "total_amount": "15750000.0000"
    },
    {
      "id": "3a7b1c22-88ef-4d10-b0a5-6c9e2f4d7a81",
      "code": "PO-2026-000124",
      "status": "draft",
      "total_amount": "2400000.0000"
    }
  ],
  "meta": {
    "total": 128,
    "page": 2,
    "page_size": 20
  },
  "request_id": "01J9Z8XK7QW3V6M2NB4TY5RC8D"
}
```

Danh sách rỗng vẫn giữ nguyên hình dạng này: `"data": []` và `"meta": {"total": 0, ...}`.
Không bao giờ trả mảng trần làm body, và không bao giờ trả `"data": null` cho danh sách
rỗng — xem lưu ý về slice `nil` ở cuối mục.

#### 3. Lỗi validate 422 kèm danh sách field lỗi

```json
{
  "error": {
    "code": "ERR_COMMON_VALIDATION_FAILED",
    "message": "Dữ liệu gửi lên không hợp lệ",
    "fields": [
      {
        "field": "code",
        "message": "không được để trống"
      },
      {
        "field": "items.0.quantity",
        "message": "phải lớn hơn 0"
      },
      {
        "field": "ordered_at",
        "message": "sai định dạng, cần RFC 3339"
      }
    ]
  },
  "request_id": "01J9Z8XK7QW3V6M2NB4TY5RC8D"
}
```

`field` dùng **đường dẫn tới field trong body request**, đúng tên `json` tag, phần tử mảng
đánh chỉ số từ 0 (`items.0.quantity`). Đó là thứ frontend cần để highlight đúng ô.

#### Struct Go trong `shared/response`

```go
package response

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	apperr "erp/shared/errors"
	"erp/shared/requestid"
)

// Envelope là thân JSON của mọi response đi qua shared/response (R-11).
// Đúng một trong hai field Data và Error mang giá trị; Meta chỉ có ở response list.
type Envelope struct {
	Data      any        `json:"data,omitempty"`
	Meta      *Meta      `json:"meta,omitempty"`
	Error     *ErrorBody `json:"error,omitempty"`
	RequestID string     `json:"request_id"`
}

// Meta là khối phân trang bắt buộc của mọi response list (R-12).
type Meta struct {
	Total    int64 `json:"total"`
	Page     int   `json:"page"`
	PageSize int   `json:"page_size"`
}

// ErrorBody mang mã lỗi ổn định của C-API-05. Client rẽ nhánh theo Code, không theo
// Message: lấy chuỗi thông điệp làm khóa rẽ nhánh thì sửa chính tả cũng thành breaking
// change (P-ERR).
type ErrorBody struct {
	Code    string       `json:"code"`
	Message string       `json:"message"`
	Fields  []FieldError `json:"fields,omitempty"`
}

// FieldError chỉ xuất hiện ở lỗi validate 422, mỗi field sai một phần tử.
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func Success(c *gin.Context, data any) { write(c, http.StatusOK, Envelope{Data: data}) }

func Created(c *gin.Context, data any) { write(c, http.StatusCreated, Envelope{Data: data}) }

func NoContent(c *gin.Context) { c.Status(http.StatusNoContent) }

// List luôn kèm Meta, kể cả khi rỗng: data là [] và meta.total là 0, không phải null
// và cũng không phải 404.
func List(c *gin.Context, data any, m Meta) {
	write(c, http.StatusOK, Envelope{Data: data, Meta: &m})
}

// ValidationFailed là đường ra duy nhất của lỗi sai hình dạng request: 422 (R-10), lỗi
// gắn vào từng field để form highlight đúng ô (P-ERR).
func ValidationFailed(c *gin.Context, fields []FieldError) {
	write(c, http.StatusUnprocessableEntity, Envelope{Error: &ErrorBody{
		Code:    apperr.CodeValidationFailed,
		Message: "Du lieu gui len khong hop le",
		Fields:  fields,
	}})
}

// FieldErrors dịch lỗi của binding validator sang []FieldError. Mọi handler đều cần
// nó ngay sau ShouldBindJSON, nên nó sống ở đây chứ không được viết lại trong từng
// module — hai bản dịch khác nhau nghĩa là client nhận hai hình dạng lỗi cho cùng một
// loại sai.
//
// Hợp đồng của nó, và đây là phần dễ làm sai nhất:
//
//   - `field` là ĐƯỜNG DẪN tới field trong body request, viết theo tag `json` chứ
//     không phải tên field Go: `customer_id`, không phải `CustomerID`.
//   - Phần tử mảng đánh chỉ số từ 0 và nối bằng dấu chấm: `items.0.quantity`. Đây là
//     thứ frontend cần để highlight đúng ô thứ mấy của dòng thứ mấy (C-TS-05).
//   - Lỗi không gắn được vào field nào — ví dụ JSON hỏng cú pháp — trả về một phần tử
//     duy nhất với `field` rỗng.
func FieldErrors(err error) []FieldError {
	var ve validator.ValidationErrors
	if !errors.As(err, &ve) {
		// Không phải lỗi validate: JSON hỏng, kiểu sai, body rỗng. Không có field nào
		// để gắn vào.
		return []FieldError{{Field: "", Message: "Body khong doc duoc"}}
	}

	out := make([]FieldError, 0, len(ve))
	for _, fe := range ve {
		out = append(out, FieldError{
			Field:   jsonPath(fe.Namespace()),
			Message: messageFor(fe),
		})
	}
	return out
}

// jsonPath đổi Namespace của validator (`CreateOrderRequest.Items[0].Quantity`) sang
// đường dẫn theo tag json (`items.0.quantity`): bỏ tên struct gốc, đổi `[0]` thành
// `.0`, và tra tag json của từng chặng. messageFor sinh thông điệp tiếng Việt theo
// tag validate (`required`, `gt`, `uuid`...). Cả hai không xuất khẩu — chúng là chi
// tiết của FieldErrors, không phải API.

// Error trả lỗi đã có mã ra nguyên trạng; lỗi không có mã là lỗi kỹ thuật nên chỉ ra
// tới client dưới dạng ERR_INTERNAL kèm request_id (P-ERR).
func Error(c *gin.Context, err error) {
	var appErr *apperr.Error
	if errors.As(err, &appErr) {
		write(c, appErr.HTTPStatus, Envelope{Error: &ErrorBody{
			Code:    appErr.Code,
			Message: appErr.Message,
		}})
		return
	}
	write(c, http.StatusInternalServerError, Envelope{Error: &ErrorBody{
		Code:    apperr.CodeInternal,
		Message: "Loi he thong",
	}})
}

// write là chỗ duy nhất trong toàn hệ thống gọi c.JSON. Nó nằm ở shared/response nên
// nằm ngoài phạm vi grep của R-11 (modules/** và shared/middleware/**).
func write(c *gin.Context, status int, env Envelope) {
	env.RequestID = requestid.FromContext(c.Request.Context())
	c.Header("X-Request-Id", env.RequestID)
	c.JSON(status, env)
}
```

Ba chi tiết cài đặt quyết định hình dạng JSON ở trên:

- **Kiểu của `Data` là `any` chứ không phải một struct cụ thể**, nên `omitempty` trên nó
  chỉ bỏ qua khi interface là `nil`. Một `interface` không `nil` đang giữ slice rỗng vẫn
  được tuần tự hóa — đúng thứ R-12 cần.
- **Nhưng một slice `nil` nằm trong interface đó lại ra `null`.** Vì vậy repository trả về
  `make([]T, 0)` cho kết quả rỗng, không trả `nil`. Đây là chỗ `"data": null` lọt ra thực
  tế nhiều nhất.
- **`ErrorBody` chứ không phải `Error`** vì package đã có hàm `Error(c, err)`. Tên hàm giữ
  đúng như R-11 nêu ở phần cách sửa; kiểu đổi tên.

---

### C-API-04 — Tham số phân trang, sắp xếp, lọc

**Implements:** R-12

Mọi endpoint list nhận đúng ba tham số chuẩn dưới đây, tên và ngữ nghĩa giống nhau ở mọi
module:

| Tham số | Mặc định | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| `page` | `1` | `>= 1` | Trang thứ mấy, đếm từ 1 |
| `page_size` | `20` | `1..100` | Số bản ghi mỗi trang |
| `sort` | tùy endpoint | phải có trong whitelist | `field` tăng dần, `-field` giảm dần |

- `page_size` vượt `100` trả **`422`**, không cắt ngọn im lặng: client xin 500 mà nhận 100
  rồi tự phân trang theo giả định 500 sẽ mất bản ghi mà không biết.
- `page` vượt số trang có thật trả `200` với `data` rỗng và `meta.total` đúng — không phải
  `404`.
- `OFFSET` tính bằng `(page - 1) * page_size`.
- `meta.total` là tổng số bản ghi **sau khi lọc, trước khi phân trang**.

#### `sort` phải đi qua whitelist tĩnh

Giá trị `sort` do client gửi **không bao giờ được nội suy vào SQL** — không nối chuỗi,
không `fmt.Sprintf`. Nó là khóa để tra vào một map whitelist khai **tĩnh ở cấp package**
trong repository; thứ đi vào câu SQL là **giá trị lấy ra khỏi map**. Khóa không có trong
map rơi về cột mặc định thay vì báo lỗi (R-12).

```go
package repository

import "strings"

// orderSortable là whitelist TĨNH khai ở cấp package: khóa là tên field client gửi lên,
// giá trị là tên cột thật. Chuỗi do client gửi không bao giờ đi vào SQL (R-12).
var orderSortable = map[string]string{
	"created_at": "created_at",
	"code":       "code",
	"status":     "status",
}

// defaultOrderBy có tie-breaker id. Thiếu nó, hai bản ghi cùng created_at có thể đổi
// chỗ giữa hai lần gọi, và phân trang sẽ lặp hoặc bỏ sót bản ghi.
const defaultOrderBy = "created_at DESC, id DESC"

// orderBy nhận chuỗi sort thô và trả mệnh đề ORDER BY dựng từ giá trị LẤY RA KHỎI
// whitelist. Biến ghép vào SQL là col, không phải sort — đặt hai tên khác nhau để chỗ
// này nhìn ra được khi review. Khóa lạ rơi về mặc định thay vì báo lỗi (R-12).
func orderBy(sort string) string {
	col, ok := orderSortable[strings.TrimPrefix(sort, "-")]
	if !ok {
		return defaultOrderBy
	}
	if strings.HasPrefix(sort, "-") {
		return col + " DESC, id DESC"
	}
	return col + " ASC, id ASC"
}
```

Ba điều kiện để đoạn trên là whitelist thật chứ chỉ có hình thức của whitelist:

1. Map khai **ở cấp package**, không dựng trong hàm từ dữ liệu bên ngoài.
2. Mọi cột trong map phải là cột thứ nhất hoặc thứ hai của ít nhất một index (R-09) — mở
   `sort` cho một cột không có index là mở một đường seq scan toàn bảng cho client.
3. `ORDER BY` luôn có **tie-breaker `id`**. Thiếu nó, thứ tự giữa các bản ghi trùng giá
   trị sắp xếp là không xác định, và cùng một bản ghi có thể xuất hiện ở cả trang 1 lẫn
   trang 2.

#### Struct bind query

```go
package response

// ListQuery là bộ tham số list chuẩn của R-12; handler bind bằng c.ShouldBindQuery(&q).
// Nó nằm cùng package với Meta vì hai thứ là hai nửa của một hợp đồng: giá trị đã
// chuẩn hóa ở đây phải là đúng giá trị xuất hiện lại trong meta của response.
type ListQuery struct {
	Page     int    `form:"page" binding:"omitempty,min=1"`
	PageSize int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	Sort     string `form:"sort"`
}

// Normalize chỉ điền mặc định cho tham số vắng mặt. Giá trị vượt biên (page_size 500)
// đã bị binding chặn và trả 422 từ trước, nên ở đây không có nhánh cắt ngọn im lặng.
func (q *ListQuery) Normalize() {
	if q.Page < 1 {
		q.Page = 1
	}
	if q.PageSize < 1 {
		q.PageSize = 20
	}
}

// Offset dịch page/page_size sang OFFSET của SQL.
func (q *ListQuery) Offset() int { return (q.Page - 1) * q.PageSize }
```

Struct query của từng endpoint **nhúng** `ListQuery` rồi thêm field lọc riêng, để ba tham
số chuẩn không bị khai lại mỗi nơi một kiểu.

#### Quy ước filter

```
GET /api/v1/orders?status=active&created_from=2026-01-01&created_to=2026-01-31&page=2&page_size=20&sort=-created_at
```

- **Tên filter là tên field**, phẳng, snake_case: `?status=active`. Không dùng cú pháp
  lồng kiểu `?filter[status][eq]=active` — nó đẩy việc phân tích cú pháp vào handler và
  mở đường cho toán tử tùy ý.
- **Khoảng giá trị dùng hậu tố `_from` và `_to`**, bao gồm cả hai đầu: `created_from` là
  `>=`, `created_to` là `<=`. Khi giá trị là ngày mà cột là `TIMESTAMPTZ`, `_to` được hiểu
  là **hết ngày đó** theo múi giờ hệ thống.
- **Nhiều giá trị cho một field thì lặp tham số**: `?status=draft&status=approved` nghĩa
  là `IN`. Không dùng chuỗi phân tách bằng dấu phẩy.
- **Tìm kiếm văn bản tự do dùng đúng một tham số `q`**, mỗi endpoint tự khai nó tìm trên
  những cột nào.
- Mọi giá trị filter đi vào SQL bằng **tham số bind `$n`**, không nối chuỗi. Whitelist của
  `sort` không áp cho filter vì tên filter đã là một field khai tĩnh trong struct query —
  field không khai thì không bind được.
- Filter không khớp bản ghi nào trả `200` với `data` rỗng.

Endpoint list được miễn phân trang chỉ khi nó trả **hằng số biên dịch được** — enum khai
ngay trong code Go, không truy vấn DB — và phải đăng ký ở bảng 3 của C-API-07.

---

### C-API-05 — Bảng mã lỗi nghiệp vụ

**Implements:** R-11

Mã lỗi có dạng `ERR_<DOMAIN>_<CASE>`, chữ hoa, phân tách bằng `_`. `<DOMAIN>` là tên module
viết hoa (`ORDER`, `INVENTORY`, `CUSTOMER`), hoặc `COMMON` cho lỗi dùng chung mọi module,
hoặc `AUTH` cho lỗi xác thực và phân quyền.

| Mã | HTTP | Thông điệp mặc định | Khi nào |
|---|---|---|---|
| `ERR_AUTH_UNAUTHENTICATED` | `401` | Phiên đăng nhập không hợp lệ hoặc đã hết hạn | Thiếu token, token sai chữ ký, token hết hạn |
| `ERR_AUTH_INVALID_CREDENTIALS` | `401` | Email hoặc mật khẩu không đúng | Đăng nhập sai email **hoặc** sai mật khẩu — hai ca dùng chung một mã và một thông điệp, xem ghi chú dưới bảng |
| `ERR_AUTH_FORBIDDEN` | `403` | Bạn không có quyền thực hiện thao tác này | Kiểm quyền ở service thất bại (R-15) |
| `ERR_AUTH_EMAIL_DUPLICATED` | `409` | Email đã được dùng trong công ty này | Tạo hoặc sửa user với email đã tồn tại trong **cùng** công ty — vi phạm `uq_users_email_active`. Cùng một email ở công ty khác thì hợp lệ |
| `ERR_AUTH_COMPANY_CODE_DUPLICATED` | `409` | Mã phân vùng đã được dùng | Tạo phân vùng với mã đã có ở một phân vùng còn sống - vi phạm `uq_companies_code` |
| `ERR_AUTH_COMPANY_IN_USE` | `409` | Phân vùng còn người dùng đang hoạt động, không vô hiệu hoá được | Vô hiệu hoá một phân vùng còn ít nhất một người dùng chưa bị xoá mềm |
| `ERR_COMMON_MALFORMED_REQUEST` | `400` | Dữ liệu gửi lên không đọc được | Thân JSON **chưa đọc được** vì sai cú pháp hoặc body rỗng; hoặc query param không ép được về kiểu của field (`page=abc`) — đường bind này tách riêng khỏi thân JSON và giữ nguyên `400`, cố ý ngoài phạm vi hợp đồng 422/400 dưới đây. Sai kiểu một field **bên trong** thân JSON không còn ở mã này — xem `ERR_COMMON_VALIDATION_FAILED`. **Không** kèm `error.fields` |
| `ERR_COMMON_NOT_FOUND` | `404` | Không tìm thấy bản ghi | Không có bản ghi, **hoặc** bản ghi thuộc công ty khác |
| `ERR_COMMON_VALIDATION_FAILED` | `422` | Dữ liệu gửi lên không hợp lệ | Sai hình dạng request — từ bind (`binding:"..."`, hoặc sai kiểu một field trong thân JSON) **hoặc** từ validate nghiệp vụ ở tầng service (`apperr.ValidationFailed`). Từ chặng E, cả hai nguồn đều kèm `error.fields`; trước đó chỉ nguồn bind có field |
| `ERR_COMMON_VERSION_CONFLICT` | `409` | Bản ghi đã được người khác cập nhật, hãy tải lại rồi thử lại | `updated_at` client gửi lên không khớp bản trong DB |
| `ERR_COMMON_IDEMPOTENCY_KEY_MISSING` | `422` | Thiếu header Idempotency-Key | Endpoint có tên ở bảng 5 của C-API-07 mà request không gửi header |
| `ERR_COMMON_IDEMPOTENCY_KEY_REUSED` | `422` | Idempotency-Key đã dùng cho một request có nội dung khác | Cùng khóa, payload khác (P-IDEM) |
| `ERR_COMMON_RATE_LIMITED` | `429` | Bạn thao tác quá nhanh, thử lại sau ít phút | Vượt hạn mức số lần gọi |
| `ERR_COMMON_SERVICE_UNAVAILABLE` | `503` | Dịch vụ chưa sẵn sàng | `/ready` không ping được database. Mã hạ tầng: người đọc nó là orchestrator, không phải client nghiệp vụ — xem ghi chú dưới bảng |
| `ERR_ORDER_NOT_FOUND` | `404` | Đơn hàng không tồn tại | `sql.ErrNoRows` ở endpoint chi tiết đơn hàng |
| `ERR_ORDER_CODE_DUPLICATED` | `409` | Mã đơn hàng đã tồn tại | Vi phạm `uq_orders_company_id_code` |
| `ERR_ORDER_STATUS_NOT_ALLOWED` | `409` | Trạng thái hiện tại không cho phép thao tác này | Duyệt một đơn đã hủy, sửa một đơn đã duyệt |
| `ERR_CUSTOMER_CREDIT_LIMIT_EXCEEDED` | `409` | Vượt hạn mức công nợ của khách hàng | Tổng công nợ sau thao tác vượt hạn mức đã cấp |
| `ERR_INVENTORY_STOCK_NOT_AVAILABLE` | `409` | Không đủ tồn kho | Giữ hàng thất bại vì không còn đủ số lượng |
| `ERR_MACHINE_CODE_DUPLICATED` | `409` | Mã đã tồn tại trong công ty này | Tạo hoặc sửa máy, hoặc kế hoạch bảo trì, với mã đã có trong **cùng** công ty — vi phạm `uq_machines_company_id_code` hoặc `uq_maintenance_plans_company_id_code`. Cùng một mã ở công ty khác thì hợp lệ |
| `ERR_MACHINE_STATUS_NOT_ALLOWED` | `409` | Trạng thái hiện tại không cho phép thao tác này | Cặp (trạng thái hiện tại, hành động) không có trong bảng chuyển trạng thái của kế hoạch bảo trì: bắt đầu một kế hoạch đang làm, hoàn thành một kế hoạch chưa bắt đầu, hủy một kế hoạch đã hoàn thành |
| `ERR_MACHINE_ASSIGNEE_INVALID` | `422` | Người phụ trách không hợp lệ | `assigned_to` không phải user còn hoạt động của cùng công ty. User thuộc công ty khác trả **cùng** mã này, không phải `404`: thứ không tồn tại ở đây là một giá trị trong body chứ không phải tài nguyên trên URL |
| `ERR_INVENTORY_CODE_DUPLICATED` | `409` | Mã đã tồn tại trong công ty này | Tạo hoặc sửa kho, hoặc vật tư, với mã đã có trong **cùng** công ty — vi phạm `uq_warehouses_company_id_code` hoặc `uq_stock_items_company_id_code` |
| `ERR_INVENTORY_INSUFFICIENT_STOCK` | `409` | Không đủ tồn kho | Chuyển động làm tồn của cặp (kho, vật tư) xuống dưới 0. `dieu_chinh` âm chịu cùng kiểm này — điều chỉnh xuống dưới 0 vẫn là tồn âm |
| `ERR_INVENTORY_UNIT_INVALID` | `422` | Đơn vị tính không hợp lệ | `unit_id` không phải một đơn vị tính còn sống |
| `ERR_INVENTORY_UNIT_CODE_DUPLICATED` | `409` | Mã đơn vị tính đã tồn tại | Tạo đơn vị tính với mã đã có — vi phạm `uq_units_code`. Mã **riêng** chứ không dùng `ERR_INVENTORY_CODE_DUPLICATED`: mã kia mang mệnh đề "trong cùng công ty này", mà `units` không có `company_id` nên một mã trùng là trùng với **toàn hệ** ([ADR-0022](../03-decisions/ADR-0022-mo-duong-ghi-cho-bang-units.md)) |
| `ERR_INVENTORY_ITEM_OR_WAREHOUSE_INVALID` | `422` | Vật tư hoặc kho không hợp lệ | `stock_item_id` hoặc `warehouse_id` không phải bản ghi còn sống **của công ty actor**. Bản ghi của công ty khác trả **cùng** mã này, không phải `404` — cùng lý do với `ERR_MACHINE_ASSIGNEE_INVALID` |
| `ERR_INTERNAL` | `500` | Lỗi hệ thống, vui lòng báo lại kèm mã request | Mọi lỗi kỹ thuật và lỗi lập trình |

Quy ước dùng bảng này:

- **Mã là hợp đồng, thông điệp thì không.** Client rẽ nhánh theo `error.code`; dùng chuỗi
  `message` làm khóa rẽ nhánh nghĩa là sửa một lỗi chính tả tiếng Việt cũng thành breaking
  change (P-ERR). Sửa `message` là việc không cần thông báo; đổi hoặc xóa một mã là
  breaking change và phải sang `/api/v2` (C-API-06). Thêm mã mới thì không.
- **Mọi mã khai thành hằng trong `shared/errors`**, không viết chuỗi trực tiếp ở handler
  hay service.
- **Thông điệp cấm chứa chi tiết nội bộ**: tên bảng, tên constraint, câu SQL, tên file.
  Những thứ đó đi vào log tra được theo `request_id` (R-17).
- **Mọi lỗi kỹ thuật ra client dưới đúng một mã `ERR_INTERNAL`** kèm `request_id`. Không
  tách mã theo loại lỗi kỹ thuật — client không làm gì được với sự khác biệt đó.
- **Lỗi nghiệp vụ log ở mức `Info`, không phải `Error`**: nó là hành vi bình thường của
  hệ thống.
- **`ERR_AUTH_INVALID_CREDENTIALS` dùng đúng một thông điệp cho cả sai email lẫn sai mật
  khẩu, và đó là chủ ý.** Tách hai ca thành "email không tồn tại" và "mật khẩu sai" là xác
  nhận với người ngoài rằng email nào có tồn tại trong hệ thống — một kênh dò tài khoản
  dùng được mà không cần đăng nhập nổi lần nào. Đây đúng là lý do khiến bản ghi của công ty
  khác trả `404` chứ không phải `403`
  ([../02-principles/P-ERR-error-handling.md](../02-principles/P-ERR-error-handling.md)).
  Thông điệp phải mờ như nhau, và thời gian trả lời cũng vậy: bỏ qua bước so mật khẩu khi
  không tìm thấy email là để lộ cùng thông tin đó qua độ trễ.
- **`ERR_COMMON_SERVICE_UNAVAILABLE` là mã hạ tầng, và nó là mã hạ tầng duy nhất.** Bảng
  này là bảng mã *nghiệp vụ*, nên một mã mà không client nghiệp vụ nào rẽ nhánh theo cần
  được giải thích chứ không được lặng lẽ nằm chung. Nó có mặt vì R-11 buộc **mọi** response
  đi qua envelope, mà envelope thì đòi một `code` — kể cả response `503` của `/ready`, thứ
  chỉ có readiness probe đọc và chỉ đọc mỗi status code. Thêm mã hạ tầng thứ hai phải sửa
  chính dòng này, đúng cách R-13 đóng danh sách ba endpoint hạ tầng.

#### Hợp đồng `422`/`400` sau chặng E

Viết thành một câu để không ai phải suy luận lại từ hai bảng ở trên: **`422` luôn có
`error.fields`; `400` không bao giờ có.** Trước chặng E câu đó sai ở cả hai vế; bốn thay đổi
dưới đây là lý do nó đúng từ chặng E:

- **`422` gồm cả lỗi bind lẫn lỗi validate tầng service.** Trước chặng E, chín call site gọi
  `apperr.ValidationFailed(code, message)` ở tầng service trả `422` **không kèm field**, vì
  `response.Error` chỉ đọc `Code`/`Message`/`HTTPStatus` của `*apperr.Error` — kiểu đó không
  có chỗ nào đựng field. Sau chặng E, `shared/errors` mang thêm một kiểu đựng field của
  riêng nó (package đó cấm import `shared/response`, vì service import `shared/errors` và
  R-03 cấm service phụ thuộc HTTP), và `response.Error` tự ánh xạ kiểu đó sang
  `response.FieldError` khi ghi envelope. Cả chín chỗ giờ đều gắn tên field.
- **Sai kiểu trong THÂN JSON ra `422` có field — với điều kiện `Field` đọc được.**
  `"repair_cost": 1500000` (số JSON thay vì chuỗi) và `"planned_date": "01/09/2026"` (sai
  định dạng) — trước chặng E cả hai ra `400` không field, vì `BindFailed` coi mọi lỗi
  không phải `validator.ValidationErrors` là `400`. Sau chặng E, `*json.UnmarshalTypeError`
  (ca `repair_cost`) ra `422` với field lấy từ thuộc tính `Field` sẵn có của chính lỗi đó;
  ca ngày tháng đi lối `planned_date`/`commissioned_date`/`occurred_at` bind thành
  `string`, handler tự parse và tự đặt tên field khi hỏng — cùng một khuôn xử lý cho cả ba,
  nhưng **không cùng một định dạng**: `occurred_at` là `TIMESTAMPTZ` (migration
  `000008_create_breakdowns`) nên chỉ nhận RFC 3339 đầy đủ, còn `planned_date` và
  `commissioned_date` nằm trên cột `DATE` nên nhận thêm dạng `"2026-09-01"` (xem C-API-02).
  Điều kiện:
  `*json.UnmarshalTypeError` cũng sinh ra khi cả thân request là mảng/chuỗi/số
  (`[1,2,3]`, `"chuoi"`, `123`) thay vì object — lúc
  đó `Field` là chuỗi rỗng vì lỗi nằm ở hình dạng của cả thân request, không ở một field
  nào, và ca đó **ở lại `400`** (xem C-API-02).
- **`400` co lại đúng nghĩa đen: JSON hỏng cú pháp, body rỗng, hoặc thân đọc được về cú
  pháp nhưng không phải object** (`UnmarshalTypeError` với `Field` rỗng). Không còn gì
  khác của thân JSON nằm trong `400`.
- **Query param sai kiểu (`page=abc`) vẫn là `400`** — cố ý ngoài phạm vi chặng này. Nó đi
  qua `ShouldBindQuery`, một đường bind khác thân JSON, sinh `*strconv.NumError` — kéo nó
  vào cùng hợp đồng `422` là mở rộng một thay đổi hợp đồng vốn đã đủ rộng.

**Nợ có tên: hai văn phạm khác nhau cho đường dẫn field của phần tử mảng.** `FieldErrors`
(C-API-03) hứa đường dẫn phần tử mảng có chỉ số — `items.0.quantity` — vì `validator` chạy
trên struct **đã bind xong**, nơi mỗi phần tử của slice có vị trí biết được qua
`Namespace()`. Nhưng `*json.UnmarshalTypeError.Field` không mang chỉ số: cùng một ô sai
kiểu nằm trong một mảng-của-object cho ra `items.quantity`, không phải
`items.0.quantity` — `Offset` của lỗi đó là vị trí byte trong chuỗi JSON, không phải chỉ số
phần tử, và suy chỉ số ra từ `Offset` là đoán chứ không phải đọc. Từ chặng E, cùng một ô có
thể ra hai văn phạm khác nhau tùy lỗi đến từ validator hay từ `encoding/json`. **Chưa có
hậu quả**: không DTO nào trong `machine`/`auth` hôm nay có mảng-của-object mang field kiểu
chặt (thứ duy nhất `UnmarshalTypeError` chạm được là field vô hướng). Nhưng nợ này phải có
tên trước khi có hậu quả — tức trước khi DTO đầu tiên dạng đó xuất hiện — và phải được đóng
bằng cách tìm ra cơ chế ghép chỉ số **thật** (nếu có), không phải bằng cách đoán từ
`Offset`.

Ánh xạ từ tên constraint sang mã lỗi (P-ERR: dịch theo **tên constraint**, không theo mã
lỗi PostgreSQL, vì `23505` một mình không nói được ràng buộc nào bị vi phạm):

| Constraint | Mã lỗi | HTTP | Field |
|---|---|---|---|
| `uq_orders_company_id_code` | `ERR_ORDER_CODE_DUPLICATED` | `409` | — |
| `ck_orders_status` | `ERR_COMMON_VALIDATION_FAILED` | `422` | — |
| `uq_users_email_active` | `ERR_AUTH_EMAIL_DUPLICATED` | `409` | — |
| `uq_companies_code` | `ERR_AUTH_COMPANY_CODE_DUPLICATED` | `409` | — |
| `uq_machines_company_id_code` | `ERR_MACHINE_CODE_DUPLICATED` | `409` | — |
| `uq_maintenance_plans_company_id_code` | `ERR_MACHINE_CODE_DUPLICATED` | `409` | — |
| `ck_machines_status` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `status`\* |
| `ck_maintenance_plans_status` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `status`\* |
| `ck_machines_kind` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `kind`\* |
| `ck_breakdowns_repair_cost_non_negative` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `repair_cost`\* |
| `uq_warehouses_company_id_code` | `ERR_INVENTORY_CODE_DUPLICATED` | `409` | — |
| `uq_stock_items_company_id_code` | `ERR_INVENTORY_CODE_DUPLICATED` | `409` | — |
| `uq_units_code` | `ERR_INVENTORY_UNIT_CODE_DUPLICATED` | `409` | — |
| `ck_stock_movements_kind` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `kind`\* |
| `ck_stock_movements_kind_sign` | `ERR_COMMON_VALIDATION_FAILED` | `422` | `quantity`\* |

\* Các dòng CHECK trên là hàng phòng thủ cuối trong hàm dịch vi phạm CHECK của module sở
hữu bảng (`dichViPhamCheck` ở `modules/machine/internal/service/errors.go` cho bốn dòng của
`machine`) — không đường chạy bình thường nào chạm tới chúng, vì service đã tự chặn giá trị
sai trước khi câu SQL chạy tới ràng buộc CHECK. Tên
field ở các dòng này là **ước lệ**: gán để `422` từ nhánh phòng thủ đó cũng có hình dạng
nhất quán với mọi `422` khác, không phải tên đã được xác nhận khớp chính xác input nào gây
ra lỗi. Comment tại chỗ trong `dichViPhamCheck` phải nói rõ điều này, để người sau không
tưởng nó chính xác.

Constraint chưa có trong bảng ánh xạ thì để lỗi đi tiếp nguyên trạng thành `ERR_INTERNAL`.
Đoán bừa cho ra thông điệp sai, và thông điệp sai khó gỡ hơn thông điệp chung chung. Bảng
ánh xạ này dài ra theo từng PR thêm unique index hoặc CHECK có ý nghĩa nghiệp vụ.

---

### C-API-06 — Quy tắc versioning

**Implements:** R-13

Mọi route nghiệp vụ nằm dưới `/api/v1`, đăng ký qua đúng một `router.Group("/api/v1")` ở
composition root. Ngoại lệ là danh sách đóng ba endpoint hạ tầng `/health`, `/ready`,
`/metrics`; thêm endpoint hạ tầng mới phải sửa chính R-13, không sửa mục này.

| Thay đổi | Breaking? | Phải làm gì |
|---|---|---|
| Xóa một field khỏi DTO response | **Có** | Sang `/api/v2` |
| Đổi kiểu dữ liệu của field response (`int` → `string`) | **Có** | Sang `/api/v2` |
| Đổi tên tag `json` của field response | **Có** | Sang `/api/v2` |
| Đổi ngữ nghĩa của field mà giữ nguyên tên và kiểu | **Có** | Sang `/api/v2` |
| Thêm field gắn `binding:"required"` vào DTO request đã tồn tại | **Có** | Sang `/api/v2` |
| Đổi hoặc xóa một mã lỗi (C-API-05) | **Có** | Sang `/api/v2` |
| Đổi status code trả về cho một tình huống đã có | **Có** | Sang `/api/v2` |
| Thêm field mới vào DTO response | Không | Merge bình thường |
| Thêm field **optional** vào DTO request | Không | Merge bình thường |
| Thêm endpoint mới | Không | Merge bình thường |
| Thêm mã lỗi mới | Không | Merge bình thường |
| Sửa chuỗi `message` của một mã lỗi | Không | Merge bình thường |
| Thêm giá trị mới vào một tập enum **trả về** | Không, nhưng phải báo | Ghi vào mô tả API và báo cho client |

Cách sang `v2`:

- Tạo `router.Group("/api/v2")` với handler và DTO **mới**, giữ nguyên toàn bộ handler và
  DTO của `/api/v1` cho tới khi client migrate xong.
- **DTO của `v2` nằm ở package riêng, không dùng chung struct với `v1`.** Dùng chung nghĩa
  là mọi lần sửa `v2` về sau lại rò sang `v1` — đúng thứ việc tách version sinh ra để ngăn.
- Chỉ version **những tài nguyên thật sự đổi**. Một thay đổi ở `/orders` không kéo theo
  `/customers` sang `v2`.
- Service và repository **không** version theo. Version là chuyện của lớp HTTP; nếu logic
  nghiệp vụ phải rẽ nhánh theo version thì thứ đang đổi là nghiệp vụ chứ không phải hợp
  đồng API, và đó là một quyết định cần ADR.
- Ngày tắt `/api/v1` không do file này quyết — nó là quyết định vận hành, cần một ADR.

Phía frontend: `/api/v1` khai đúng **một lần** ở base URL của HTTP client, không rải chuỗi
`/api/v1` vào từng lời gọi. Sang `v2` từng phần thì phần đó khai đường dẫn đầy đủ, phần
còn lại giữ base URL cũ.

---

### C-API-07 — Sổ đăng ký ngoại lệ

**Implements:** R-10, R-11, R-12, R-16

Năm bảng dưới đây là **sổ đăng ký**, không phải văn bản quy ước. Bốn Rule và một Principle
đều nói ngoại lệ của chúng "phải được ghi vào `04-conventions/C-API-http.md`" — đây là chỗ
ghi.

Ba quy tắc dùng sổ này:

1. **Ngoại lệ chỉ có hiệu lực khi có dòng trong bảng tương ứng.** Một endpoint dùng ngoại
   lệ mà không có tên ở đây là vi phạm chính Rule đó, không phải một thiếu sót giấy tờ.
2. **Thêm dòng là việc của chính PR tạo endpoint đó**, không phải việc dọn dẹp sau. PR
   thêm endpoint `/actions/<verb>` mà không thêm dòng vào bảng 1 là PR chưa xong, và
   **reviewer phải kiểm** — đây là mục dễ quên nhất vì Rule vẫn xanh khi grep.
3. **Xóa endpoint thì xóa dòng.** Một dòng trỏ tới endpoint không còn tồn tại là một ngoại
   lệ đang mở mà không ai canh.

Cột `Ngày duyệt` ghi theo dạng `YYYY-MM-DD`, là ngày PR chứa endpoint đó được merge.

Bảng 3 hiện **rỗng**. Rỗng nghĩa là chưa có ngoại lệ nào được duyệt — không phải quên
ghi.

#### 1. Endpoint hành động dạng `/actions/<verb>` — ngoại lệ R-10

R-10 cấm động từ trong path. Endpoint không map được vào CRUD dùng dạng
`POST /api/v1/<tai-nguyen>/:id/actions/<verb>` và phải có tên ở đây.

| Endpoint | Lý do | Ngày duyệt |
|---|---|---|
| `POST /api/v1/maintenance-plans/:id/actions/start` | Không tạo tài nguyên nào nên không phải `POST` tài nguyên, không thay toàn bộ bản ghi nên không phải `PUT`. Nó là **chuyển trạng thái** `ke_hoach` → `dang_lam`, kèm đổi `machines.status` sang `bao_tri` trong cùng transaction — thứ không diễn đạt được bằng một `PATCH` sửa field `status` | 2026-08-12 |
| `POST /api/v1/maintenance-plans/:id/actions/complete` | Cùng lý do: **chuyển trạng thái** `dang_lam` → `hoan_thanh` kèm trả máy về `hoat_dong` và đóng dấu `completed_at`. Cặp (trạng thái hiện tại, hành động) hợp lệ hay không do service quyết, không phải do client gửi lên giá trị `status` mới | 2026-08-12 |
| `POST /api/v1/maintenance-plans/:id/actions/cancel` | Cùng lý do: **chuyển trạng thái** sang `huy` từ `ke_hoach` hoặc `dang_lam`, và hiệu ứng kèm theo khác nhau tùy trạng thái xuất phát. Đó là một hành động nghiệp vụ chứ không phải một phép sửa field, và cũng không phải `DELETE` vì bản ghi vẫn sống | 2026-08-12 |

#### 2. Endpoint trả file, stream, hoặc bọc thẳng `http.Handler` ngoài, được miễn envelope — ngoại lệ R-11

R-11 buộc mọi response đi qua envelope của `shared/response`. Hai hình dạng được miễn:
handler gọi `c.File(`, `c.FileAttachment(`, `c.DataFromReader(`, hoặc `c.Stream(`; hoặc
handler bọc thẳng một `http.Handler` ngoài qua `gin.WrapH(`/`gin.WrapF(`. Cả hai đều đòi
**không** gọi `c.JSON(` trong cùng hàm. Endpoint được miễn vẫn phải trả header
`X-Request-Id` (R-17), vì nó không còn chỗ nào khác để mang `request_id`. Dòng đăng ký
của hình dạng `gin.WrapH`/`gin.WrapF` phải nêu rõ định dạng response bên thứ ba nào khiến
envelope không dùng được — cửa này rộng hơn bốn hình dạng kia vì `gin.WrapH` bọc được bất
kỳ `http.Handler` nào, nên lý do đăng ký phải cụ thể hơn một câu "cần dùng thư viện X".

| Endpoint | Lý do | Ngày duyệt |
|---|---|---|
| `GET /metrics` — `quanTrac.Handler()` (`shared/metrics`, dùng ở `cmd/api/router.go`) | Bọc `promhttp.HandlerFor(...)` qua `gin.WrapH(` — định dạng text của Prometheus có cú pháp riêng, không phải JSON, nên không mang được envelope `{data, error, meta, request_id}`; không scraper Prometheus nào đọc envelope. `/metrics` cũng nằm ngoài `/api/v1` theo danh sách đóng của R-13, nhưng đó là ngoại lệ về **tiền tố đường dẫn**, không phải ngoại lệ về **hình dạng response** — hai việc khác nhau, ngoại lệ này ghi riêng cho R-11 | 2026-08-14 |

#### 3. Endpoint list trả hằng số biên dịch được, miễn phân trang — ngoại lệ R-12

R-12 buộc mọi endpoint list nhận `page`, `page_size`, `sort` và trả `meta`. Chỉ endpoint
trả **hằng số biên dịch được** — enum khai ngay trong code Go, không truy vấn DB — mới
được miễn. Danh mục đọc từ bảng **không** thuộc diện này dù hôm nay chỉ có mười dòng.

| Endpoint | Lý do | Ngày duyệt |
|---|---|---|

Bảng trên hiện **rỗng**, và nó rỗng vì điều khoản tự huỷ của dòng duy nhất từng nằm ở đây
đã được thi hành.

Dòng đó miễn `GET /api/v1/roles`, với điều kiện là câu "không truy vấn DB" chứ không phải câu
"danh sách ngắn", và nó viết sẵn ngày hết hạn của chính mình: *ngày danh mục vai trò được đọc
từ một bảng — vai trò do người dùng tự định nghĩa — dòng này phải bị gỡ và endpoint phải nhận
đủ ba tham số, dù số dòng lúc đó vẫn là bảy.*

Ngày đó là **2026-08-22**, khi ADR-0023 đưa vai trò xuống database và ADR-0024 mục 5 chuyển
`GET /api/v1/roles` sang đọc bảng `roles`. Endpoint ấy nay nhận đủ `page`, `page_size`, `sort`
và trả `meta` như mọi endpoint list khác.

Giữ lại đoạn này chứ không xoá cùng dòng bảng: một ngoại lệ đã hết hạn đúng theo điều khoản
của chính nó là một tiền lệ đáng đọc, không phải một dòng cần dọn.

#### 4. DTO response được phép serialize token — ngoại lệ R-16

R-16 cấm serialize token, secret, password hash, số CCCD. Chỉ DTO response của endpoint
**cấp token** hoặc **làm mới token** được miễn. Dòng đăng ký phải nêu cả endpoint lẫn tên
struct DTO được miễn, vì thứ được miễn là struct chứ không phải đường dẫn.

| Endpoint | Lý do | Ngày duyệt |
|---|---|---|
| `POST /api/v1/auth/login` — struct `handler.TokenPairDTO` (`modules/auth/internal/handler/auth_handler.go`) | Endpoint **cấp token**: thân response mang `access_token` và `refresh_token`, không có đường nào khác trao chúng cho client | 2026-08-11 |
| `POST /api/v1/auth/refresh` — struct `handler.TokenPairDTO` (`modules/auth/internal/handler/auth_handler.go`) | Endpoint **làm mới token**: cùng struct với `/auth/login`, vì nó trả đúng một cặp token mới sau khi thu hồi cặp cũ | 2026-08-11 |

Hai dòng trên miễn đúng **một** struct. Mọi struct khác của module `auth` vẫn chịu R-16
đầy đủ: `service.TokenPair`, `service.LoginInput`, `service.RefreshInput`,
`service.LogoutInput` và `service.ChangePasswordInput` đều mang `json:"-"` trên field nhạy
cảm, và `model.RefreshToken.TokenHash` cũng vậy. Ngoại lệ này là về **đường ra tới
client**, không phải về tiện lợi khi viết struct.

#### 5. Endpoint bắt buộc nhận header `Idempotency-Key` — hard check của P-IDEM

Bảng này **không phải ngoại lệ mà là nghĩa vụ**: nó liệt kê endpoint bị siết chặt hơn mặc
định, không phải endpoint được nới. Theo
[../02-principles/P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md), mọi
handler `POST` sinh **bút toán tiền**, **chuyển động kho**, hoặc **cấp số chứng từ** phải
đọc header `Idempotency-Key`; thiếu header trả `422` với mã
`ERR_COMMON_IDEMPOTENCY_KEY_MISSING`. Endpoint có tên trong bảng này mà handler của nó
không chứa chuỗi `Idempotency-Key` là vi phạm.

Kèm theo, và đây là phần quyết định thành bại: **client sinh khóa lúc mở form**, không
phải lúc bấm nút, và giữ nguyên khóa đó qua mọi lần bấm lẫn mọi lần retry, chỉ đổi khi
người dùng bắt đầu một thao tác nghiệp vụ mới. Sinh lúc bấm nút thì mỗi lần bấm là một
khóa mới, và toàn bộ cơ chế chạy đúng mà vô dụng. Disable nút để chặn double-click là UX
tốt nhưng không thay thế được gì: nó không cứu được retry sau timeout, cũng không cứu được
người dùng bấm F5 rồi gửi lại form.

| Endpoint | Lý do | Ngày duyệt |
|---|---|---|
| `POST /api/v1/stock-movements` | Sinh **chuyển động kho** — mệnh đề thứ hai của P-IDEM, và đây là endpoint đầu tiên của hệ thống khớp nó. Gửi lại một lần xuất kho là xuất hai lần cùng một lô hàng, và dấu vết duy nhất là tồn kho ít đi đúng bằng số hàng chưa ai lấy: không màn hình nào đỏ. Ba ca ở mục "Idempotency" của C-API-02 thi hành được nhờ ba cột `request_hash`, `response_status`, `response_body` mà [ADR-0018](../03-decisions/ADR-0018-luu-response-cho-idempotency-key.md) chốt | 2026-08-15 |

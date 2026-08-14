# C-TS — Quy ước TypeScript frontend

Convention nằm **giữa** Rule và Code. Rule nói *"mọi response đi qua envelope"*; file này
nói *"hàm nào bóc envelope, component nhận được thứ gì"*. Rule trả lời **cái gì bắt buộc
đúng**, Convention trả lời **viết ra như thế nào**, cụ thể tới từng ký tự.

Vì vậy file này **không phải nguồn sự thật** cho bất cứ thứ gì Rule hay ADR đã quyết. Khi
nó lệch với [../01-rules/RULES.md](../01-rules/RULES.md) hoặc với
[C-API-http.md](C-API-http.md), bản gốc thắng và file này là thứ phải sửa.

Một điều cần nói trước, vì nó chi phối cả file: **frontend ở hệ thống này không có thẩm
quyền nghiệp vụ nào.** Nó không tính tiền, không quyết định trạng thái nào hợp lệ, không
quyết định ai được làm gì (R-19, ADR-0009). Thứ nó làm là trình bày dữ liệu backend trả về
và thu thập đầu vào thô để gửi lên. Mọi quy ước dưới đây là hệ quả của mệnh đề đó.

| Mục | Nội dung | Neo về |
|---|---|---|
| C-TS-01 | Bố cục module frontend | R-01 |
| C-TS-02 | Đặt tên component, hook, file | — |
| C-TS-03 | Quản lý state, ranh giới server state và client state | — |
| C-TS-04 | Gọi API và xử lý envelope | R-11, R-12 |
| C-TS-05 | Form, validate, hiển thị lỗi | R-11, R-19 |
| C-TS-06 | Hiển thị theo quyền | R-15, R-19 |

---

### C-TS-01 — Bố cục module frontend

**Implements:** R-01

Bố cục soi gương backend, và đó là chủ đích: một người đang sửa module `order` ở backend
tìm được đúng thứ tương ứng ở frontend mà không phải học một bản đồ thứ hai.

```text
src/modules/<a>/
├── api/          # hàm gọi HTTP + type DTO — thứ duy nhất module khác import
├── components/
├── hooks/
├── pages/
└── types.ts
```

| Thư mục | Chứa gì | Ai được import |
|---|---|---|
| `api/` | Hàm gọi HTTP của module (`listOrders`, `createOrder`) và type DTO đi kèm | Mọi module |
| `components/` | Component của riêng module | Chính module; module khác chỉ dùng component được export tường minh |
| `hooks/` | Hook bọc lời gọi `api/` và state của module | Chính module |
| `pages/` | Component gắn với một route | Chỉ router của app |
| `types.ts` | Type dùng chung trong module (không phải DTO) | Chính module |

#### Ranh giới module ở frontend cũng là ranh giới thật

Đây là chỗ dễ bị coi nhẹ nhất, vì hậu quả không hiện ra ngay. Module khác **chỉ** được
import từ `api/` và từ component được export tường minh; `hooks/`, `pages/` và phần bên
trong `components/` là chi tiết nội bộ.

Ba lý do, cùng ba lý do đã viết ra ở
[../01-rules/rules/R-01-module-boundary.md](../01-rules/rules/R-01-module-boundary.md) cho
backend, và chúng không đổi khi sang TypeScript:

- **Refactor nội bộ không được làm vỡ màn hình của người khác.** Nếu màn hình đơn hàng
  import thẳng `modules/customer/components/CustomerPicker/parts/Row`, thì team customer
  đổi cấu trúc thư mục nội bộ của họ là làm hỏng màn hình đơn hàng — và không ai biết cho
  tới lúc build đỏ.
- **`api/` là chỗ duy nhất hình dạng dữ liệu liên module được cam kết.** Nó ánh xạ đúng
  `modules/<A>/api/` bên Go, nên khi backend đổi DTO thì chỗ phải sửa ở frontend là một
  thư mục chứ không phải cả cây import.
- **Nó giữ đường lùi tách module.** ADR-0001 chọn modular monolith với khả năng tách module
  thành service riêng; một frontend bám vào ruột module khác thì tách được backend mà
  không tách được màn hình.

Khác biệt phải nói thẳng: **TypeScript không có `internal/` như Go.** Trình biên dịch Go từ
chối biên dịch một import vượt ranh giới; `tsc` thì không có cơ chế tương đương. Nghĩa là
toàn bộ ranh giới này do lint và review giữ, không có ai giữ hộ. Cách kiểm rẻ nhất là một
lệnh quét trên diff, đúng tinh thần lệnh grep của R-01:

```powershell
# Import xuyen module ma khong di qua api/
Get-ChildItem -Path src\modules -Recurse -Include *.ts, *.tsx | ForEach-Object {
    $file = $_.FullName
    $current = ($file -split '\\modules\\')[1] -split '\\' | Select-Object -First 1
    Select-String -Path $file -Pattern "@/modules/([a-z0-9-]+)/([a-z0-9-]+)" -AllMatches | ForEach-Object {
        $lineNo = $_.LineNumber
        foreach ($m in $_.Matches) {
            if ($m.Groups[1].Value -eq $current) { continue }
            if ($m.Groups[2].Value -eq 'api') { continue }
            "{0}:{1}: module '{2}' import '{3}' - module khac chi duoc import api/" -f $file, $lineNo, $current, $m.Value
        }
    }
}
```

#### Bố cục cả `src/`

```text
src/
├── app/              # router, provider, layout chung — biết mọi module
├── modules/
│   ├── order/
│   └── customer/
├── shared/
│   ├── api/          # http client, type envelope, ApiError (C-TS-04)
│   ├── components/   # component không mang nghiệp vụ: Button, Table, Modal
│   ├── hooks/
│   └── lib/          # hàm thuần: định dạng ngày, định dạng số
└── main.tsx
```

`src/app/` là composition root của frontend, ánh xạ đúng vai của `cmd/**` bên Go: nó là chỗ
duy nhất được biết mọi module cùng lúc, vì nó phải dựng bảng route.

`src/shared/` chịu đúng ràng buộc như `shared/` bên Go (R-04): **`shared/` cấm import
`modules/`**. Một `shared/components/Button` biết tới `modules/order` thì không còn dùng
chung được nữa, và mọi module kéo theo cây phụ thuộc của order mỗi lần vẽ một cái nút.

Alias `@/` trỏ tới `src/` và khai đúng một lần trong `tsconfig.json` cùng cấu hình bundler.
Không dùng đường dẫn tương đối vượt cấp (`../../../shared/api`): nó vừa khó đọc vừa khiến
mọi lệnh quét ranh giới ở trên vô dụng.

---

### C-TS-02 — Đặt tên component, hook, file

**Implements:** —

| Loại | Quy ước tên | Tên file | Ví dụ |
|---|---|---|---|
| Component | PascalCase | Trùng tên component, đuôi `.tsx` | `OrderList` → `OrderList.tsx` |
| Hook | `use<Ten>`, camelCase | kebab-case, đuôi `.ts` | `useOrderList` → `use-order-list.ts` |
| Module hàm thuần | camelCase cho hàm | kebab-case, đuôi `.ts` | `formatMoney` → `format-money.ts` |
| Hàm gọi API | camelCase, động từ + đối tượng | kebab-case | `listOrders` → `order-api.ts` |
| Thư mục | kebab-case | — | `src/modules/work-order/` |
| Type / interface | PascalCase, **không** tiền tố `I` | — | `Order`, `CreateOrderInput` |
| Hằng cấp module | SCREAMING_SNAKE_CASE | — | `DEFAULT_PAGE_SIZE` |
| Test | trùng tên thứ được test | `<ten>.test.ts(x)` | `use-order-list.test.ts` |

Hai quy ước tên file trông không nhất quán và đó là cố ý:

- **File component trùng tên component** vì tên đó là thứ xuất hiện trong JSX ở mọi nơi
  khác. `OrderList.tsx` cho phép tìm định nghĩa của `<OrderList />` bằng đúng chuỗi đang
  nhìn thấy trên màn hình.
- **Mọi file còn lại kebab-case** vì chúng không có một danh tính PascalCase để khớp, và
  kebab-case tránh hẳn lớp lỗi do hệ thống file phân biệt hoa thường trên Linux mà không
  phân biệt trên Windows/macOS — `useOrderList.ts` với `useorderlist.ts` là hai file khác
  nhau trên CI và là một file trên máy dev.

Quy ước còn lại:

- **Một component một file.** Component phụ chỉ dùng trong file đó thì ở lại file đó và
  không export; cần dùng ở nơi khác thì tách ra file riêng.
- **Prop nhận hàm đặt tên `on<Su kien>`; hàm xử lý bên trong đặt tên `handle<Su kien>`**:
  `<OrderRow onApprove={handleApprove} />`. Nhìn tên là biết đang ở phía nào của ranh giới.
- **Prop boolean đặt tên khẳng định**: `isDisabled`, `hasError`, `canApprove` — không
  `isNotReady`.
- **Type DTO giữ nguyên `snake_case` đúng như tag `json` của backend**: `total_amount`,
  `page_size`, `created_at`. Đổi sang camelCase nghĩa là dựng thêm một lớp ánh xạ phải bảo
  trì thủ công, và một field bị quên trong lớp đó không thành lỗi biên dịch — nó thành một
  ô trống trên màn hình. Chuyển đổi tên chỉ xảy ra ở lớp trình bày nếu thật sự cần, không
  xảy ra ở `api/`.
- **Hook trả về object có tên field, không trả tuple** khi có từ ba giá trị trở lên: người
  gọi không phải nhớ thứ tự.

---

### C-TS-03 — Quản lý state, ranh giới server state và client state

**Implements:** —

Mọi state trên màn hình thuộc đúng một trong hai loại, và trả lời sai câu hỏi phân loại
này là nguồn của phần lớn lỗi "màn hình hiện số cũ".

| | Server state | Client state |
|---|---|---|
| Là gì | Dữ liệu đến từ API | Trạng thái của giao diện |
| Ai sở hữu | Backend | Chính component |
| Có cũ đi được không | **Có** — người khác sửa được nó | Không |
| Ví dụ | Danh sách đơn hàng, chi tiết một đơn, danh mục sản phẩm | Modal đang mở, tab đang chọn, ô tìm kiếm chưa bấm áp dụng, bước wizard |
| Quản lý bằng | Thư viện data-fetching có cache | `useState` / `useReducer` cục bộ |
| Cần gì | Cache key, invalidate, refetch, trạng thái loading/error | Không cần gì |

Câu hỏi phân loại đúng chỉ có một: **"nếu người khác sửa thứ này lúc tôi đang mở màn hình,
màn hình tôi có sai không?"** Trả lời "có" thì đó là server state.

> Việc chọn thư viện data-fetching cụ thể chưa có ADR. Ví dụ dưới đây dùng API của TanStack
> Query để code đọc được; mọi mệnh đề bắt buộc ở mục này đều diễn đạt được với thư viện
> tương đương.

#### Cấm chép server state vào client state rồi tự đồng bộ

```tsx
// SAI: chép dữ liệu từ cache ra một bản state thứ hai rồi tự giữ cho hai bản khớp nhau.
function OrderListWrong() {
  const { data } = useQuery({ queryKey: ['orders'], queryFn: () => listOrders({}) });

  // Bản sao thứ hai của cùng một sự thật.
  const [orders, setOrders] = useState<Order[]>([]);

  useEffect(() => {
    if (data) setOrders(data.items);
  }, [data]);

  const approve = useMutation({
    mutationFn: approveOrder,
    onSuccess: () => {
      // Cache được làm mới ở đây...
      queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });

  // ...nhưng `orders` thì không. Nó chỉ đổi khi useEffect ở trên chạy lại, và nó chỉ
  // chạy lại khi tham chiếu `data` đổi. Mọi đường làm mới cache không đi qua đúng
  // nhánh đó — refetch nền, cập nhật lạc quan, một tab khác của chính app — đều để
  // lại một `orders` cũ trên màn hình, không có lỗi nào, không có cảnh báo nào.
  return <Table rows={orders} onApprove={approve.mutate} />;
}
```

```tsx
// ĐÚNG: đọc thẳng từ cache. Không có bản sao thứ hai thì không có gì để lệch.
function OrderList() {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ['orders'],
    queryFn: () => listOrders({}),
  });

  const approve = useMutation({
    mutationFn: approveOrder,
    // invalidateQueries chứ không setState: nó bảo cache "dữ liệu này cũ rồi", và mọi
    // component đang đọc cùng khóa đó cùng thấy dữ liệu mới. Đúng một nguồn sự thật.
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  });

  if (isLoading) return <Spinner />;
  if (error) return <ErrorBanner error={error} />;

  return <Table rows={data?.items ?? []} onApprove={approve.mutate} />;
}
```

Lý do lệnh cấm này đáng đứng ngang hàng với các quy ước khác: hỏng của nó **không báo
lỗi**. Không exception, không màn hình trắng, không dòng log. Nó chỉ hiện ra dưới dạng
người dùng vừa sửa xong một đơn hàng, quay lại danh sách, và thấy con số cũ — rồi sửa lại
lần nữa. Trong một hệ ERP, thứ đó không dừng ở khó chịu: nó là hai bút toán cho một nghiệp
vụ.

#### Ba quy ước kèm theo

**1. Cache key khai theo dữ liệu, không theo màn hình.** Khóa gồm tên tài nguyên và toàn
bộ tham số ảnh hưởng tới kết quả:

```ts
const orderKeys = {
  all: ['orders'] as const,
  list: (params: ListParams) => ['orders', 'list', params] as const,
  detail: (id: string) => ['orders', 'detail', id] as const,
};
```

Khóa đặt theo màn hình (`['order-page']`) thì hai màn hình cùng đọc một tài nguyên có hai
cache riêng, và làm mới cái này không làm mới cái kia — đúng lại bài toán vừa cấm ở trên,
chỉ khác chỗ đứng.

**2. State dẫn xuất thì tính lúc render, không lưu.** Tổng số dòng đang chọn, nhãn hiển thị
của một trạng thái, danh sách đã lọc theo ô tìm kiếm — tính từ state gốc mỗi lần render.
Lưu nó vào `useState` là tạo ra một bản sao thứ hai, y hệt lỗi ở trên.

**3. Bộ lọc và phân trang sống ở URL, không ở `useState`.** `page`, `page_size`, `sort` và
các filter là thứ người dùng mong giữ được khi bấm F5 hoặc gửi link cho đồng nghiệp; giữ
chúng trong state cục bộ là mất cả hai. Tên tham số trên URL trùng đúng tên tham số API
(C-API-04), nên không có lớp dịch nào ở giữa.

Client state chỉ lên `context` khi thật sự nhiều nhánh xa nhau cùng cần — phiên đăng nhập,
theme, ngôn ngữ. Đưa state của một form vào context để "khỏi truyền prop" là biến một thứ
cục bộ thành thứ toàn cục, và mỗi lần gõ một ký tự lại vẽ lại nửa cây component.

---

### C-TS-04 — Gọi API và xử lý envelope

**Implements:** R-11, R-12

Mọi response của hệ thống này đi qua đúng một envelope `{data, error, meta, request_id}`
(C-API-03). Quy ước ở đây có một mệnh đề trung tâm: **envelope bị bóc đúng một lần, ở lớp
client dùng chung. Component không bao giờ nhìn thấy nó.**

#### Type khớp envelope của C-API-03

```ts
// src/shared/api/types.ts

// FieldError chỉ xuất hiện ở lỗi validate 422. `field` là ĐƯỜNG DẪN tới field trong
// body request, đúng tên tag json, phần tử mảng đánh chỉ số từ 0: "items.0.quantity".
export interface FieldError {
  field: string;
  message: string;
}

// ApiErrorBody là khối `error` của envelope. Client rẽ nhánh theo `code`, không theo
// `message`: lấy chuỗi thông điệp làm khóa rẽ nhánh thì backend sửa một lỗi chính tả
// tiếng Việt cũng thành breaking change (C-API-05).
export interface ApiErrorBody {
  code: string;
  message: string;
  fields?: FieldError[];
}

// Meta là khối phân trang, CHỈ có ở response list (R-12).
export interface Meta {
  total: number;
  page: number;
  page_size: number;
}

// Envelope là thân JSON của mọi response. Đúng một trong hai field `data` và `error`
// có mặt; `meta` chỉ có ở response list; `request_id` có ở MỌI response, kể cả thành
// công — nên nó là field duy nhất không optional.
export interface Envelope<T> {
  data?: T;
  meta?: Meta;
  error?: ApiErrorBody;
  request_id: string;
}

// Page<T> là thứ tầng trên nhận cho một response list: danh sách đã bóc kèm meta.
export interface Page<T> {
  items: T[];
  meta: Meta;
}

export interface ListParams {
  page?: number;
  page_size?: number;
  sort?: string;
  filters?: Record<string, string | number | Array<string | number> | undefined>;
}
```

Ba chi tiết của type trên bám sát C-API-03 và không được nới:

- **`request_id` không optional.** Backend gắn nó vào mọi response, và nó là thứ người dùng
  đọc cho tổng đài khi gặp lỗi (R-17). Khai nó optional là mở đường cho giao diện lỗi không
  hiển thị mã tra cứu.
- **`data?: T` là optional vì response lỗi không có `data`** — không phải vì response thành
  công có thể thiếu nó.
- **`meta` nằm ở cấp envelope, không nằm trong `data`.** Đặt sai chỗ thì mọi type response
  list phải khai lại hình dạng phân trang.

#### Client dùng chung — chỗ duy nhất envelope bị bóc

```ts
// src/shared/api/client.ts
import type { ApiErrorBody, Envelope, FieldError, ListParams, Meta, Page } from './types';

// /api/v1 khai ĐÚNG MỘT LẦN ở đây, không rải vào từng lời gọi (C-API-06). Sang v2 từng
// phần thì phần đó khai đường dẫn đầy đủ, phần còn lại giữ nguyên base URL này.
//
// Origin cua backend doc tu bien moi truong `VITE_API_ORIGIN` (Vite bat buoc tien to
// VITE_), mac dinh http://localhost:8080. TEN BIEN NAY LA HOP DONG - dat ten khac o repo
// khac se cho ra hai ten cho mot thu.
//
// Vi sao khong dung duong dan tuong doi + server.proxy cua Vite: proxy bien moi thu thanh
// same-origin o dev, nen middleware CORS cua backend khong bao gio duoc thu cho toi luc
// len production. Origin cau hinh duoc thi cross-origin la that ngay tu may dev.
const API_ORIGIN = (import.meta.env.VITE_API_ORIGIN ?? '').trim().replace(/\/+$/, '') || 'http://localhost:8080';
const BASE_URL = `${API_ORIGIN}/api/v1`;

// ApiError mang trọn thông tin lỗi từ envelope. Tầng trên rẽ nhánh theo `status` và
// `code`; `requestId` đi vào thông báo lỗi để người dùng đọc cho tổng đài (R-17).
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly fields: FieldError[] = [],
    readonly requestId = '',
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function call<T>(path: string, init: RequestInit = {}): Promise<Envelope<T>> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init.headers ?? {}) },
  });

  // request_id đọc từ HEADER trước: header là đường chính thức, bản trong envelope chỉ
  // là tiện ích và không tồn tại ở 204 lẫn ở endpoint trả file (C-API-03, R-17).
  const headerRequestId = res.headers.get('X-Request-Id') ?? '';

  // 204 không có body (C-API-02). Gọi res.json() ở đây là ném một lỗi parse và che mất
  // một thao tác đã thành công.
  if (res.status === 204) {
    return { request_id: headerRequestId };
  }

  const body = (await res.json()) as Envelope<T>;
  const requestId = body.request_id || headerRequestId;

  if (!res.ok) {
    // Lỗi không có khối `error` là lỗi từ tầng dưới backend (proxy, load balancer):
    // vẫn phải thành một ApiError có mã, không được thành một exception trần.
    const e: ApiErrorBody = body.error ?? { code: 'ERR_INTERNAL', message: 'Lỗi hệ thống' };
    throw new ApiError(res.status, e.code, e.message, e.fields ?? [], requestId);
  }

  return { ...body, request_id: requestId };
}

// getOne trả về THÂN dữ liệu đã bóc. Đây là điểm mấu chốt của cả mục: component nhận
// `Order`, không nhận `Envelope<Order>`, và không nơi nào ngoài file này viết `.data`.
export async function getOne<T>(path: string): Promise<T> {
  const env = await call<T>(path);
  return env.data as T;
}

export async function send<T>(
  method: 'POST' | 'PUT' | 'PATCH',
  path: string,
  body: unknown,
  extraHeaders: Record<string, string> = {},
): Promise<T> {
  const env = await call<T>(path, { method, body: JSON.stringify(body), headers: extraHeaders });
  return env.data as T;
}

export async function remove(path: string): Promise<void> {
  await call<never>(path, { method: 'DELETE' });
}

// getList dựng query string theo đúng quy ước C-API-04 và trả về { items, meta }.
export async function getList<T>(path: string, params: ListParams): Promise<Page<T>> {
  const page = params.page ?? 1;
  const pageSize = params.page_size ?? 20;

  const qs = new URLSearchParams();
  qs.set('page', String(page));
  qs.set('page_size', String(pageSize));
  if (params.sort) qs.set('sort', params.sort);

  for (const [key, value] of Object.entries(params.filters ?? {})) {
    // Nhiều giá trị cho một field thì LẶP tham số, không nối bằng dấu phẩy (C-API-04).
    for (const one of Array.isArray(value) ? value : [value]) {
      if (one !== undefined && one !== '') qs.append(key, String(one));
    }
  }

  const env = await call<T[]>(`${path}?${qs.toString()}`);

  // Danh sách rỗng là `data: []` và `meta.total: 0`, không phải null và không phải 404
  // (C-API-03). Hai toán tử ?? dưới đây là lưới an toàn cho ca backend lỗi, không phải
  // chỗ cho phép backend trả null.
  const meta: Meta = env.meta ?? { total: 0, page, page_size: pageSize };
  return { items: env.data ?? [], meta };
}
```

#### `api/` của module chỉ gọi client, không tự fetch

```ts
// src/modules/order/api/order-api.ts
import { getList, getOne, send } from '@/shared/api/client';
import type { ListParams, Page } from '@/shared/api/types';

// total_amount là CHUỖI, không phải number: cột là NUMERIC(18,4) và ép nó về number là
// đưa nó qua double của JavaScript — đúng sai số mà NUMERIC sinh ra để tránh
// (C-API-03, C-DB-02). Định dạng để hiển thị làm ở lớp trình bày, từ chuỗi này.
//
// allowed_actions do backend trả về và là thứ duy nhất frontend dùng để bật/tắt nút
// (C-TS-06).
export interface Order {
  id: string;
  code: string;
  status: string;
  total_amount: string;
  created_at: string;
  allowed_actions: string[];
}

export interface CreateOrderInput {
  customer_id: string;
  code: string;
  items: Array<{ product_id: string; quantity: number; unit_price: string }>;
}

export function listOrders(params: ListParams): Promise<Page<Order>> {
  return getList<Order>('/orders', params);
}

export function getOrder(id: string): Promise<Order> {
  return getOne<Order>(`/orders/${id}`);
}

export function createOrder(input: CreateOrderInput, idempotencyKey?: string): Promise<Order> {
  const headers = idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {};
  return send<Order>('POST', '/orders', input, headers);
}
```

#### Hook đọc danh sách — nơi `meta` được dùng

```ts
// src/modules/order/hooks/use-order-list.ts
import { useQuery } from '@tanstack/react-query';

import { listOrders } from '../api/order-api';
import type { ListParams } from '@/shared/api/types';

export function useOrderList(params: ListParams) {
  return useQuery({
    queryKey: ['orders', 'list', params],
    queryFn: () => listOrders(params),
    // Giữ trang cũ trên màn hình trong lúc trang mới đang tải, thay vì nháy về rỗng.
    placeholderData: (prev) => prev,
  });
}
```

Component phân trang đọc `data.meta.total`, `data.meta.page`, `data.meta.page_size` —
đúng ba field mà R-12 bắt backend trả về. Nó **không** tự suy ra tổng số trang từ độ dài
mảng: mảng chỉ chứa một trang.

#### Bốn điều cấm, cả bốn đều grep được

| Cấm | Vì sao |
|---|---|
| `res.data.data` hay bất cứ chỗ nào ngoài `client.ts` chạm vào `.data` của envelope | Envelope bóc đúng một lần; hai chỗ bóc là hai chỗ phải sửa khi C-API-03 đổi |
| Gọi thẳng `fetch(` hoặc `axios(` ngoài `src/shared/api/` | Bỏ qua base URL, bỏ qua bóc envelope, bỏ qua `ApiError`, bỏ qua `request_id` |
| Viết chuỗi `'/api/v1'` ngoài `client.ts` | C-API-06 đòi tiền tố version khai đúng một lần |
| Trả `any` từ hàm trong `api/` | Type DTO là chỗ duy nhất frontend biết hình dạng dữ liệu backend; `any` xóa nó đi |

**Ngoại lệ khi kiểm bằng máy — đường lên `v2` không bị bắt oan.** Luật ESLint canh dòng cấm
`/api/v1` ở trên (`c-ts-04-base-url-once`, [ADR-0012](../03-decisions/ADR-0012-r19-canh-o-frontend-eslint.md))
chỉ khớp đúng chuỗi `/api/v1`, không khớp mọi đường dẫn đầy đủ bắt đầu bằng `/api/`. C-API-06
đã chừa sẵn đường sang `v2` từng phần: *"Sang v2 từng phần thì phần đó khai đường dẫn đầy
đủ, phần còn lại giữ base URL cũ."* Một file `api/` viết `/api/v2/orders` cho một tài nguyên
đã version không vi phạm gì; chỉ `/api/v1` viết tay ngoài `client.ts` mới đỏ. Luật viết chặt
theo đúng chuỗi `/api/v1`, không phải theo tiền tố `/api/v`, để không bắt oan `v2`.

---

### C-TS-05 — Form, validate, hiển thị lỗi

**Implements:** R-11, R-19

#### Validate ở frontend chỉ là UX

Frontend được validate đúng ba nhóm, và chúng có chung một tính chất: **nhìn vào riêng ô
nhập là trả lời được, không cần biết gì về nghiệp vụ hay dữ liệu trong database.**

| Được validate | Ví dụ |
|---|---|
| Bắt buộc | "Mã đơn không được để trống" |
| Định dạng | Email, số điện thoại, ngày theo RFC 3339, chuỗi phải là số |
| Độ dài và biên hiển nhiên | Mã tối đa 32 ký tự, số lượng phải lớn hơn 0 |

Mọi thứ ngoài ba nhóm đó là nghiệp vụ, và nghiệp vụ ở backend (R-19, ADR-0009). Frontend
**không** kiểm "đơn đã duyệt thì không sửa được", **không** kiểm "vượt hạn mức công nợ",
**không** kiểm "còn đủ tồn kho". Ba câu đó đều cần đọc database mới trả lời được, và câu
trả lời hợp lệ lúc 10h có thể sai lúc 10h01 (C-API-02).

Ba nhóm được phép ở trên **cũng phải có bản backend**. Validate frontend là để người dùng
biết ngay mà không phải chờ round-trip, không phải để thay thế kiểm tra thật.

#### Cấm gửi con số do frontend tính

Đây là vế cụ thể nhất của R-19, và cũng là vế dễ vi phạm nhất vì nó trông rất tiện.

```ts
// SAI: frontend tính rồi gửi kết quả lên server.
async function submitWrong(items: Array<{ quantity: number; unit_price: number }>) {
  const subtotal = items.reduce((s, it) => s + it.quantity * it.unit_price, 0);
  const tax = subtotal * 0.08;

  await createOrder({
    customer_id: 'c-1',
    code: 'PO-001',
    items: [],
    // Ba field dưới đây là ba quy tắc nghiệp vụ đã bị chép sang frontend: cách tính
    // thành tiền, thuế suất, và cách làm tròn. Chúng sẽ lệch với backend — không phải
    // "nếu" mà là "khi nào" — và lúc đó không có bên nào báo lỗi: đơn hàng chỉ đơn
    // giản mang một con số sai vào sổ.
    subtotal,
    tax_amount: tax,
    total_amount: subtotal + tax,
  } as never);
}
```

```tsx
// ĐÚNG: gửi ĐẦU VÀO THÔ, hiển thị tạm tính, render lại con số backend trả về.
function OrderForm() {
  const [items, setItems] = useState<ItemRow[]>([]);

  // Tạm tính để NHÌN. Hiển thị con số này lên màn hình là UX chuẩn mực và R-19 nói rõ
  // nó không vi phạm — người nhập đơn cần thấy tiền ngay khi gõ số lượng. Ranh giới
  // nằm ở chỗ khác: con số này không bao giờ đi vào body của một request.
  const preview = items.reduce((sum, it) => sum + it.quantity * Number(it.unit_price), 0);

  const create = useMutation({
    mutationFn: (input: CreateOrderInput) => createOrder(input, idempotencyKey),
  });

  async function handleSubmit() {
    // Body chỉ có đầu vào thô: product_id, quantity, unit_price.
    const saved = await create.mutateAsync({
      customer_id: customerId,
      code,
      items: items.map((it) => ({
        product_id: it.product_id,
        quantity: it.quantity,
        unit_price: it.unit_price,
      })),
    });

    // Con số hiển thị sau khi lưu là con số BACKEND trả về, không phải `preview`.
    // Hai giá trị lệch nhau nghĩa là backend có một quy tắc mà frontend chưa biết —
    // và đúng như vậy mới là hệ thống chạy đúng.
    setSavedTotal(saved.total_amount);
  }

  return (
    <form onSubmit={handleSubmit}>
      <ItemTable rows={items} onChange={setItems} />
      <div>Tạm tính: {formatMoney(preview)}</div>
      <button type="submit">Lưu</button>
    </form>
  );
}
```

Ranh giới nói lại cho gọn: **hiển thị tạm tính trên màn hình được phép; gửi con số đó lên
server thì không.** Dấu hiệu vi phạm cũng chính là chỗ để tìm khi review: kết quả một phép
tính tiền, thuế hay tồn kho xuất hiện trong body của một `POST`/`PUT`/`PATCH`.

Hệ quả kèm theo: **cấm bảng chuyển trạng thái hardcode ở frontend.** Một
`const NEXT_STATUSES = { pending: ['approved', 'rejected'] }` dùng để quyết định bật nút là
đúng thứ R-19 cấm — xem C-TS-06.

#### Hiển thị lỗi 422 — map `error.fields` sang từng ô

`422` mang danh sách `error.fields`, mỗi phần tử có `field` là **đường dẫn** tới ô trong
body request (`code`, `items.0.quantity`) và `message` là câu để hiển thị (C-API-03). Đó
đúng là thứ form cần để highlight đúng ô.

```ts
// src/shared/api/form-errors.ts
import { ApiError } from './client';

export interface FormErrorResult {
  // Lỗi gắn được vào một ô cụ thể của form.
  fieldErrors: Array<{ path: string; message: string }>;
  // Lỗi không gắn được vào ô nào — hiển thị ở banner đầu form. KHÔNG được nuốt: một
  // field lỗi mà không hiện ở đâu cả là người dùng bấm Lưu mãi không được và không
  // hiểu vì sao.
  formMessage: string | null;
  // true khi dữ liệu trên màn hình đã cũ và phải tải lại (409), không phải khi sai ô.
  shouldReload: boolean;
}

export function toFormErrors(err: unknown, knownPaths: ReadonlySet<string>): FormErrorResult {
  if (!(err instanceof ApiError)) {
    // Khong phai ApiError nghia la request khong bao gio toi duoc may chu: mat mang,
    // backend chua len, hoac CORS chan o preflight. Ba nguyen nhan, MOT hanh dong sua
    // giong nhau - nen thong diep noi ra hanh dong do, khong noi "khong xac dinh".
    return { fieldErrors: [], formMessage: 'Khong ket noi duoc toi may chu', shouldReload: false };
  }

  // 422: sai HÌNH DẠNG request. Giữ nguyên form, highlight từng ô (C-API-02).
  if (err.status === 422) {
    const fieldErrors: Array<{ path: string; message: string }> = [];
    const leftover: string[] = [];
    for (const f of err.fields) {
      if (knownPaths.has(f.field)) fieldErrors.push({ path: f.field, message: f.message });
      else leftover.push(`${f.field}: ${f.message}`);
    }
    return {
      fieldErrors,
      formMessage: leftover.length > 0 ? leftover.join('; ') : null,
      shouldReload: false,
    };
  }

  // 409: sai TRẠNG THÁI — mã trùng, đơn đã duyệt, hết tồn. Không có ô nào để highlight;
  // thứ đang hiển thị trên màn hình đã cũ nên phải tải lại (C-API-02).
  if (err.status === 409) {
    return { fieldErrors: [], formMessage: err.message, shouldReload: true };
  }

  // Còn lại: kèm requestId vào thông điệp để người dùng đọc cho tổng đài (R-17).
  const suffix = err.requestId ? ` (mã tra cứu: ${err.requestId})` : '';
  return { fieldErrors: [], formMessage: `${err.message}${suffix}`, shouldReload: false };
}
```

Ba quy tắc rút ra từ đoạn trên:

1. **Rẽ nhánh theo `status` và `error.code`, không theo `error.message`.** Thông điệp là
   chuỗi tiếng Việt backend được phép sửa bất cứ lúc nào mà không báo (C-API-06); mã thì
   không (C-API-05).
2. **`422` giữ form, `409` tải lại dữ liệu.** Trộn hai loại vào một cách xử lý là bắt người
   dùng đoán xem họ nên sửa ô nào hay nên bấm F5.
3. **Không nuốt field lạ.** Backend trả một `field` mà form không có ô tương ứng — thường là
   do form và DTO đã lệch nhau — thì đẩy lên banner. Bỏ qua im lặng là dựng một nút Lưu
   không bao giờ chạy được và không bao giờ nói vì sao.

#### `Idempotency-Key` sinh lúc mở form

Với endpoint có tên ở bảng 5 của C-API-07 — POST sinh bút toán tiền, chuyển động kho, hoặc
cấp số chứng từ — client phải gửi header `Idempotency-Key`, và **khóa sinh lúc mở form,
không phải lúc bấm nút**:

```ts
// Sinh MỘT lần khi component mount và giữ nguyên qua mọi lần bấm lẫn mọi lần retry.
// Sinh lúc bấm nút thì mỗi lần bấm là một khóa mới, và toàn bộ cơ chế chạy đúng mà vô
// dụng. Disable nút để chặn double-click là UX tốt nhưng không thay thế được: nó không
// cứu được retry sau timeout, cũng không cứu được người dùng bấm F5 rồi gửi lại form.
const idempotencyKeyRef = useRef(crypto.randomUUID());
```

Khóa chỉ đổi khi người dùng bắt đầu một thao tác nghiệp vụ **mới** — mở form trắng lần
nữa, không phải sửa lại một ô rồi gửi lại.

**Nợ có tên: backend chưa thi hành `Idempotency-Key` trên bất kỳ route HTTP nào.**
`shared/idempotency` tồn tại ở backend nhưng chỉ phục vụ consumer outbox nội bộ — không
handler nào đọc header đó, và bảng 5 của C-API-07 (endpoint bắt buộc nhận header) đang
**rỗng**. Frontend vẫn sinh và gửi `Idempotency-Key` đúng quy ước ở trên, nhưng cho tới khi
có endpoint đọc và validate nó, header đó không chặn được double-submit hay retry trùng ở
phía server — nó đi vào request và bị bỏ qua. Hình dạng đúng của việc đóng nợ này là backend
thi hành, không phải frontend ngừng gửi.

---

### C-TS-06 — Hiển thị theo quyền

**Implements:** R-15, R-19

#### Ẩn nút là UX, không phải bảo mật

R-15 nói thẳng: *ẩn nút ở frontend không tính là kiểm quyền*. Kiểm quyền thật nằm ở câu
lệnh đầu tiên của method service (C-GO-06), và nó vẫn chạy dù frontend có ẩn nút hay không.

Lý do không phải lý thuyết: nút bị ẩn vẫn gọi được bằng `curl`, bằng DevTools, bằng một
tab cũ mở từ trước lúc quyền bị thu hồi. Frontend không giữ được thứ gì nó không sở hữu.

Vậy ẩn nút để làm gì? Để người dùng không bấm vào một thứ chắc chắn thất bại. Đó là toàn bộ
giá trị của nó, và nó vẫn đáng làm — chỉ là không được nhầm nó với một lớp bảo vệ.

Hệ quả trực tiếp: **frontend vẫn phải xử lý `403` tử tế.** Ẩn nút không đảm bảo `403` không
bao giờ tới; quyền đổi giữa lúc tải trang và lúc bấm là chuyện bình thường.

| Status | Nghĩa | Frontend làm gì |
|---|---|---|
| `401` | Chưa xác thực, token sai hoặc hết hạn | Thử làm mới token; thất bại thì đưa về màn hình đăng nhập |
| `403` | Đã xác thực, không đủ quyền | Hiện thông điệp rõ ràng tại chỗ, **giữ nguyên màn hình**, làm mới dữ liệu để nút cập nhật lại |

Ba lỗi hay gặp ở nhánh `403`, cả ba đều tệ hơn việc không xử lý gì: **đăng xuất người
dùng** (`403` không phải `401` — họ đăng nhập đúng, chỉ là không được làm việc đó), **thử
lại tự động** (lần nào cũng `403`, chỉ thêm tải cho server), và **màn hình trắng** vì lỗi
lọt lên error boundary gốc.

#### Bật/tắt theo field API trả về, không tự suy luận từ role

**Trạng thái thật hôm nay: `allowed_actions` chưa tồn tại ở bất kỳ response nào của
backend.** Không endpoint nào trả field này tính tới cuối chặng E — đây là hình dạng đích
mà C-TS-06 mô tả cho ngày field đó có mặt, không phải cái đang chạy. Xây nó đòi một thiết
kế cho việc rò quyền từ `authz.Checker` ra DTO mà không phá R-04 và ADR-0010 (bảng vai trò
cố ý nhốt trong composition root) — một quyết định về mô hình quyền, chưa thuộc chặng nào
đã đóng.

Đường hợp lệ cho tới lúc đó **không phải** chờ có field rồi mới cho nút hoạt động, và cũng
không phải đoán bằng `role` để lấp chỗ trống. Nó là dòng cuối của bảng ba cấp bên dưới: **để
nút hiện, không kiểm gì cả, và xử lý `403` cho tử tế khi nó tới.** Đó không phải một trạng
thái tạm bợ chờ sửa — chính C-TS-06 (dòng ~798) đã gọi tên nó là cách đúng: *"khi chưa có dữ
liệu quyền cho một thao tác, cách đúng là để nút đó hiện và xử lý `403` cho tử tế, chứ không
phải đoán bằng role."* Cái bị cấm là **đoán**, không phải **không biết**.

```tsx
// SAI: frontend tự suy luận quyền từ role và tự dựng bảng chuyển trạng thái hợp lệ.
const NEXT_STATUSES: Record<string, string[]> = {
  draft: ['approved', 'cancelled'],
  approved: ['cancelled'],
};

function ApproveButtonWrong({ order, role }: { order: Order; role: string }) {
  // Hai dòng dưới là hai quy tắc nghiệp vụ đã bị chép sang frontend: "ai được duyệt"
  // và "trạng thái nào duyệt được". Cả hai đều đã có bản ở backend, nên đây là bản thứ
  // hai — và bản thứ hai luôn lệch. Nó lệch IM LẶNG theo cả hai chiều: nút hiện cho
  // người không có quyền (bấm vào ăn 403 khó hiểu), hoặc nút ẩn với người có quyền
  // (họ báo hỏng, không ai tìm ra vì backend cho phép).
  const canApprove = role === 'admin' && NEXT_STATUSES[order.status]?.includes('approved');

  return <button disabled={!canApprove}>Duyệt</button>;
}
```

```tsx
// ĐÚNG: hỏi backend, không tự suy. allowed_actions là một field của chính bản ghi,
// backend tính nó bằng cùng bộ quy tắc mà nó dùng để cho phép hay từ chối thao tác —
// nên nút và câu trả lời của server không thể lệch nhau.
function ApproveButton({ order, onApprove }: { order: Order; onApprove: () => void }) {
  const canApprove = order.allowed_actions.includes('approve');

  return (
    <button type="button" disabled={!canApprove} onClick={onApprove}>
      Duyệt
    </button>
  );
}
```

> Endpoint duyệt đơn có dạng `/orders/:id/actions/approve` — dạng ngoại lệ của R-10, chỉ
> tồn tại khi đã có dòng đăng ký ở bảng 1 của C-API-07. Ví dụ trên chỉ minh họa phía hiển
> thị.

Vì sao `allowed_actions` chứ không phải role, nói cho hết:

- **Tự suy luận từ role là chép logic phân quyền sang frontend** — đúng thứ R-19 cấm, và
  đúng kiểu chép nguy hiểm nhất vì nó không hiện ra dưới dạng một phép tính sai mà dưới
  dạng một cái nút.
- **Quyền không chỉ phụ thuộc role.** Nó phụ thuộc trạng thái bản ghi, phụ thuộc người tạo,
  phụ thuộc hạn mức. Frontend không có đủ dữ liệu để tính, nên nó sẽ tính bằng một xấp xỉ —
  và xấp xỉ đó là bản thứ hai của quy tắc.
- **Backend đổi quy tắc thì frontend theo kịp mà không cần deploy.** `allowed_actions` là
  dữ liệu, không phải code; sửa quy tắc duyệt đơn ở service là màn hình đúng ngay.
- **Nó test được.** Kiểm nút hiện đúng lúc nào chỉ cần dựng một object `Order` với
  `allowed_actions` khác nhau, không phải mô phỏng cả một cây role.

Ba cấp hiển thị theo quyền, dùng ba nguồn dữ liệu khác nhau — cả ba đều do backend trả về,
không cái nào do frontend suy ra:

| Cấp | Nguồn | Ví dụ |
|---|---|---|
| Nút trên một bản ghi | `allowed_actions` của chính bản ghi đó | Nút Duyệt trên một đơn hàng |
| Mục menu và route | Danh sách quyền backend trả về cùng phiên đăng nhập | Menu "Kế toán" |
| Trường hợp còn lại | Không đoán — cứ hiển thị, và xử lý `403` khi nó tới | Thao tác hiếm, chưa có field tương ứng |

Dòng cuối bảng là quy ước có chủ đích: khi chưa có dữ liệu quyền cho một thao tác, cách
đúng là **để nút đó hiện** và xử lý `403` cho tử tế, chứ không phải đoán bằng role. Một
frontend đoán sai theo hướng ẩn nút tạo ra một lỗi không ai gỡ được từ phía người dùng; một
frontend hiển thị nút rồi nhận `403` tạo ra một thông báo rõ ràng, và một dòng trong danh
sách việc cần làm cho backend: bổ sung field quyền cho thao tác đó.

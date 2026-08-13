# ADR-0011: TanStack Query v5 là thư viện data-fetching duy nhất cho server state ở frontend

**Status:** Accepted (2026-08-13)

## Context

Chặng E là chặng đầu tiên có code TypeScript thật trong `frontend-erp` — trước đó repo chỉ
có 2 commit, 3 file, không một dòng code.

`04-conventions/C-TS-frontend.md` mục C-TS-03 đã viết trước, ở chặng D, một mô hình quản lý
state: tách **server state** (dữ liệu đến từ API, có thể cũ đi vì người khác sửa được) khỏi
**client state** (trạng thái của giao diện, chỉ component sở hữu). Mọi ví dụ minh họa của
C-TS-03 — cache key theo dữ liệu, cấm chép `useQuery` vào `useState` rồi tự đồng bộ bằng
`useEffect`, `invalidateQueries` thay vì `setState` sau mutation, `placeholderData` giữ
trang cũ khi trang mới đang tải — đều viết bằng API của TanStack Query. Nhưng mục đó tự ghi
một dòng chú thích ở trên cùng: *"Việc chọn thư viện data-fetching cụ thể chưa có ADR."*

Chặng E cần dựng bốn màn hình thật (đăng nhập, danh sách máy, chi tiết & sửa máy, báo sự
cố). Màn danh sách máy là ca nghiệm thu trực tiếp của C-TS-03: bộ lọc và phân trang sống ở
URL, không ở `useState`, và tổng số trang đọc từ `meta.total` chứ không suy từ độ dài mảng.
C-TS-05 (form, validate, hiển thị lỗi) cần một mutation có thể rẽ nhánh theo `status` và
`error.code` của response — `422` giữ form và tô từng ô theo `error.fields`, `409` bắt tải
lại dữ liệu — nghĩa là cần một state machine pending/error/success cho mutation, không chỉ
một hàm gọi API.

Thời điểm quyết: `frontend-erp` chưa có dependency nào ngoài khung Vite (dựng song song ở
task khác của cùng chặng).

## Decision

**Chọn TanStack Query v5 làm thư viện data-fetching duy nhất cho server state ở
`frontend-erp`.**

- Áp dụng cho mọi nơi đọc dữ liệu từ API (`useQuery`) và mọi nơi ghi dữ liệu lên API
  (`useMutation`).
- **Không** áp dụng cho client state — client state vẫn dùng `useState`/`useReducer`/
  `context` cục bộ đúng như C-TS-03 đã chốt trước đó; ADR này không đổi ranh giới đó, chỉ
  chọn công cụ cho một nửa của nó.
- Cache key khai theo đúng khuôn C-TS-03 đã viết: theo tài nguyên và tham số ảnh hưởng kết
  quả, không theo tên màn hình.

## Alternatives

**SWR** — loại vì yếu hơn ở mutation và invalidation, đúng chỗ chặng này cần mạnh. C-TS-05
cần phân biệt hành vi theo status ngay tại điểm mutation thất bại: `422` giữ form, `409`
bắt tải lại. Mô hình mutation của SWR là một hàm phụ trợ (`mutate`) dựng trên cùng cơ chế
fetch của nó, không phải một state machine pending/error/success độc lập như `useMutation`
của TanStack Query — muốn có chỗ tập trung xử lý lỗi theo status nhất quán qua toàn app thì
phải tự dựng thêm một lớp bọc, và lớp bọc đó chính là thứ TanStack Query đã có sẵn.

**Tự viết trên `fetch`** (một `useState` + `useEffect` mỗi hook, tự quản cache bằng một
`Map` module-scope) — loại vì rẻ lúc đầu, đắt dần. Ba thứ phải tự dựng lại nếu đi hướng
này, và cả ba đã bị C-TS-03 coi là có sẵn: cache theo khóa dữ liệu (không phải theo
component gọi), deduplication khi hai component cùng đọc một khóa cùng lúc, và invalidate
xuyên component khi một mutation ở nơi khác thành công. Bốn màn hình của chặng E mỗi màn
một bản triển khai hơi khác nhau của cùng ba thứ đó là đúng lỗi "hai bản logic luôn lệch
nhau theo thời gian" mà [ADR-0009](ADR-0009-business-rule-chi-o-backend.md) đã cảnh báo —
chỉ khác chỗ đứng: lần này lệch giữa các hook của cùng một frontend, không phải giữa
frontend và backend.

**Không chọn gì — mỗi màn hình tự quản bằng `useState` cục bộ, gọi lại API khi cần làm
mới** — loại. Đây chính là ví dụ **SAI** mà C-TS-03 dùng để minh họa lỗi "chép server state
vào client state rồi tự đồng bộ": có một bản sao thứ hai của cùng một sự thật, hỏng của nó
không báo lỗi nào, chỉ lộ ra dưới dạng người dùng thấy con số cũ sau khi người khác đã sửa.

## Consequences

**Được:**

- Convention đã viết ở C-TS-03 (cache key theo dữ liệu, `invalidateQueries` thay
  `setState`, `placeholderData` giữ trang cũ khi tải trang mới) có một thư viện thật đứng
  sau, không còn là ví dụ minh họa cho một API giả định.
- `useMutation` cho một chỗ tập trung để hàm `toFormErrors` của C-TS-05 nhận lỗi và rẽ
  nhánh theo `status`/`error.code`, không phải mỗi form tự bắt `try/catch` một kiểu khác
  nhau.
- Cache theo khóa dữ liệu và invalidate xuyên component là hành vi mặc định của thư viện,
  không phải thứ mỗi màn hình phải tự nhớ implement đúng.

**Mất:**

- Thêm một dependency ngoài vào `frontend-erp` ngay từ chặng đầu tiên có code thật; một
  thay đổi breaking của thư viện (v5 → v6) là việc phải theo dõi và nâng cấp, không nằm
  trong tay đội kiểm soát bằng convention nội bộ.
- Devtools và mô hình tư duy của TanStack Query (query key, stale time, cache time,
  invalidate) là kiến thức người mới phải học thêm, ngoài kiến thức React thuần.

**Nợ để lại:**

- **C-TS-03 hiện vẫn còn dòng "Việc chọn thư viện data-fetching cụ thể chưa có ADR."** Dòng
  đó nay sai kể từ ADR này, nhưng việc sửa nó không nằm trong phạm vi các thay đổi đã giao
  cho chặng E — đây là việc phải làm ở PR kế tiếp có chạm `C-TS-frontend.md`.
- Chưa chốt cấu hình mặc định của `QueryClient` (`staleTime`, `retry`, vị trí đặt
  `QueryClientProvider` trong `src/app/`) — đó là chi tiết tầng Convention, để ngỏ cho tới
  khi có đủ code thật để soi một mẫu số chung.

**Constrains:** —

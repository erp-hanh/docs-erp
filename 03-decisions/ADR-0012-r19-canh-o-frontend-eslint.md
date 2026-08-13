# ADR-0012: `R-19` được canh bằng ESLint ở `frontend-erp`, không mở rộng `backend-erp/arch`

**Status:** Accepted (2026-08-13)

> **Sửa đổi trong ngày (2026-08-13):** thêm một đoạn vào cuối mục Decision, ghi lại rằng
> tập sink mà `r19-no-computed-money-in-body` thi hành rộng hơn "Dấu hiệu vi phạm" của
> `R-19` liệt kê trong `RULES.md`, kèm lý do và danh sách đầy đủ. Phát hiện này xuất hiện
> khi viết fixture cho luật đó (E9), sau khi ADR này đã `Accepted` trong cùng ngày.
>
> Ghi lại ở đây vì quy tắc bất biến của ADR nói rằng ADR đã `Accepted` thì không sửa nội
> dung. Ngoại lệ này chỉ hợp lệ vì nó xảy ra cùng ngày và chưa ai dựa vào bản cũ — mã
> `R-19` trong `backend-erp/arch/rules.go` chưa từng trỏ tới nội dung cụ thể của đoạn
> thêm này, và tài liệu duy nhất mà đoạn thêm này ràng buộc thêm (`RULES.md`) không đổi
> một chữ. Lần sau, một thay đổi như thế này phải là một ADR mới đánh dấu `Superseded
> by`.

## Context

`R-19` (Business Rules Never in UI, xem [ADR-0009](ADR-0009-business-rule-chi-o-backend.md))
tồn tại từ trước, nhưng tới cuối chặng D nó là rule **duy nhất** trong 24 rule của
`backend-erp/arch` chưa từng được gọi một lần: `Level: NA` trong `arch/rules.go`, và
`chayChecks()` bỏ qua mọi rule `NA` ngay ở dòng đầu vòng lặp. Cột LAN CHAY của nó đọc là
"chưa ai hỏi", không phải "chưa đạt" — vì `frontend-erp` không có một file `.ts`/`.tsx` nào
để soi.

Bộ máy `arch/` của `backend-erp` (`loader.go`, cơ chế fixture hai chiều generic trên
`[]RawFile`, `EffectiveLevels`, `gen_readme`, `TestRuleDeclaration`) đã tồn tại và hoạt động
tốt qua bốn chặng cho các rule Go. Thêm `.ts`/`.tsx` vào `rawExts` của `loader.go` là đúng
một dòng thay đổi để bộ máy đó bắt đầu nhận file frontend — cơ chế fixture phía sau nó
không cần sửa gì.

Nhưng `loader.go` cố ý không dùng `go/packages`: nó đọc file nguồn ở mức thấp, không cần
một toolchain biên dịch đầy đủ đứng sau. Go không có parser TypeScript. Một checker viết
trong `arch/` cho file `.tsx` do đó sẽ phải là regex trên text — cùng kỹ thuật với
`sqlscan`, vốn tự khai trong comment của chính nó rằng nó "không phải parser đầy đủ".

Mệnh đề trung tâm của R-19 — "frontend cấm gửi con số nó tự tính lên server" — là một câu
hỏi **dataflow**: phải biết biến nào giữ **kết quả của một phép toán số học**, và biến đó
có chảy tới **đối số thứ hai của `axios.post`/thân `fetch`** hay không. C-TS-05 dòng 617
ghi đúng ranh giới đó: *"hiển thị tạm tính trên màn hình được phép; gửi con số đó lên server
thì không."* Một regex khớp theo mẫu chuỗi không phân biệt được biến `total` được render ra
JSX với biến `total` cùng tên bị nhét vào body của request POST — với regex, cả hai chỉ là
một token `total` xuất hiện gần một cặp ngoặc.

Bài học của chặng A còn nguyên giá trị: bảy dòng "PASS trên tập RỖNG" đã sống sót một chặng
vì không ai hỏi câu hỏi mà rule đó tuyên bố đang canh. Viết checker regex trong `arch/` để
R-19 chuyển `PASS` là mua đúng cái bẫy đó lần thứ hai — lần này khó phát hiện hơn, vì tập
không còn rỗng (có code `.tsx` thật), chỉ có luật là rỗng ruột.

`@typescript-eslint` có AST thật của TypeScript kèm thông tin kiểu. Luật "biểu thức số học
chảy vào thân request" viết được ở đó, và tại thời điểm quyết định này, nó là chỗ **duy
nhất** viết được.

## Decision

**`R-19` được canh bằng ESLint chạy trong `frontend-erp`, không mở rộng bộ máy `arch/` của
`backend-erp` để đọc file TypeScript.**

- Hai luật cụ thể — `r19-no-computed-money-in-body` (kết quả biểu thức số học đi vào thân
  `POST`/`PUT`/`PATCH`) và `r19-no-status-table` (object ánh xạ trạng thái→trạng thái dùng
  để quyết định bật/tắt) — sống ở `frontend-erp/eslint-rules/`, mỗi luật kèm fixture hai
  chiều (`__fixtures__/<ten-luat>/{vi-pham,hop-le}.tsx`).
- Hai luật đó chạy trong job `arch` của `frontend-erp/.github/workflows/ci.yml`, chấm điểm
  vào `frontend-erp/arch/LEVELS.md` — bảng dùng **cùng văn phạm**
  (`RULE | KHAI | THUC TE | LAN CHAY | FILE`) với bảng của `backend-erp`, sinh bởi một
  runner riêng (`frontend-erp/scripts/arch.mjs`) áp lại đúng ba mệnh đề đóng bảng đã giữ
  cho bảng gốc không mục: `FULL` thì `Unverifiable` rỗng, `PARTIAL`/`NA` thì khác rỗng, và
  một luật không có fixture vi phạm là `FAIL` chứ không phải `PASS`.
- `backend-erp/arch/rules.go` giữ nguyên `R-19` ở `Level: NA`, nhưng đổi nội dung
  `Unverifiable` từ một lời từ chối chung chung sang một con trỏ đích danh: tên hai luật
  ESLint, tên job CI, và đường dẫn `frontend-erp/arch/LEVELS.md`.
- **Không đổi `01-rules/RULES.md`** — mệnh đề R-19 giữ nguyên từng chữ, nên `arch-pin`
  không phải chạy lại.

**Tập sink thi hành thật rộng hơn "Dấu hiệu vi phạm" của `R-19` trong `RULES.md`.**
`RULES.md` khai dấu hiệu vi phạm là *"tham số thứ hai của `axios.post(`/`axios.put(`, hoặc
`body` của `fetch(`"*. Đọc đúng nghĩa đen ba ví dụ đó, một luật hiện thực CHỈ chừng đó tập
sink sẽ không bao giờ khớp một dòng nào trong `src/modules/**`: C-TS-04 cấm `fetch`/`axios`
ở mọi nơi ngoài `src/shared/api/`, và C-TS-03 bắt mọi lệnh ghi đi qua `useMutation` →
`api/` → `send()`. Component nghiệp vụ không bao giờ gọi thẳng `axios.post`/`fetch` — nó
gọi `mutate`/`mutateAsync` của một hook, hook đó gọi một hàm trong `api/`, hàm đó gọi
`send()`. Một luật khớp đúng chữ ba ví dụ đó sẽ xanh vĩnh viễn trên toàn bộ
`src/modules/**` — đúng loại "luật trang trí cho một dòng PASS giả" mà cả chặng E được mở
ra để tránh (mục 1 của spec chặng E), và nó suýt xảy ra thật vì hai văn bản của chính dự
án mâu thuẫn nhau: `R-19` đòi canh dataflow thật, còn ví dụ minh họa của nó giả định một
kiến trúc gọi mạng trực tiếp mà C-TS-03/C-TS-04 đã đóng lại từ trước.

Tập sink thi hành thật, đọc từ `frontend-erp/eslint-rules/r19-no-computed-money-in-body.js`
và `frontend-erp/eslint-rules/lib/request-body.js` (hàm `collectRequestBodies`), gồm:

- tham số thứ hai của `.post(`/`.put(`/`.patch(` gọi trên một object bất kỳ (không riêng
  `axios`);
- tham số đầu tiên của `mutate(`/`mutateAsync(`;
- thuộc tính `body` của object cấu hình `fetch(url, { method, body })`, khi `method`
  không phải một verb chỉ-đọc (`GET`/`HEAD`/`OPTIONS`/`DELETE`);
- thuộc tính `data` của `axios({ method, data })`, cùng điều kiện `method`;
- tham số thứ ba của `send('POST'|'PUT'|'PATCH', url, body)` — client dùng chung của
  C-TS-04;
- mọi tham số của một hàm được `import` từ một module có đường dẫn khớp `api/`, mang tên
  động từ ghi (`create`, `update`, `save`, `submit`, `send`, `report`, `bao`, `tao`, `sua`,
  `cap_nhat`, `luu`, `gui`, ...).

Ba mục cuối không nằm trong "Dấu hiệu vi phạm" của `RULES.md`. Đó chính xác là điều đoạn
này ghi lại: tập sink thi hành đúng **mệnh đề** của `R-19` — "frontend cấm gửi con số nó
tự tính lên server" — qua kiến trúc thật của repo (`useMutation` → `api/` → `send()`),
không qua ba ví dụ minh họa liệt kê trong "Dấu hiệu vi phạm". Ví dụ trong `RULES.md` là ví
dụ minh họa cho mệnh đề tại thời điểm `R-19` được viết, không phải danh sách đóng của mệnh
đề; tập sink thi hành phải theo mệnh đề, không theo ví dụ liệt kê lúc đó.

**Không sửa `01-rules/RULES.md`** vì phát hiện này — mệnh đề `R-19` và "Dấu hiệu vi phạm"
của nó giữ nguyên từng chữ, đúng điều kiện đã nêu ở bullet trên để `arch-pin` không phải
chạy lại. Nếu "Dấu hiệu vi phạm" cần viết lại cho khớp tập sink thật, đó là một quyết định
của người, thực hiện bằng một ADR mới hoặc một lần sửa `RULES.md` có chủ ý và được duyệt —
không phải hệ quả ngầm của việc viết checker trong chặng này.

## Alternatives

**Thêm `.ts`/`.tsx` vào `rawExts` của `loader.go` và viết checker regex trong `arch/` của
`backend-erp`** — loại. Đây là phương án rẻ nhất về công sức viết: đúng một dòng mở rộng
loader, tái dùng toàn bộ cơ chế fixture generic có sẵn, không cần bảng điểm thứ hai. Chính
vì rẻ nên nó hấp dẫn nhất — và nó hỏng đúng ở chỗ rule này cần đúng: một regex không tách
được "biến chảy ra JSX" khỏi "biến chảy vào body request", vì cả hai chỉ là cùng một tên
biến xuất hiện trong text. Chấp nhận phương án này là mua một dòng `PASS` mà không mua được
thứ dòng đó tuyên bố đang canh — hệ quả xấu hơn cả `Level: NA`, vì `NA` ít nhất còn trung
thực.

**Viết một TypeScript AST checker bằng Go** (tự dựng một parser tối giản cho một tập con cú
pháp cần dùng, hoặc gọi ra một binary Node.js từ `arch/` của `backend-erp`) — loại. Đây là
dựng lại đúng thứ `@typescript-eslint` đã có sẵn và đã được kiểm chứng, cho một phạm vi hẹp
hơn nhiều những gì nó làm được, đồng thời kéo một runtime Node.js vào làm phụ thuộc build
của `backend-erp` chỉ để chấm điểm một rule của một repo khác. Hai chi phí, không có lợi
ích tương ứng nào bù lại.

**Giữ nguyên `Unverifiable` như trước chặng E — không canh R-19 bằng máy ở chặng này** —
loại, vì "R-19 bị hỏi lần đầu" chính là mục tiêu đo được mà chặng E được mở ra để đạt. Giữ
nguyên không phải một phương án trung lập ở đây; nó là không đạt goal của chặng.

## Consequences

**Được:**

- Luật viết trên AST thật, có thông tin kiểu — phân biệt được biểu thức số học chảy vào
  JSX (không đỏ, đúng ngoại lệ C-TS-05 dòng 617) với cùng biểu thức đó chảy vào thân
  request (đỏ), đúng ranh giới mà mệnh đề trung tâm của R-19 cần.
- Fixture hai chiều bắt buộc theo đúng ba mệnh đề gốc của `TestRuleDeclaration`, dịch sang
  runner của `frontend-erp` — không lặp lại "PASS trên tập RỖNG" của chặng A: một luật
  không có fixture vi phạm ra `FAIL`.
- `Unverifiable` của R-19 ở `backend-erp/arch/LEVELS.md` từ một câu từ chối chung chung
  thành một con trỏ đích danh, đọc được thẳng ra chỗ đang canh thật thay vì dừng lại ở "nó
  thuộc repo khác".

**Mất:**

- **Bảng điểm thành hai file.** `backend-erp/arch/LEVELS.md` sẽ **không bao giờ** hiện
  `R-19 PASS` — người chỉ đọc bảng đó sẽ luôn thấy `N/A`, và phải biết đọc sang
  `frontend-erp/arch/LEVELS.md` mới thấy R-19 thật sự đứng ở đâu. Đây là chi phí thật,
  không phải chi tiết trình bày: một rule định nghĩa ở một nguồn duy nhất (`RULES.md`) nay
  bị chấm điểm ở hai nơi.
- Runner mới của `frontend-erp` sinh ra trong cùng chặng với ba mệnh đề "đóng bảng" được
  dịch sang, nhưng chưa có bốn chặng lịch sử chứng minh chúng đủ chặt như bộ test tự canh
  (`TestRuleDeclaration`, `TestFixtures`, `TestOptionalRootStaysHonest`) đã bảo vệ bảng của
  `backend-erp`.
- Hai bộ máy chấm điểm cần bảo trì song song thay vì một: đổi văn phạm bảng
  (`RULE | KHAI | THUC TE | LAN CHAY | FILE`) phải sửa ở cả hai runner nếu muốn giữ đồng
  bộ, và không có gì tự động báo khi chúng lệch nhau ngoài việc con người nhận ra.

**Nợ để lại — điều kiện mở lại quyết định này:**

- Nếu về sau tồn tại một cách phân tích dataflow TypeScript **thật** (không phải regex) mà
  `arch/` của `backend-erp` dùng được mà không kéo theo một runtime ngoài Go làm phụ thuộc
  build thường trực — ví dụ một service phân tích chạy sẵn ở CI mà `arch/` chỉ gọi và đọc
  kết quả có cấu trúc — thì đáng xét lại việc hợp nhất bảng điểm. Điều kiện đó **chưa tồn
  tại** tại thời điểm quyết định này.
- Nếu số lượng rule kiểu dataflow tương tự R-19 tăng lên — không còn là một rule "đơn độc"
  mà thành một lớp nhiều rule cùng dạng cần canh cả ở Go lẫn TypeScript — và việc duy trì
  hai bộ máy chấm điểm trở thành gánh nặng **đo được** (thời gian sửa mỗi lần đổi văn phạm,
  số lần hai bảng lệch nhau trong thực tế), thì nên cân nhắc hợp nhất. Quyết định đó phải
  dựa trên chi phí đã xảy ra thật, không phải dự đoán trước.
- Nếu có một client thứ ba ngoài `frontend-erp` (ví dụ một ứng dụng di động) cũng phải chịu
  R-19, quyết định này **không** tự động áp dụng cho client đó — tiền đề "TypeScript +
  `@typescript-eslint`" của ADR này có thể không đúng với công nghệ của client đó, và nơi
  đặt checker cho nó là một quyết định cần xét lại riêng, không suy diễn từ ADR này.
- Bảng của `frontend-erp` chưa có gì tương đương `TestRuleDeclaration`/`TestFixtures` để tự
  bảo vệ, ngoài phiên bản vừa sinh ở chặng E. Chặng sau phải canh xem bảng đó có mục theo
  đúng cách bảng cũ suýt mục ở chặng A, hay nó cũng cứng như bảng cũ.

**Constrains:** —

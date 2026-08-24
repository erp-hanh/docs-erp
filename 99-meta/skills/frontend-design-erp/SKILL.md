---
name: frontend-design-erp
description: Thiết kế và dựng giao diện cho repo `frontend-erp` của hệ ERP này — hệ token màu/chữ/khoảng cách, bộ component dùng chung, năm khuôn màn hình, quy tắc bảng–form–lỗi–phân quyền, và checklist trước khi giao. Dùng skill này BẤT CỨ KHI NÀO việc đang làm chạm tới thứ nhìn thấy được trên màn hình - dựng màn mới, thêm hay sửa component, viết CSS, chỉnh layout, làm bảng danh sách, làm form, làm màn tổng quan, sửa trạng thái đang tải / rỗng / lỗi, đổi màu chữ khoảng cách, dựng mockup - kể cả khi người dùng không nhắc chữ "thiết kế", "CSS" hay "UI", mà chỉ nói "màn hình xấu", "cho đẹp hơn", "khó nhìn", "gọn lại", "làm màn danh sách kho", hay dán ảnh chụp màn hình rồi hỏi sửa gì.
---

# Thiết kế frontend cho ERP

> **Bản sao lưu có version:** `docs-erp/99-meta/skills/frontend-design-erp/`. Thư mục
> `.claude/skills/` không thuộc repo git nào — sửa skill xong phải chép lại sang `docs-erp`
> trong cùng đợt việc, xem `docs-erp/99-meta/skills/README.md`.

Skill này viết cho đúng một repo: `frontend-erp` — React 19 + TypeScript + Vite +
TanStack Query, router tự viết, **không Tailwind, không thư viện component, không
dependency UI nào**. Mọi thứ dưới đây chạy được với đúng những gì `package.json` đã có.

## Skill này đứng ở đâu trong trật tự của hệ thống

```
Rules > Principles > Conventions > SKILL NÀY > code hiện có
```

`docs-erp` là nguồn sự thật. Skill này chỉ có thẩm quyền trên thứ **nhìn thấy được**:
màu, chữ, khoảng cách, bố cục, trạng thái hiển thị, chữ trên màn hình. Khi nó lệch với
`docs-erp/04-conventions/C-TS-frontend.md` hay với một Rule, **bản gốc thắng và skill này
là thứ phải sửa** — mở issue ở `docs-erp`, đừng tự diễn giải.

Đặc biệt, skill này **không bao giờ** là lý do để frontend giữ quy tắc nghiệp vụ. Không
tính tiền, không dựng bảng chuyển trạng thái, không đoán quyền từ role. Một thiết kế đẹp
mà vi phạm R-19 là một thiết kế sai.

## Luận điểm gốc: ERP không phải landing page

Skill `frontend-design` gốc dạy cách làm một trang có **bản sắc riêng, không lẫn vào
đâu** — hero là một luận đề, typography mang cá tính, dám mạo hiểm một lần. Đúng cho một
trang giới thiệu sản phẩm. Sai cho màn nhập chuyển động kho lúc 7 giờ sáng.

Người dùng của hệ này mở cùng vài màn hình, mỗi ngày, hàng trăm lần. Với họ, thứ có giá
trị không phải sự bất ngờ mà là **sự đoán trước được**: nút Lưu luôn ở đúng chỗ đó, cột
số luôn canh phải, lỗi luôn hiện ở cùng một nơi. Cái đẹp ở đây là kỷ luật, không phải
sáng tạo.

Nên cách tiêu bản sắc ở dự án này là:

> **Tiêu toàn bộ sự táo bạo đúng một lần, ở tầng token và bộ component. Từ đó trở đi,
> mọi màn hình phải nhàm chán giống hệt nhau.**

Một màn hình mới mà "trông khác các màn khác" là một lỗi cần sửa, không phải một đóng
góp. Nếu bạn thấy cần một màu, một khoảng cách hay một kiểu nút mà hệ token chưa có, thì
việc phải làm là **thêm token đó cho cả hệ**, không phải viết một giá trị thô cho riêng
màn này.

**Dấu ấn riêng của hệ này — chọn đúng một, và đây là nó:** *mã là nhân vật chính.* Người
dùng ERP gọi tên mọi thứ bằng mã (`PO-001`, mã kho, mã vật tư), và trong code hiện tại
`row.code` đã luôn là đường dẫn sang màn chi tiết. Nên mã được đối xử như một danh tính
thật: chữ đẳng khổ, nền chấm nhẹ, luôn là link, luôn copy được. Mọi trang trí khác giữ
im lặng để chỗ này nói.

## Trước khi vẽ bất cứ thứ gì: bốn câu hỏi

Trả lời được bốn câu này thì phần lớn quyết định thiết kế đã tự có đáp án:

1. **Màn này thuộc khuôn nào trong năm khuôn?** Danh sách, form, chi tiết, tổng quan, hay
   trang chủ ứng dụng (sơ đồ quy trình). Đừng tự thêm khuôn thứ sáu — khuôn chỉ sinh ra khi
   một màn thật sự không ép được vào khuôn nào, không phải vì muốn khác đi; đọc đoạn mở đầu
   `references/khuon-man-hinh.md` trước khi nghĩ mình đang gặp ca đó.
2. **Dữ liệu tới từ endpoint nào, và `meta` phân trang có không?** Có `meta` thì có chân
   trang phân trang, không có thì không được bịa ra.
3. **Bốn trạng thái của màn này trông ra sao?** Đang tải lần đầu, rỗng, lỗi, có dữ liệu —
   cộng trạng thái thứ năm là đang làm mới nền. Thiếu một trạng thái là màn hình chưa xong.
4. **Thao tác nào trên màn này do backend quyết?** Nút bật/tắt theo `allowed_actions` của
   chính bản ghi (C-TS-06), không theo role. Chưa có field đó thì **để nút hiện** và xử lý
   `403` tử tế — đó là quy ước, không phải tạm bợ.

## Chín luật giữ cho toàn hệ đồng nhất

Đây là phần quan trọng nhất của skill. Mỗi luật đều có lý do, và lý do mới là thứ đáng
nhớ — khi gặp ca mà luật không nói tới, hãy suy từ lý do.

**1. Mọi giá trị hình thức đến từ token.** Không hex thô, không `px` rời rạc, không
`rgba()` viết tay trong component. Lý do không phải sự sạch sẽ: hệ này sẽ có chế độ tối,
sẽ có lúc phải chỉnh độ tương phản cho nhà xưởng sáng chói, và mỗi giá trị thô là một chỗ
sót lại phía sau. Token nằm ở `src/shared/styles/tokens.css` — xem
`references/token.md`. Ngoại lệ duy nhất được viết giá trị thô: chính file token đó.

**2. Lưới 4px.** Mọi khoảng cách là bội của 4 và gọi qua `--gian-*`. Mắt người không đọc
được con số, nhưng đọc được sự lệch: `13px` cạnh `16px` cạnh `14px` cho ra cảm giác cẩu
thả mà không ai chỉ được tại đâu.

**3. Mỗi màn phải có đủ năm trạng thái.** Đang tải lần đầu (khung xương, không phải chữ
"Đang tải..."), rỗng (một câu giải thích + đúng một đường ra), lỗi (thông điệp + mã tra
cứu + nút thử lại), có dữ liệu, và đang làm mới nền (giữ nguyên dữ liệu cũ, chỉ báo nhẹ).
Trạng thái rỗng **bắt buộc mang đường tạo mới** nếu người dùng tạo được — một màn rỗng
không lối ra là ngõ cụt.

**4. Số là số, không phải chữ.** Cột số canh phải, dùng `font-variant-numeric:
tabular-nums`, định dạng bằng `Intl.NumberFormat('vi-VN')`. Tiền tệ đến từ backend dưới
dạng **chuỗi** (`NUMERIC(18,4)`) — định dạng từ chuỗi đó, và **không bao giờ** tính lại
rồi gửi lên (R-19). Tạm tính để nhìn thì được; tạm tính đi vào body request thì không.

**5. Nút hành động do dữ liệu quyết, không do màn hình đoán.** `allowed_actions` bật/tắt
nút. Nút `disabled` phải nói được vì sao (thuộc tính `title` hoặc một dòng chữ cạnh nút) —
một cái nút xám câm là lỗi giao diện tệ nhất trong ERP, vì người dùng không có cách nào
tự gỡ.

**6. Lỗi hiện ở hai chỗ, và luôn mang mã tra cứu.** Lỗi của một ô nằm ngay dưới ô đó; lỗi
của cả biểu mẫu nằm ở banner đầu form. `422` giữ nguyên form và tô từng ô; `409` nói dữ
liệu đã cũ và mời tải lại; `403` giữ nguyên màn hình, không đăng xuất, không tự thử lại.
Mọi banner lỗi hiện `request_id` (R-17) — đó là thứ người dùng đọc cho tổng đài.

**7. Bàn phím và tiêu điểm là yêu cầu, không phải tính năng.** Không bao giờ `outline:
none` mà không có `:focus-visible` thay thế. Thứ tự tab đi theo thứ tự đọc. Vùng bấm tối
thiểu 44×44px trên cảm ứng, 32px trên chuột. Mọi nút chỉ có biểu tượng phải có
`aria-label`. Không dùng emoji làm biểu tượng — SVG nội tuyến, nét 1.5px, khung 20px.

**8. Chuyển động phục vụ sự hiểu, không phục vụ sự vui.** 120ms cho phản hồi tức thời
(hover, nhấn), 180ms cho thứ xuất hiện/biến mất. Không animation trang trí, không thứ gì
chuyển động khi trang vừa tải. Luôn tôn trọng `prefers-reduced-motion`. Trong một màn
nhập liệu, chuyển động thừa không làm nó sang hơn — nó làm chậm việc.

**9. Đồng nhất là luật, không phải sự phẳng lì.** Hai màn cùng khuôn phải giống nhau tới
từng khoảng cách — đó là luật 1 tới 8. Nhưng **bên trong một màn thì phải có thứ bậc**: một
dải đầu trang mang tên màn và hành động chính, rồi mới tới nội dung. Một màn mở ra bằng
khoảng trống, hoặc một màn mà mắt không biết bám vào đâu trước, là lỗi ngang với một màn lạc
kiểu. Bảy khối dựng nên thứ bậc đó nằm ở `references/khuon-man-hinh.md` mục 0 — chúng là
vật liệu chung của cả năm khuôn, không phải sáng tạo riêng của từng màn.

Luật này rút ra ngày 2026-08-24 từ một lần đo thật: đặt màn Phân quyền đang chạy cạnh một
màn ERP thương mại, bảng màu không có lỗi nào, **toàn bộ khoảng cách nằm ở bố cục**. Nên khi
ai đó nói màn hình xấu, chỗ phải soi trước là mục 0 của khuôn màn hình, không phải bộ token.

## Quy trình

Bốn bước, làm đúng thứ tự. Ba bước đầu rẻ, bước bốn đắt — nên đừng đảo.

**Bước 1 — Đọc trước khi vẽ.** Mở `references/khuon-man-hinh.md` — **mục 0 trước**, vì bảy
khối bố cục ở đó là vật liệu chung của cả năm khuôn — rồi tới `references/token.md`.
Nếu màn này có bảng hoặc form, mở thêm `references/bo-component.md`. Nếu đang sửa một màn
đã có, đọc màn cùng khuôn gần nhất trong `src/modules/` và **bắt chước nó**, kể cả khi bạn
sẽ làm khác đi nếu được chọn lại.

**Bước 2 — Nói ra bố cục trước khi viết code.** Một khối ASCII mười dòng, kèm câu trả lời
cho bốn câu hỏi ở trên. Việc này bắt lỗi bố cục lúc còn sửa được bằng một dòng chữ, thay
vì lúc đã có 200 dòng TSX. Cần bản mockup cho người khác xem thì viết một file HTML tĩnh
trong `mockup-erp/`, `<link>` thẳng vào cùng `tokens.css` — cùng token nghĩa là thứ duyệt
trên mockup đúng là thứ sẽ lên màn thật.

**Mockup có hạn sử dụng, và nó hết hạn đúng lúc màn lên code.** Từ giây phút có
`*.tsx` chạy được, bản chạy được là nguồn sự thật; giữ hai bản song song đồng bộ với nhau
là một khoản bảo trì không ai trả, và bản mockup sẽ lệch dần rồi có ngày ai đó duyệt nhầm
nó. Đánh dấu ngay trên đầu file là **đã lên code**, ghi những chỗ bản code cố ý khác đi và
vì sao — rồi để nó yên như một hồ sơ thiết kế, đừng sửa nữa.

**Bước 3 — Dựng bằng thứ đã có.** Ưu tiên theo đúng thứ tự này: component trong
`src/shared/components/` → phần tử HTML thuần đã được `co-so.css` tạo dáng sẵn → component
mới. Component mới chỉ ra đời khi **cùng một hình dạng xuất hiện lần thứ ba**; hai lần đầu
cứ chép. Trừu tượng hóa sớm ở tầng giao diện luôn đắt hơn là chép hai lần.

**Bước 4 — Tự soi rồi mới nói xong.** Từ thư mục `frontend-erp/`, chạy
`node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs`, rồi đi hết
`references/checklist.md`. Đánh dấu một dòng nghĩa là đã kiểm thật.

## Bộ token — bảng tra nhanh

Chi tiết, lý do và bản chế độ tối ở `references/token.md`. File chép được ngay ở
`assets/tokens.css`; lớp nền tạo dáng sẵn cho HTML thuần ở `assets/co-so.css`.

| Nhóm | Token | Dùng khi |
|---|---|---|
| Nền | `--mau-nen`, `--mau-nen-noi`, `--mau-nen-nhat` | Nền trang, thẻ nổi, ô tô nhẹ |
| Chữ | `--mau-chu`, `--mau-chu-mo`, `--mau-chu-nhat` | Chữ chính, chú thích, chữ trên nền đậm |
| Viền | `--mau-vien`, `--mau-vien-dam` | Viền thường, viền khi rê chuột |
| Thương hiệu | `--mau-chinh`, `--mau-chinh-dam`, `--mau-chinh-nhat` | Nút chính, link, nền tô nhạt |
| Trạng thái | `--mau-loi`, `--mau-canh-bao`, `--mau-tot` (+ hậu tố `-nhat`) | Lỗi, cảnh báo, thành công |
| Khoảng cách | `--gian-1` … `--gian-8` (4 → 64px) | Mọi padding, margin, gap |
| Chữ | `--chu-xs` … `--chu-3xl`, `--dam-vua`, `--dam-manh` | Cỡ và độ đậm |
| Bo góc | `--bo-goc`, `--bo-goc-lon`, `--bo-goc-tron` | Nút/ô nhập, thẻ, chip |
| Độ nổi | `--do-noi-1`, `--do-noi-2`, `--do-noi-3` | Thẻ, dropdown, hộp thoại |
| Nhịp | `--nhip-nhanh`, `--nhip-vua`, `--duong-cong` | Mọi `transition` |
| Khung | `--rong-noi-dung`, `--rong-form`, `--cao-thanh-dau`, `--rong-canh` | Bố cục vỏ ứng dụng |

Ba con số đáng nhớ vì chúng chi phối cảm giác của cả hệ: **nền trang không trắng** (thẻ
trắng nổi lên trên nền `--mau-nen` mới có tầng lớp), **viền mảnh 1px thay cho bóng đổ**
(bóng chỉ dành cho thứ thật sự nổi lên: dropdown, hộp thoại), và **bo góc 6px** —
đủ mềm để không cứng, đủ nhỏ để không trẻ con.

## Bộ component dùng chung

Đặt ở `src/shared/components/`, mỗi component một thư mục kèm `*.module.css` cạnh nó.
Ràng buộc của `shared/` giữ nguyên (R-04): **`shared/` cấm import `modules/`** — một
`Nut` biết tới đơn hàng thì không còn dùng chung được nữa.

Chữ ký đầy đủ, trạng thái và ghi chú trợ năng của từng component ở
`references/bo-component.md`:

`Nut` · `LienKetNut` · `TruongNhap` · `ThanhLoc` · `TieuDeTrang` · `Bang` · `PhanTrang` ·
`BangThongBao` · `NhanTrangThai` · `MaBanGhi` · `ManRong` · `KhungXuong` · `HopThoaiXacNhan`

Ba thứ **không** làm thành component dùng chung, và đây là lý do: bảng của từng module
(cột là chuyện của nghiệp vụ, `Bang` chỉ lo khung và trạng thái), form nghiệp vụ (ráp từ
`TruongNhap`, không bọc thêm một lớp), và bất cứ thứ gì mới xuất hiện hai lần.

## Khuôn màn hình

Năm khuôn, wireframe và luật riêng của từng khuôn ở `references/khuon-man-hinh.md`:

| Khuôn | Dùng cho | Xương sống |
|---|---|---|
| Danh sách | `/kho`, `/vat-tu`, `/ton-kho`, `/machines` | Tiêu đề + hành động → thanh lọc → bảng → phân trang |
| Form | `/kho/moi`, `/vat-tu/:id`, `/chuyen-dong/moi` | Một cột hẹp, nhãn trên ô, chân trang dính nút Lưu |
| Chi tiết | Xem một bản ghi + thao tác trên nó | Đầu trang mang mã và trạng thái → khối thông tin → lịch sử |
| Tổng quan | `/` | Hàng chỉ số → khối việc cần làm → lối tắt |
| Trang chủ ứng dụng | `/kho-van`, `/thiet-bi` | Tiêu đề + mô tả → chuỗi bước đánh số nối mũi tên → nhánh bên (nếu có) |

Vỏ ứng dụng (thanh điều hướng, thanh đầu trang, responsive) cũng nằm trong file đó.

## Chữ trên màn hình

Chữ là vật liệu thiết kế, không phải phần chú thích thêm vào lúc cuối. Quy tắc đầy đủ ở
`references/chu-tren-man-hinh.md`. Bốn điều hay sai nhất:

- **Nút nói việc nó làm**: "Lưu vật tư", không phải "Gửi"; và tên đó **không đổi** suốt
  luồng — nút "Lưu" thì thông báo sau đó là "Đã lưu".
- **Lỗi nói cách sửa**, không xin lỗi, không mơ hồ: "Mã kho đã tồn tại, chọn mã khác",
  không phải "Có lỗi xảy ra".
- **Màn rỗng là lời mời**, không phải một câu thông báo cụt.
- **Gọi tên theo thứ người dùng biết**, không theo thứ hệ thống có: "Đơn vị tính", không
  phải "unit_id".

Chữ hiển thị viết **tiếng Việt có dấu**. Luật này thắng lối không dấu của code cũ
(`Danh sach vat tu`) và thắng cả những đoạn trong chính skill này còn viết theo lối cũ.
Gặp chuỗi không dấu **trong vùng mình đang sửa** thì sửa luôn; ngoài vùng đó thì để yên,
đừng biến một PR giao diện thành một đợt quét toàn repo.

Dấu tiếng Việt cần `line-height` rộng hơn tiếng Anh vì `ẫ` và `ộ` ăn vào cả phần trên lẫn
phần dưới của dòng — `--dong-*` trong bộ token đã tính sẵn phần đó, nên đừng đè lại.

## Trước khi nói là xong

```bash
cd frontend-erp
node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs
npm run lint && npm test
```

Script bắt bốn nhóm lỗi bằng máy: giá trị màu thô ngoài file token, `px` không đi qua
`--gian-*`, `outline: none` không kèm `:focus-visible`, và emoji dùng làm biểu tượng.
Nó **không** thay được `references/checklist.md` — trợ năng, năm trạng thái và chất lượng
chữ thì chỉ có mắt người đọc ra.

## Đọc thêm

| File | Khi nào mở |
|---|---|
| `references/token.md` | Trước khi viết dòng CSS đầu tiên; khi cần thêm token mới |
| `references/bo-component.md` | Khi dựng hoặc sửa bất cứ component dùng chung nào |
| `references/khuon-man-hinh.md` | Khi dựng một màn mới, hoặc sửa bố cục một màn đã có |
| `references/chu-tren-man-hinh.md` | Khi viết nhãn, thông điệp lỗi, màn rỗng, tên nút |
| `references/checklist.md` | Trước khi mở PR — mọi lần, không có ngoại lệ |
| `assets/tokens.css`, `assets/co-so.css` | Lần đầu dựng hệ token cho repo, hoặc làm mockup |

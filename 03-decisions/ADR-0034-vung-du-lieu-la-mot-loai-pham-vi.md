# ADR-0034: Vùng dữ liệu là một LOẠI PHẠM VI, không phải một cột mới

**Status:** Accepted (2026-08-24)

## Context

Chủ dự án chốt phạm vi của màn cấp 1 (quản trị hệ thống) gồm đúng ba việc: bổ nhiệm quản trị
phân hệ, gán vùng dữ liệu cho họ, và **tạo vùng dữ liệu**. Hai việc đầu có đường đi rồi; việc
thứ ba đòi một thứ chưa có trong mô hình.

**Vùng dữ liệu là gì, theo lời người dùng:** một tập kho **có tên** — "Miền Nam" gồm sáu kho,
"Hà Nội + Hải Phòng" gồm ba — để gán cho một quản trị phân hệ bằng một thao tác, thay vì tick
từng kho.

**Thứ đang có.** `user_company_role_scopes` (migration 000023) treo phạm vi vào MỘT hàng vai
trò, và nó đã tổng quát sẵn: `(scope_type TEXT, scope_id UUID)`. Hôm nay chỉ có một loại,
`scope.Kho = "warehouse"`, và `scope_id` cố ý **không** mang `REFERENCES` — migration 000023 ghi
rõ lý do ở chỗ khai cột.

**Thứ quan trọng nhất đo được lúc khảo sát:** mọi module đọc phạm vi đều đi qua đúng **một** câu
truy vấn — `selectScopeIDsTheoActorSQL` trong `modules/auth/internal/repository/scope_repository.go`
— rồi lên `scope.Resolve`. `movement_service.go:206` và mọi chỗ lọc theo kho đều nằm sau nó.
Nghĩa là chi phí của một loại phạm vi mới tập trung ở một chỗ, không rải ra từng module.

**Hai nghĩa của "gán một vùng", và chúng khác nhau ở chỗ người dùng nhìn thấy được:**

1. **Chép lúc gán** (materialize): gán vùng "Miền Nam" = chép sáu id kho vào bảng phạm vi. Rẻ,
   không đụng đường đọc. Nhưng ngày ai đó thêm kho thứ bảy vào vùng, **không một người nào đã
   được gán vùng đó thấy kho mới** — và không có gì trên màn nói ra điều ấy.
2. **Trỏ tới vùng** (reference): bảng phạm vi giữ id của VÙNG, đường đọc nở nó ra thành kho lúc
   truy vấn. Sửa vùng lan tới mọi người đang mang nó, ngay lập tức.

Người dùng gọi nó là "vùng", và một cái vùng mà sửa xong không ai thấy thì đó là một bản chép
đội lốt một cái vùng.

## Decision

**Vùng dữ liệu là một loại phạm vi mới (`scope_type = "data_zone"`), và đường đọc phạm vi nở nó
ra thành kho lúc truy vấn. Không thêm cột vào bảng phạm vi, không chép id kho lúc gán.**

**1. Hai bảng mới.**

- `data_zones(id, company_id, code, name, description, ...)` — `code` là mã người quản trị gõ,
  duy nhất trong một phân vùng.
- `data_zone_warehouses(id, company_id, data_zone_id, warehouse_id, ...)` — bảng nối.

Cả hai mang `company_id NOT NULL` đọc thẳng trên bảng (R-06), `deleted_at` cho xoá mềm (R-18),
và bộ cột kiểm toán theo C-DB-05. Index theo R-09 cho mọi cột nằm trong WHERE/JOIN.

**2. `scope_type` nhận thêm một giá trị, bảng phạm vi KHÔNG đổi hình dạng.** Một hàng
`user_company_role_scopes` mang `scope_type = 'data_zone'`, `scope_id = <id của vùng>`. Migration
000023 đã cố ý không đặt `REFERENCES` trên `scope_id` và không đặt `CHECK` trên `scope_type`
(C-DB-02) — quyết định này là thứ dùng đúng chỗ trống đó, chứ không phải nới một ràng buộc.

**3. Đường đọc nở vùng ra kho, và nó nằm ở ĐÚNG MỘT chỗ.**
`selectScopeIDsTheoActorSQL` đổi thành hợp của hai vế khi loại được hỏi là `warehouse`:

- kho gán trực tiếp (`scope_type = 'warehouse'`), và
- kho nằm trong những vùng đã gán (`scope_type = 'data_zone'` JOIN `data_zone_warehouses`).

`GROUP BY` sẵn có khử trùng giữa hai vế: một kho vừa được gán trực tiếp vừa nằm trong một vùng
chỉ ra một dòng. Không consumer nào phải sửa — `scope.Resolve` và mọi module giữ nguyên.

**4. Xoá mềm một vùng KHÔNG âm thầm mở rộng quyền.** `data_zone_warehouses` và `data_zones` đều
phải mang `deleted_at IS NULL` trong vế JOIN. Thiếu một mệnh đề đó thì xoá một vùng làm mọi kho
của nó **biến mất khỏi** phạm vi (fail-close, đúng chiều) — nhưng bỏ sót ở chiều ngược lại,
`data_zone_warehouses` không lọc `deleted_at`, thì gỡ một kho khỏi vùng không có tác dụng gì và
người ta vẫn thấy kho đã gỡ. Vế thứ hai là lỗ hổng thật, và nó im lặng tuyệt đối.

**5. Vùng rỗng là hợp lệ và có nghĩa rõ ràng: không kho nào.** Không phải "tất cả". Đây là cùng
một luật mà `scope.Doc` đã khai cho danh sách rỗng, và ADR-0030 đã chốt: phạm vi trả lời "của
ai", không trả lời "còn sống không".

**6. Thứ ADR này KHÔNG quyết:** vùng dữ liệu cho loại tài nguyên khác kho (ngày có phạm vi theo
chi nhánh hay theo nhóm vật tư), và việc một vùng có lồng trong vùng khác được không. Cả hai
chưa có ca thật; dựng sẵn là dựng cho một bài toán chưa ai đặt.

## Alternatives

**Chép id kho lúc gán (materialize)** — loại, và lý do không phải chi phí. Nó tạo ra một thứ mà
người dùng gọi là "vùng" nhưng cư xử như một bản chép: sửa vùng xong, những người đã được gán
vẫn giữ danh sách cũ, và không có chỗ nào trên màn nói ra điều đó. Kiểu sai lệch đó chỉ lộ ra
nhiều tháng sau, lúc ai đó hỏi "vì sao anh ta không thấy kho mới" — và câu trả lời nằm ở một
thao tác đã xảy ra từ lâu.

**Thêm cột `data_zone_id` vào `user_company_role_scopes`** — loại. Bảng đó đã có cặp
`(scope_type, scope_id)` để trả lời đúng câu hỏi này; thêm một cột song song là hai đường biểu
diễn cho một khái niệm, và mọi câu đọc sau đó phải nhớ hỏi cả hai. Một hàng mang cả `scope_id`
của kho lẫn `data_zone_id` là một trạng thái không ai đặt tên được, mà database thì cho phép.

**Cho vùng là một `roles` đặc biệt** — loại. Vai trò trả lời "làm được việc gì", phạm vi trả lời
"trên dữ liệu nào". ADR-0020 đã tách hai trục đó và màn phân quyền dựng theo đúng hai bước ấy;
gộp lại là bỏ một quyết định đang chạy tốt để đổi lấy một bảng ít hơn.

## Consequences

**Được:** sửa một vùng lan ngay tới mọi người mang nó — đúng nghĩa người dùng chờ đợi. Chi phí
tập trung ở một câu truy vấn, không rải ra từng module. Bảng phạm vi không đổi nên không
migration nào phải viết lại dữ liệu đang có.

**Mất:** câu đọc phạm vi dài thêm một vế `UNION` và một JOIN — mỗi lần lọc theo kho tốn thêm một
lần đọc bảng nối. Đây là câu chạy trên **mọi** request có lọc theo kho, nên index của
`data_zone_warehouses` không phải chuyện tối ưu về sau mà là điều kiện để bản này lên được.

**Nợ để lại:** màn gán phạm vi hôm nay bày một danh sách kho phẳng. Sau bản này nó phải bày được
cả hai thứ — vùng và kho lẻ — và phải nói rõ kho nào đến từ vùng nào, nếu không người gán sẽ gỡ
một kho rồi ngạc nhiên vì nó vẫn còn đó.

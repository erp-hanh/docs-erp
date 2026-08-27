# ADR-0035: Vùng dữ liệu là một LOẠI PHẠM VI, không phải một cột mới

**Status:** Accepted (2026-08-24)

## Context

**Tên "vùng dữ liệu" đã từng chỉ một thứ KHÁC, và bản này không hồi sinh thứ đó.**
`99-meta/my-specs/2026-08-24-module-quan-tri-hai-man-spec.md` mục 10 (đính chính 25/08) bỏ khái
niệm *vùng dữ liệu = nhóm nhiều phân vùng*. Vùng ở ADR này là **một tập kho có tên, nằm gọn
trong MỘT phân vùng** - nó không gom phân vùng lại, và mọi bảng của nó mang `company_id` đọc
thẳng (R-06), thứ mà khái niệm cũ theo định nghĩa không có. Hai thứ khác nhau trùng tên, và chỗ
phân biệt là câu hỏi "nó gom cái gì": phân vùng, hay kho.

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
và bộ cột kiểm toán theo C-DB-03 (C-DB-05 là quy tắc index, không phải cột kiểm toán). Index theo R-09 cho mọi cột nằm trong WHERE/JOIN.

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

**6. Năm quyền mới cấp cho `quan_tri_he_thong`, và chỉ nó.** `auth.data_zone_list`,
`auth.data_zone_read`, `auth.data_zone_create`, `auth.data_zone_update`, `auth.data_zone_delete`.
Đây là chỗ bản đầu của ADR này bỏ sót: mục Context nói thẳng tạo vùng dữ liệu là một trong ba
việc của cấp 1, nhưng mục Decision không cấp quyền cho ai, nên năm endpoint trả `403` cho mọi
actor - fail-close, ồn ào, và không dùng được.

Cấp cho đúng một vai trò vì vùng dữ liệu cắt ngang mọi phân hệ: một `inventory.admin` gom được
kho vào một vùng thì anh ta tự nới phạm vi của chính mình, đúng ca mà ADR-0029 đã rào ở trục vai
trò. Ngày một quản trị phân hệ cần tự dựng vùng trong phạm vi của mình, đó là một ADR khác.

**7. Thứ ADR này KHÔNG quyết:** vùng dữ liệu cho loại tài nguyên khác kho (ngày có phạm vi theo
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

**Đính chính, lúc gỡ (2026-08-27). Quyết định này ĐÃ ĐƯỢC THI CÔNG, ĐÃ CHẠY, VÀ ĐÃ ĐƯỢC GỠ.**
ADR ở lại vì ADR là bất biến; code thì không còn. Ai đọc tới đây rồi đi tìm `data_zones` trong
`backend-erp` sẽ không thấy gì, và đó là trạng thái đúng chứ không phải một chỗ thi công còn dở.

Đường đi đầy đủ: thi công xong và lên máy dev ở `v0.1.0-rc.56`. Sau đó chủ dự án chốt là không
cần màn vùng dữ liệu nữa; `frontend-erp` gỡ màn ở `v0.1.0-rc.59`, còn backend đứng nguyên thêm
một thời gian và thành **code chết** — hai bảng, năm endpoint, một loại phạm vi mới, không màn
nào gọi tới. Phần backend gỡ ngày 2026-08-27.

**Thứ đã đi.** Hai bảng `data_zone_warehouses` và `data_zones`, bằng migration
**`000032_go_vung_du_lieu`** (bảng nối trước — `data_zone_id` mang khoá ngoại thật). Năm endpoint
`/data-zones` cùng model, repository, service, handler và phần nối ở `modules/auth/module.go`.
Năm quyền `auth.data_zone_*` ở mục 6, cùng chỗ chúng đứng trong `quan_tri_he_thong` — tập quyền
của vai trò đó trở lại **mười sáu** mã của ADR-0031 mục 1. Mã lỗi
`ERR_AUTH_DATA_ZONE_CODE_DUPLICATED` và dòng ánh xạ constraint của nó ở `C-API-http.md`. Và mục
3 — `selectScopeIDsTheoActorSQL` trở lại dạng **một vế**, đúng hình dạng nó có trước ADR này;
bốn mệnh đề `deleted_at IS NULL` của bốn bảng còn lại giữ nguyên không sót cái nào.

**Thứ ở lại, cố ý.** Migration `000031` — lịch sử migration không sửa lại được, và một migration
đã chạy trên dev thì càng không. Những hàng `user_company_role_scopes` mang
`scope_type = 'data_zone'`, nếu còn: `000032` **không** dọn chúng, và file đó ghi rõ hai lẽ (xoá
cứng một bảng nghiệp vụ là thứ R-18 cấm, và dọn ở đây làm bước lùi mất khả năng lùi). Hệ quả
phải nói ra: một hàng như vậy sau `000032` không nở ra kho nào, nên người từng chỉ được gán vùng
sẽ thấy phạm vi rỗng — fail-close, đúng chiều, nhưng im lặng.

**Thứ ADR này vẫn còn giá trị.** Mục 2 — bảng phạm vi không đổi hình dạng, `scope_type` là tập
mở — chưa bao giờ bị đụng tới và vẫn đúng. Ngày một loại phạm vi thứ hai thật sự cần đến, lập
luận ở mục Alternatives (vì sao không chép lúc gán, vì sao không thêm một cột song song) dùng
lại được nguyên vẹn. Thứ mất đi là một tính năng, không phải một quyết định.

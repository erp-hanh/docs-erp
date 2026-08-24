---
name: deploy-rc
description: Đóng một bản release candidate của hệ ERP và đẩy lên VPS dev (103.179.172.110) — tính số rc từ remote, tag cùng số trên cả ba repo infra-erp/backend-erp/frontend-erp, chạy deploy-dev.sh, rồi kiểm chứng từ máy ngoài. Dùng skill này ngay khi người dùng nói "deploy rc", "deploy lên dev", "đẩy lên dev", "lên dev đi", "tag rc mới", "ra bản rc", "release rc", "deploy bản mới", hoặc hỏi bản trên dev đang là tag nào — kể cả khi họ không nhắc chữ "rc" hay tên repo nào. Cũng dùng khi cần rollback máy dev về một tag cũ, hoặc khi người dùng hỏi vì sao dev không lên bản mới.
---

# Deploy một bản rc lên VPS dev

## 0a. Skill này và `/deploy` khác nhau chỗ nào

`/deploy` (trong `.claude/commands/`) là **quy trình chung**, portable, dùng được cho mọi
dự án: rc khác stable ra sao, cổng phê duyệt nằm ở đâu, Local → Dev → Prod đi thế nào.
Nó cố ý **không** chứa host, path, hay tên script của bất kỳ dự án nào.

Skill này là **bản đồ của đúng một máy**. Khi cả hai cùng chạm tới một việc trên ERP,
skill này thắng — nó biết địa chỉ và biết bẫy. Ngược lại, nếu việc đang làm là dựng quy
trình cho một dự án khác, hoặc cần bức tranh tổng gồm cả prod, thì đọc `/deploy`; chép
skill này sang dự án khác là chép sai toàn bộ địa chỉ.

## 0. Đọc cái này trước

**Nguồn sự thật về máy dev là `infra-erp/docs/Deploy-dev-vps.md`.** File này là quy trình;
file đó là mô tả máy. Khi hai bên lệch nhau, file đó đúng — và việc phải làm là sửa file
này chứ không phải làm theo trí nhớ.

Skill này **chỉ đụng tới môi trường dev**. Prod chưa được dựng. Nếu người dùng nói "lên
prod", dừng lại và nói thẳng là chưa có máy prod, đừng suy diễn ra một quy trình.

## 1. Hình dạng của hệ này, trong ba câu

Bốn repo trong `erp/`, ba repo được triển khai: `infra-erp` (compose + script),
`backend-erp` (api + relay + migration), `frontend-erp` (SPA). `docs-erp` là tài liệu,
không triển khai.

Trên VPS, ba repo nằm **ngang hàng** trong `/opt/erp` vì `build.context` của mọi service
tự dựng đều là `../..` — thư mục chứa cả ba.

Một lần release = **cùng một số rc trên cả ba repo**, kể cả repo không đổi dòng code nào
(tag lại đúng commit cũ). Lệch số giữa các repo là mất khả năng trả lời câu "máy dev đang
chạy chính xác cái gì".

## 2. Trước khi tag — ba điều kiện, thiếu cái nào thì dừng

1. **Code phải đã ở `main` của remote.** Tag trỏ vào `origin/main`, không trỏ vào nhánh
   cục bộ. Tag một nhánh chưa vào `main` là tag một thứ chưa ai soi.

   **Không bắt buộc phải đi qua PR.** `main` không được bảo vệ (repo private trên gói miễn
   phí nên GitHub không cho bật branch protection), nên đưa code lên `main` bằng cách nào
   cũng được. Thứ BẮT BUỘC là **làm trên một nhánh và soi lại trước khi `main` nhìn thấy** -
   bốn đợt liền, mỗi đợt final review đều tìm ra bug thật sau khi mọi task đã xong, và không
   cái nào do CI bắt. Đợt nhỏ thì `git merge` dưới máy rồi push; đợt lớn thì mở PR vì diff
   trên GitHub đọc dễ hơn và thân PR là chỗ ghi "vì sao".
2. **CI xanh trên `main`.** `gh run list --branch main --limit 1 --json conclusion,status`.
   Merge dưới máy thì CI chạy SAU khi `main` đã đổi - phải chờ nó xanh rồi mới tag, đừng tag
   ngay sau khi push.
3. **Tài khoản GitHub đúng.** `gh auth status` phải cho thấy **`hanhtv106`** đang active.
   Sai tài khoản là hỏng cả bốn repo — nếu sai thì `gh auth switch --user hanhtv106`.

Còn thay đổi chưa commit dưới máy? Nói cho người dùng biết là nó **sẽ không** có trong
bản deploy, rồi hỏi họ muốn commit trước hay deploy nguyên `main` hiện tại. Đừng tự
quyết, và cũng đừng lặng lẽ deploy thiếu.

**Điều kiện thứ tư, hay bị bỏ qua: bản này có thật sự chứa gì mới không.** So
`origin/main` của từng repo với commit mà tag rc đang chạy trỏ tới:

```bash
ssh dev-erp "for r in infra-erp backend-erp frontend-erp; do printf '%-14s %s\n' \$r \"\$(git -C /opt/erp/\$r describe --tags --always)\"; done"
```

Ba SHA trùng hết nghĩa là bản mới không đổi một dòng chạy được nào — thường vì việc thật
vẫn nằm ở nhánh chưa merge. Nói ra rồi hỏi người dùng, đừng tag một bản rỗng: nó tiêu
tốn một số rc và tạo ảo giác "đã đẩy bản mới lên rồi mà vẫn lỗi".

## 3. Số rc tính từ REMOTE, không tính từ máy

```bash
cd "d:/My project web/erp"
for d in infra-erp backend-erp frontend-erp; do
  (cd $d && git fetch --tags --prune -q origin && echo "$d: $(git tag -l 'v*' --sort=-v:refname | head -3 | tr '\n' ' ')")
done
```

`N = (rc lớn nhất thấy được trên bất kỳ repo nào) + 1`. Tag cục bộ hay tụt sau remote,
nên phải `fetch` trước rồi mới đọc. Chưa repo nào có tag thì bản đầu tiên là
`v0.1.0-rc.1`.

## 4. Tag và đẩy lên

```bash
cd "d:/My project web/erp"
RC=v0.1.0-rc.2   # thay bằng số vừa tính
for d in infra-erp backend-erp frontend-erp; do
  (cd $d && git tag -a "$RC" origin/main -m "$RC" && git push -q origin "$RC" \
   && printf '%-14s %s\n' "$d" "$(git rev-parse --short "$RC^{}")")
done
```

Dùng `origin/main` chứ không dùng `HEAD`: người dùng có thể đang đứng ở một nhánh khác
với công việc dở dang, và tag phải trỏ vào thứ đã qua review.

Đối chiếu ba SHA in ra với `git rev-parse --short origin/main` của từng repo trước khi đi
tiếp — một dòng lệch là dấu hiệu tag nhầm chỗ, sửa lúc này rẻ hơn nhiều so với sau khi
máy dev đã chạy.

## 5. Triển khai

```bash
ssh dev-erp "bash /opt/erp/infra-erp/scripts/deploy-dev.sh $RC"
```

Chạy nền (build hai ảnh Go + một ảnh frontend trên máy 2 vCPU mất vài phút, thường vượt
timeout mặc định). Script làm năm việc theo đúng thứ tự này, và thứ tự là toàn bộ giá trị
của nó: đưa ba repo về đúng ref → `compose up --build` → đợi Postgres healthy →
`migrate-up` → smoke test. Nó dừng ngay nếu Postgres không healthy, để không chạy
migration lên một database chưa nhận kết nối.

## 6. Kiểm chứng — từ MÁY NGOÀI, không phải từ trong VPS

Script đã tự kiểm từ bên trong. Phần đó không trả lời được câu hỏi "người dùng có vào
được không" và cũng không trả lời được "cổng nào đang hở ra Internet".

```bash
IP=103.179.172.110
curl -s -m 10 http://$IP:8080/health; echo
curl -s -m 10 -o /dev/null -w "ready %{http_code}\n" http://$IP:8080/ready
curl -s -m 10 -o /dev/null -w "web   %{http_code}\n" http://$IP/
curl -s -m 10 -o /dev/null -D - -X OPTIONS -H "Origin: http://$IP" \
  -H "Access-Control-Request-Method: POST" http://$IP:8080/api/v1/auth/login | grep -i access-control-allow-origin
for p in 5433 9090 3000; do curl -s -m 6 -o /dev/null -w "$p %{http_code}\n" http://$IP:$p/ || echo "$p đóng (đúng)"; done
```

Mong đợi: `/health` và `/ready` 200, web 200, preflight trả đúng `Allow-Origin`, ba cổng
cuối **không kết nối được**. Ba cổng đó mà mở là sự cố bảo mật, không phải chi tiết nhỏ:
Postgres đang dùng mật khẩu mẫu `erp/erp` và Grafana bật anonymous Viewer.

**Nhìn vào output của script xem có mục `2b. doi chieu anh` không.** Không có nghĩa là
script trên máy là bản cũ hơn bước kiểm đó — và khi ấy phải đối chiếu bằng tay, vì
`compose up --build` **không** tạo lại container chỉ vì ảnh đổi ID.

Vì sao chuyện đó xảy ra được, và nó đã xảy ra thật ở `v0.1.0-rc.4`: **script đang chạy là
bản của ref ĐANG triển khai từ trước, không phải bản của ref sắp lên.** Bước `1c` mới đưa
repo về ref mới, mà lúc đó `bash` đã đọc script rồi. Nên một bản rc có sửa
`deploy-dev.sh` thì bản sửa chỉ có tác dụng từ lần deploy **kế tiếp**. Cách xử lý: đối
chiếu image bằng tay bằng lệnh dưới đây, hoặc chạy lại chính lệnh deploy đó lần thứ hai.

Và đọc dòng `2b` báo `LECH` là **bình thường**, không phải sự cố: build không tái lập từng
byte nên mỗi lần build ra ID ảnh mới, trong khi config-hash của service thì không đổi.
Ở `v0.1.0-rc.4` cả ba service đều lệch và đều phải tạo lại.

```bash
ssh dev-erp "cd /opt/erp/infra-erp && for s in api relay web; do
  cid=\$(docker compose -f compose/dev.yml -f compose/dev-vps.yml ps -q \$s)
  ref=\$(docker inspect --format '{{.Config.Image}}' \$cid)
  anh=\$(docker image inspect \$ref --format '{{.Id}}' 2>/dev/null || echo KHONG-CON)
  cnt=\$(docker inspect --format '{{.Image}}' \$cid)
  [ \"\$anh\" = \"\$cnt\" ] && echo \"\$s: khop\" || echo \"\$s: LECH\"
done"
```

Lệch thì `docker compose -f compose/dev.yml -f compose/dev-vps.yml up -d --force-recreate api relay web`.
Đây là kiểu hỏng im lặng tuyệt đối: script in `xong`, `/health` trả 200, và thứ đang phục
vụ là bản **cũ**.

Thử đăng nhập thì nhớ **ba** trường, thiếu `company_code` sẽ trả `422` và rất dễ đọc nhầm
thành hỏng backend:

```bash
curl -s -X POST http://$IP:8080/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"company_code":"DEFAULT","email":"admin@erp.test","password":"<mật-khẩu>"}'
```

## 7. Bốn thứ trông như hỏng nhưng không phải

| Hiện tượng | Sự thật |
|---|---|
| `relay` bắn ERROR `relation "outbox" does not exist` hàng loạt | Đúng trên máy trắng: relay lên cùng compose, bảng chỉ có sau bước migrate. Chỉ đáng lo nếu **còn** sau khi script in `xong` — kiểm `docker logs --since 60s compose-relay-1`, im lặng là ổn |
| `ufw status` thấy 5433 không mở nhưng vẫn lo | ufw **không** chặn cổng Docker publish (luật iptables của Docker đứng trước). Thứ chặn thật là `host_ip: 127.0.0.1` trong `compose/dev-vps.yml` |
| Sửa `VITE_API_ORIGIN` mà giao diện vẫn gọi địa chỉ cũ | Vite nhúng giá trị vào JS lúc build. Phải build lại ảnh `web`, restart không có tác dụng |
| `CORS_ALLOWED_ORIGINS` không có cổng còn `VITE_API_ORIGIN` có | Đúng: một cái là origin của **trang** (cổng 80), một cái là địa chỉ **api** (cổng 8080) |

## 8. Rollback

```bash
ssh dev-erp "bash /opt/erp/infra-erp/scripts/deploy-dev.sh <tag-cũ>"
```

Cùng một script, khác tham số. Nhưng **migration không tự lùi**: nếu bản mới đã đổi
schema thì quay về ảnh cũ không quay được dữ liệu. Nói rõ điều này với người dùng trước
khi rollback một bản có migration, đừng để họ tưởng đã về nguyên trạng.

## 9. Cổng phê duyệt lên prod

Sau khi dev xanh, **người** phải QA thật rồi mới promote. Bằng chứng kỹ thuật ở mục 6 chỉ
nói stack chạy được và đăng nhập được — nó không nói nghiệp vụ đúng, không nói tính năng
cũ còn nguyên.

Đừng tự tạo tag stable (`v0.1.0`, bỏ hậu tố `-rc`). Đó là chữ ký phê duyệt của người
dùng, và hiện cũng chưa có máy prod để đẩy tới.

## 10. Sau khi deploy xong

Báo cho người dùng: tag nào đang chạy, ba SHA, kết quả kiểm ở mục 6, và bất cứ thứ gì
lệch so với lần trước. Nếu quy trình lộ ra chỗ nào sai hoặc thiếu, sửa
`infra-erp/docs/Deploy-dev-vps.md` — tài liệu đó phải mô tả máy như nó đang chạy thật,
không phải như nó từng chạy.

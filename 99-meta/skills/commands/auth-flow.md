Các bước
1. Server tạo biến môi trường JWT_SECRET trong file .env, không commit lên git.
2. Dựng Redis để lưu blacklist token bị revoke.
3. Thêm cột token_version (integer, default 0) vào bảng users trong database.
4. Tạo bảng refresh_tokens trong database với các cột: id, user_id, token_hash, jti, expires_at, used (boolean, default false), created_at.
5. Frontend tạo một React Context (hoặc Zustand store) để giữ access token trong memory.
6. Frontend tạo một axios instance riêng có gắn interceptor xử lý 401.
7. Server bật CSP header: default-src 'self'; script-src 'self' 'nonce-xxx'.
Bước 1 — User login
1. User nhập email, password, submit form.
2. Frontend gọi POST /api/auth/login với body { email, password }.
3. Server kiểm tra email có tồn tại không, password có khớp hash trong DB không.
4. Nếu sai, trả về 401, dừng.
5. Nếu đúng, server đọc token_version của user từ DB.
6. Server sinh access token là JWT, payload gồm: user_id, token_version, jti (UUID ngẫu nhiên), exp (hiện tại + 15 phút).
7. Server sinh refresh token là một UUID v4 ngẫu nhiên.
8. Server hash refresh token (dùng bcrypt hoặc sha256), lưu vào bảng refresh_tokens cùng user_id, jti, expires_at (hiện tại + 7 ngày), used = false.
9. Server trả response:
    * Access token nằm trong JSON body.
    * Refresh token set vào Set-Cookie với cờ: HttpOnly, Secure, SameSite=Strict, Path=/api/auth, Max-Age=604800.
10. Frontend nhận response, lưu access token vào React state (memory). Không lưu vào localStorage, không lưu vào sessionStorage.
11. Frontend chuyển user vào trang chính.
Bước 2 — Gọi API bình thường
1. Mỗi request API, axios interceptor tự động gắn header Authorization: Bearer <access_token> từ React state.
2. Server nhận request, verify JWT bằng JWT_SECRET.
3. Server decode payload, lấy user_id, token_version, jti.
4. Server kiểm tra jti có trong Redis blacklist không (key revoked_jti:<jti>). Nếu có, trả 401, dừng.
5. Server query DB lấy token_version hiện tại của user. Nếu khác với token_version trong token, trả 401, dừng.
6. Nếu mọi thứ ok, xử lý request và trả kết quả về.
Bước 3 — Access token hết hạn
1. Client gọi API, server verify JWT thấy exp đã qua, trả về 401 với mã lỗi TOKEN_EXPIRED.
2. Axios interceptor bắt được 401.
3. Interceptor kiểm tra: có phải đang có một lần gọi /renew đang chạy không? Nếu có, chờ lần đó xong rồi dùng access token mới để retry. (Tránh trường hợp 10 request cùng 401 một lúc, gọi /renew 10 lần.)
4. Nếu chưa có, interceptor gọi POST /api/auth/renew. Browser tự động gửi refresh token trong cookie httpOnly.
5. Server nhận request renew, đọc refresh token từ cookie.
6. Server hash refresh token vừa nhận, tìm trong bảng refresh_tokens.
7. Nếu không tìm thấy hoặc đã hết hạn, trả 401, dừng.
8. Nếu tìm thấy nhưng used = true (tức là đã xoay rồi mà có ai đó vẫn dùng), coi như refresh token bị đánh cắp. Server xoá toàn bộ refresh token của user này trong DB, tăng token_version lên 1, trả 401. Mọi thiết bị của user đó bị buộc đăng nhập lại.
9. Nếu hợp lệ, server:
    * Đánh dấu refresh token hiện tại là used = true.
    * Sinh access token mới (15 phút) và refresh token mới.
    * Lưu refresh token mới vào DB (used = false).
    * Trả access token mới trong JSON body.
    * Set refresh token mới vào Set-Cookie (đè lên cái cũ).
10. Frontend nhận access token mới, cập nhật React state.
11. Interceptor retry lại request ban đầu với access token mới.
12. Request ban đầu chạy thành công, user không biết gì cả.
Bước 4 — Renew token thất bại
1. Nếu /api/auth/renew trả về 401 (refresh token hết hạn, bị revoke, hoặc bị phát hiện reuse), interceptor:
2. Clear access token trong React state.
3. Gọi POST /api/auth/logout để server xoá cookie refresh token.
4. Redirect user về trang /login.
Bước 5 — User tự logout
1. User bấm nút logout.
2. Frontend gọi POST /api/auth/logout.
3. Server đọc access token hiện tại từ header, lấy jti và exp.
4. Server thêm key revoked_jti:<jti> vào Redis với TTL = exp - now (thời gian còn lại của access token).
5. Server đọc refresh token từ cookie, xoá record tương ứng trong bảng refresh_tokens.
6. Server trả về Set-Cookie với Max-Age=0 để xoá cookie ở client.
7. Frontend clear React state, redirect về /login.
Bước 6 — User bấm "Đăng xuất tất cả thiết bị" hoặc đổi mật khẩu
1. Frontend gọi POST /api/auth/logout-all (hoặc POST /api/auth/change-password).
2. Server tăng token_version của user lên 1 trong DB.
3. Server xoá toàn bộ refresh token của user trong bảng refresh_tokens.
4. Server xoá cookie refresh token ở client hiện tại (Set-Cookie Max-Age=0).
5. Từ giây phút này, mọi access token cũ của user trên mọi thiết bị đều fail ở bước verify token_version, buộc đăng nhập lại.

Tóm tắt cái gì lưu ở đâu
* Access token: React state (memory), TTL 15 phút. Không lưu localStorage, không lưu cookie.
* Refresh token: Cookie httpOnly + Secure + SameSite=Strict, TTL 7 ngày. JavaScript không đọc được.
* Hash refresh token: Bảng refresh_tokens trong database (dùng để verify và rotation).
* token_version: Cột trong bảng users (dùng để invalidate hàng loạt).
* Blacklist jti: Redis với key revoked_jti:<jti>, TTL = thời gian còn lại của token (dùng để revoke một token cụ thể).
* JWT_SECRET: Biến môi trường .env ở server.

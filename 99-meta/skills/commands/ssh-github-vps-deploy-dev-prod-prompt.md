---
name: ssh-vps-setup
description: Thiết lập SSH key (ed25519) + GitHub SSH + 2 VPS Dev/Prod chuẩn production (tắt password login, cấm root, hardening sshd, script deploy mẫu, rollback an toàn). Generic prompt — điền placeholder IP/user/repo/domain khi dùng. Đọc khi cấu hình truy cập VPS lần đầu.
---

Hãy hướng dẫn và sinh lệnh theo chuẩn production để cấu hình SSH + GitHub + VPS deploy với 2 môi trường DEV và PROD theo các yêu cầu sau:

MỤC TIÊU
1. Máy local của tôi tạo SSH key để Claude/terminal có thể truy cập SSH mà không phải nhập password đăng nhập VPS mỗi lần.
2. Public key được cấu hình đúng để dùng với GitHub qua SSH.
3. Có 2 VPS riêng: 1 VPS DEV và 1 VPS PROD, đều nhận deploy trực tiếp qua SSH từ máy local.
4. Bảo mật bắt buộc: cả 2 VPS chỉ cho phép đăng nhập bằng SSH key, tắt password login, không cho root login bằng SSH, không mở quyền truy cập từ nơi khác ngoài key của máy tôi.

YÊU CẦU TRIỂN KHAI
- Ưu tiên Ubuntu 22.04/24.04.
- Dùng SSH key loại ed25519.
- Tạo key với tên riêng, ví dụ ~/.ssh/id_ed25519_vps_deploy.
- Kiểm tra quyền file ~/.ssh, authorized_keys, và ssh config.
- Nếu VPS có file override như /etc/ssh/sshd_config.d/* thì phải kiểm tra luôn, không chỉ sửa mỗi /etc/ssh/sshd_config.
- Cấu hình SSH client ở máy local để có alias riêng:
  ssh my-vps-dev
  ssh my-vps-prod
- Cấu hình GitHub dùng SSH, test bằng:
  ssh -T git@github.com
- Repo deploy trên VPS clone bằng SSH, không dùng HTTPS.
- Tạo script deploy mẫu cho cả DEV và PROD: git pull, cài dependency, build, restart service.
- Nếu dùng PM2 hoặc Docker thì cho luôn 2 option.
- Phải có bước rollback an toàn nếu lỡ cấu hình SSH sai.
- Giải thích ngắn gọn chỗ nào chạy ở LOCAL, chỗ nào chạy ở VPS DEV, chỗ nào chạy ở VPS PROD.
- Output phải theo format:
  A. Kiến trúc đề xuất
  B. Lệnh chạy ở máy local
  C. Lệnh chạy ở VPS DEV
  D. Lệnh chạy ở VPS PROD
  E. Nội dung file config cần tạo/sửa
  F. Cách test an toàn trước khi tắt password
  G. Checklist hardening
  H. Script deploy mẫu

CHI TIẾT CẦN BAO GỒM

A. TẠO SSH KEY Ở LOCAL
- Sinh key:
  ssh-keygen -t ed25519 -C "my-vps-deploy" -f ~/.ssh/id_ed25519_vps_deploy
- Có thể để passphrase; nếu có thì hướng dẫn add vào ssh-agent để không phải nhập lại liên tục.
- Hiển thị cách xem public key:
  cat ~/.ssh/id_ed25519_vps_deploy.pub

B. CẤU HÌNH ~/.ssh/config Ở LOCAL
Tạo alias riêng cho DEV:
Host my-vps-dev
  HostName <DEV_VPS_IP>
  User <DEV_DEPLOY_USER>
  Port 22
  IdentityFile ~/.ssh/id_ed25519_vps_deploy
  IdentitiesOnly yes

Tạo alias riêng cho PROD:
Host my-vps-prod
  HostName <PROD_VPS_IP>
  User <PROD_DEPLOY_USER>
  Port 22
  IdentityFile ~/.ssh/id_ed25519_vps_deploy
  IdentitiesOnly yes

Và cho GitHub:
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_vps_deploy
  IdentitiesOnly yes

C. ADD PUBLIC KEY LÊN GITHUB
- Hướng dẫn add public key lên GitHub account.
- Nếu dùng cùng một key cho auth và signing thì nói rõ phải upload riêng theo đúng loại key.
- Test:
  ssh -T git@github.com

D. CÀI PUBLIC KEY LÊN VPS DEV
- Nếu đã login được VPS DEV lần đầu bằng password thì copy key lên server an toàn.
- Tạo user deploy riêng cho DEV, không dùng root để deploy.
- Thiết lập quyền:
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  nano ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys

E. CÀI PUBLIC KEY LÊN VPS PROD
- Nếu đã login được VPS PROD lần đầu bằng password thì copy key lên server an toàn.
- Tạo user deploy riêng cho PROD, không dùng root để deploy.
- Thiết lập quyền:
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  nano ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys

F. HARDEN SSH TRÊN CẢ 2 VPS
Phải sửa và kiểm tra toàn bộ:
- /etc/ssh/sshd_config
- /etc/ssh/sshd_config.d/*.conf

Thiết lập mong muốn:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no

Nếu muốn chặt hơn thì thêm:
AuthenticationMethods publickey
AllowUsers <DEV_DEPLOY_USER>   # trên DEV
AllowUsers <PROD_DEPLOY_USER>  # trên PROD

Sau đó:
sudo sshd -t
sudo systemctl restart ssh || sudo systemctl restart sshd

G. CÁCH TEST AN TOÀN
- Không được logout phiên SSH hiện tại trên DEV hoặc PROD trước khi test xong terminal mới.
- Mở terminal mới và test:
  ssh my-vps-dev
  ssh my-vps-prod
- Xác nhận login thành công bằng key trên từng VPS trước.
- Chỉ sau khi test OK trên cả 2 môi trường mới coi như hoàn tất việc tắt password.

H. DEPLOY TỪ GITHUB TRÊN VPS DEV
- Trên VPS DEV:
  git clone git@github.com:<OWNER>/<REPO>.git /var/www/<APP_NAME_DEV>
- Branch khuyến nghị:
  develop hoặc dev
- App name, port, domain/subdomain cho DEV phải tách riêng PROD.
- Ví dụ:
  /var/www/myapp-dev
  PM2 process: myapp-dev
  Domain: dev.example.com

I. DEPLOY TỪ GITHUB TRÊN VPS PROD
- Trên VPS PROD:
  git clone git@github.com:<OWNER>/<REPO>.git /var/www/<APP_NAME_PROD>
- Branch khuyến nghị:
  main hoặc master
- App name, port, domain cho PROD phải tách riêng DEV.
- Ví dụ:
  /var/www/myapp-prod
  PM2 process: myapp-prod
  Domain: example.com

J. SCRIPT MẪU CHO DEV
Ví dụ deploy-dev.sh:
#!/usr/bin/env bash
set -e
cd /var/www/<APP_NAME_DEV>
git pull origin develop
npm ci
npm run build
pm2 restart <APP_NAME_DEV>

Hoặc Docker:
#!/usr/bin/env bash
set -e
cd /var/www/<APP_NAME_DEV>
git pull origin develop
docker compose up -d --build

K. SCRIPT MẪU CHO PROD
Ví dụ deploy-prod.sh:
#!/usr/bin/env bash
set -e
cd /var/www/<APP_NAME_PROD>
git pull origin main
npm ci
npm run build
pm2 restart <APP_NAME_PROD>

Hoặc Docker:
#!/usr/bin/env bash
set -e
cd /var/www/<APP_NAME_PROD>
git pull origin main
docker compose up -d --build

L. ROLLBACK AN TOÀN
- Trước khi sửa SSH config, backup lại file:
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
- Nếu có file trong /etc/ssh/sshd_config.d/, backup luôn toàn bộ thư mục cấu hình liên quan.
- Sau khi sửa:
  sudo sshd -t
- Chỉ restart khi validate thành công.
- Nếu bị lỗi, restore file backup và restart lại SSH từ phiên đang còn mở.

M. BẢO MẬT BẮT BUỘC
- Không bao giờ commit private key.
- Không chép private key lên VPS DEV hoặc PROD.
- Mỗi VPS chỉ giữ public key trong authorized_keys.
- Quyền file đúng chuẩn: 700 cho ~/.ssh và 600 cho authorized_keys.
- Không deploy bằng root.
- Nên dùng deploy user riêng cho DEV và PROD.
- Nếu deploy tự động từ GitHub Actions thì dùng deploy key riêng, read-only nếu phù hợp.
- Nếu dùng personal key để pull repo trên VPS thì giải thích rõ rủi ro và khuyên dùng deploy key/repo key riêng.
- Có thể dùng 1 key local để SSH vào cả DEV và PROD, nhưng nếu cần mức an toàn cao hơn thì khuyên tách riêng 2 key:
  ~/.ssh/id_ed25519_vps_dev
  ~/.ssh/id_ed25519_vps_prod
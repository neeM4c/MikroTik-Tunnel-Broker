# MikroTik Docker Tunneling (6to4 + GRE IPv6)

Automated script to deploy MikroTik CHR on Ubuntu (alongside Hiddify, Marzban, etc.) and set up a high-speed, obfuscated tunnel to your home MikroTik.

**Features:**
* **Dockerized:** Keeps your main server clean.
* **Obfuscated:** Uses GRE inside IPv6 inside IPv4 (Protocol 41).
* **Optimized:** Auto-configures MTU (1380) and MSS (1340) for maximum speed.
* **Firewall Friendly:** Automatically handles `iptables` to forward traffic to Docker.

## Prerequisites
1.  **Ubuntu Server** (Outside Iran).
2.  **MikroTik Router** (Inside Iran) behind a Modem/NAT.
3.  **Static IP** for your Internet in Iran (Required for 6to4).
4.  **DMZ Enabled** on your Iran Modem pointing to your MikroTik.

## Quick Install (Server Side)

Run this command on your VPS:


این دستور چه کار می‌کند؟
اسکریپت را مستقیم از گیت‌هاب  می‌خواند.

داکر و میکروتیک را نصب می‌کند. (باید خودتان برای میکروتیک لایسنس بزنید و الا سرعتش به شدت کند میشود )

آی‌پی‌های سرور را خودش پیدا می‌کند.

فقط آی‌پی ثابت منزل را از تون می‌پرسد.

و در آخر، کدهای آماده برای وینباکس سرور و وینباکس خانه را برای وارد کردن در ترمینال وینباکس تحویل می‌دهد.


```bash
bash <(curl -fsSL https://raw.githubusercontent.com/neeM4c/MikroTik-Tunnel-Broker/main/install.sh)

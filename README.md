## 🚀 Auto-WP-WooEcomerce

Script bash otomatis ini menginstal lingkungan WordPress lengkap pada Ubuntu 22.04/24.04 dengan:

- **Nginx** (stable terbaru, header keamanan, versi tersembunyi)
- **PHP 8.1/8.2/8.3** (dioptimalkan & diamankan)
- **MariaDB 10.11** (otomatis teramankan)
- **SSL Let's Encrypt** (perpanjangan otomatis, dukungan wildcard untuk multisite)
- **WordPress** (versi terbaru, opsi multisite, prefix tabel unik)
- **WooCommerce** (terkonfigurasi penuh – toko Indonesia siap: IDR, COD, Transfer Bank, produk contoh)
- **Penguatan Keamanan** – Firewall UFW, Fail2ban, Wordfence, disable_functions PHP, header keamanan Nginx, blokir xmlrpc.php
- **Integrasi** – UpdraftPlus (backup otomatis harian), WP Mail SMTP (siap diatur SMTP)

Semua komponen telah dikonfigurasi agar **bekerja tanpa sentuhan manual** – toko e-commerce Anda langsung aktif setelah instalasi.

---

## 📋 Persyaratan

- **Server Ubuntu 22.04 atau 24.04 baru** (minimal 2GB RAM, 20GB disk)
- **Akses root** (script harus dijalankan sebagai root atau dengan `sudo`)
- **Nama domain** yang mengarah ke IP publik server (record DNS A)
- **Port terbuka** 80, 443 (akan diizinkan otomatis oleh UFW)
- **Koneksi internet** (untuk mengunduh paket, WordPress, plugin)

---

## ⚡ Mulai Cepat

1. **Salin script** ke server Anda (misal: `install.sh`)
2. **Buat dapat dieksekusi**  
   ```bash
   chmod +x wp-wooecomerce.sh
   ```
3. **Jalankan sebagai root**  
   ```bash
   sudo ./wp-wooecomerce.sh
   ```
4. **Jawab beberapa pertanyaan** (domain, email, versi PHP, kredensial admin)
5. **Tunggu 5–10 menit** – semuanya otomatis
6. **Akses website Anda** di `https://domainanda.com`

---

## 🛠️ Yang Dilakukan Script (Langkah demi Langkah)

| Tahap | Aksi |
|-------|------|
| **Persiapan sistem** | Update OS, install dependensi (curl, wget, unzip, nginx, certbot, ufw, fail2ban) |
| **PHP** | Menambah PPA ondrej/php, install versi PHP pilihan + ekstensi, terapkan optimasi dan hardening (`disable_functions`, `expose_php=Off`) |
| **Database** | Install MariaDB, hapus pengaturan tidak aman, buat database/user/password unik |
| **WordPress** | Unduh WP terbaru, buat `wp-config.php` dengan salt, prefix tabel khusus, konstanta hardening (`DISALLOW_FILE_EDIT`, `WP_AUTO_UPDATE_CORE`) |
| **WooCommerce** | Install dan aktifkan WooCommerce, buat halaman toko, atur mata uang Indonesia (IDR), pembayaran COD & transfer bank, tambah produk contoh |
| **Plugin** | Install **UpdraftPlus** (backup harian, simpan 5 salinan), **WP Mail SMTP** (fallback PHP mail), **Wordfence** (pemindaian keamanan harian) |
| **Konfigurasi Nginx** | Buat virtual host dengan header keamanan, `client_max_body_size 100M`, blokir `xmlrpc.php`, nonaktifkan daftar direktori, sembunyikan versi |
| **SSL** | Dapatkan sertifikat Let's Encrypt (wildcard untuk multisite subdomain), paksa redirect HTTPS |
| **Firewall** | Konfigurasi UFW (izinkan SSH, HTTP, HTTPS saja), aktifkan Fail2ban untuk SSH dan Nginx |
| **Izin** | Atur kepemilikan dan izin ketat (`wp-config.php` 600) |
| **File info** | Simpan semua kredensial ke `/root/domainanda-conf.txt` |

---

## 📝 Input Interaktif

Saat menjalankan script, Anda akan diminta:

| Pertanyaan | Contoh | Catatan |
|------------|--------|---------|
| Domain | `tokoanda.com` | Harus sudah mengarah ke IP server |
| Versi PHP | `8.2` | Pilihan: 8.1, 8.2, 8.3 |
| Email untuk SSL & admin | `admin@tokoanda.com` | Digunakan untuk Let's Encrypt dan admin WP |
| Judul website | `Toko Online Saya` | |
| Username admin | `admin` | |
| Password admin | (kosongkan untuk auto-generate) | Password kuat dibuat jika kosong |
| WordPress Multisite? | `n` (default) | Ketik `y` hanya jika butuh multisite |
| Tipe multisite (jika ya) | `1` (subdomain) atau `2` (subdirektori) | |

Semua fitur lain (WooCommerce, keamanan, backup, SMTP) **terinstal secara default** – tidak ada pertanyaan tambahan.

---

## 🔐 Fitur Keamanan yang Disertakan

| Komponen | Hardening yang Diterapkan |
|----------|---------------------------|
| **PHP** | Nonaktifkan fungsi berbahaya, sembunyikan versi, nonaktifkan `allow_url_fopen` |
| **Nginx** | Header keamanan (X‑Frame‑Options, X‑Content‑Type‑Options, XSS‑Protection, Referrer‑Policy), `server_tokens off`, blokir `/xmlrpc.php` |
| **WordPress** | Prefix tabel unik, salts, `DISALLOW_FILE_EDIT`, update minor otomatis, debug nonaktif |
| **Sistem** | Firewall UFW (hanya port 22,80,443), Fail2ban (blokir brute force setelah 5 percobaan) |
| **Plugin** | Wordfence – pemindaian malware harian (dapat ditingkatkan ke firewall real-time) |

---

## 🛒 E‑Commerce (WooCommerce) – Siap Pakai

Setelah instalasi, toko Anda memiliki:

- **Halaman produk**, **Keranjang**, **Checkout**, **Akun Saya** – semua halaman dibuat
- **Mata uang** : Rupiah Indonesia (IDR) dengan format yang benar
- **Metode pembayaran** : Cash on Delivery + Transfer Bank (BACS) – keduanya aktif
- **Produk contoh** : Satu produk contoh dengan harga 100.000 IDR
- **Pajak** : Dinonaktifkan (Anda dapat mengaktifkannya nanti di pengaturan WooCommerce)

Anda bisa mulai menjual segera – cukup ganti produk contoh dan tambahkan detail rekening bank Anda.

---

## 💾 Integrasi Backup & Email

| Integrasi | Fungsinya | Cara mengelola |
|-----------|-----------|----------------|
| **UpdraftPlus** | Backup penuh harian (file + DB) jam 12 malam, simpan 5 versi terbaru | Akses melalui admin WP → Settings → UpdraftPlus |
| **WP Mail SMTP** | Menggunakan PHP mail() sebagai fallback; siap konfigurasi SMTP nyata (Gmail, SendGrid, dll) | Admin → WP Mail SMTP → Settings |

---

## 📂 File & Direktori

| Path | Deskripsi |
|------|------------|
| `/var/www/domainanda.com/` | Document root WordPress |
| `/etc/nginx/sites-available/domainanda.com` | Server block Nginx |
| `/etc/php/8.x/fpm/conf.d/custom.ini` | Pengaturan performa PHP |
| `/etc/php/8.x/fpm/conf.d/security.ini` | PHP disable_functions dll. |
| `/root/domainanda-conf.txt` | **Semua kredensial** (database, admin, dll) |
| `/var/log/nginx/domainanda_access.log` | Log akses |
| `/var/log/nginx/domainanda_error.log` | Log error |

---

## ❓ Pemecahan Masalah

### 🔄 Sertifikat SSL gagal
- Pastikan DNS domain memiliki record A yang mengarah ke IP publik server.
- Tunggu beberapa menit setelah perubahan DNS, lalu jalankan:
  ```bash
  certbot --nginx -d domainanda.com -d www.domainanda.com
  ```

### 🚫 "502 Bad Gateway" setelah instalasi
- Periksa apakah PHP-FPM berjalan:
  ```bash
  systemctl status php8.2-fpm
  ```
- Periksa konfigurasi Nginx:
  ```bash
  nginx -t
  ```

### 🛡️ Firewall memblokir sesuatu
- Lihat aturan UFW:
  ```bash
  ufw status verbose
  ```
- Untuk mengizinkan port tambahan (misal 8080):
  ```bash
  ufw allow 8080/tcp
  ```

### 📧 Email tidak berfungsi
- WP Mail SMTP disetel ke PHP mail(). Install `postfix` atau konfigurasi kredensial SMTP nyata di pengaturan plugin.

### 🔁 Menjalankan ulang script?
Jangan jalankan ulang pada domain yang sama – script akan mencoba membuat ulang database dan menimpa file. Gunakan hanya pada server baru atau setelah membersihkan `/var/www/` dan database.

---

## 📜 Lisensi
[License]()

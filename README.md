# 📝 To-Do List Pro & Finance Tracker

Aplikasi produktivitas **All-in-One** yang dibangun menggunakan **Flutter**. Aplikasi ini menggabungkan manajemen tugas (To-Do List) yang kuat dengan pencatatan keuangan pribadi yang sederhana, dikemas dalam antarmuka yang modern dan responsif.

Saat ini aplikasi mendukung penyimpanan lokal (Offline-First) menggunakan SQLite dan sistem Login menggunakan Firebase Authentication.

## ✨ Fitur Unggulan

### 🎯 Manajemen Tugas (To-Do List)
- **CRUD Tugas:** Tambah, Edit, Hapus, dan Tandai Selesai.
- **Kategori & Prioritas:** Kelompokkan tugas (Kuliah, Kerja, Pribadi) dan atur tingkat urgensi (Tinggi, Sedang, Rendah).
- **Pengingat:** Atur tanggal dan waktu deadline.
- **Pencarian:** Cari tugas dengan cepat.

### 💰 Manajemen Keuangan
- **Pencatatan Transaksi:** Catat Pemasukan, Pengeluaran, dan Transfer.
- **Ringkasan Saldo:** Lihat total saldo, total pemasukan, dan pengeluaran secara real-time.
- **Riwayat Transaksi:** List transaksi yang rapi dengan indikator warna.

### 👤 Profil & Gamifikasi
- **Sistem Login:** Login dan Register aman menggunakan **Firebase Authentication**.
- **Statistik Produktivitas:** Grafik batang progres mingguan.
- **Sistem Lencana (Badges):** Dapatkan lencana (Perunggu, Perak, Emas) berdasarkan jumlah tugas yang diselesaikan.
- **Target Harian:** Atur target jumlah tugas per hari.

### ⚙️ Pengaturan & Kustomisasi
- **Tema:** Dukungan **Dark Mode** & Light Mode (atau mengikuti sistem).
- **Ukuran Teks:** Sesuaikan ukuran huruf (Kecil, Normal, Besar).
- **Warna Tema:** Ganti warna dominan aplikasi sesuai selera.

## 🛠️ Teknologi yang Digunakan

- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Backend (Auth):** [Firebase Authentication](https://firebase.google.com/docs/auth)
- **Database Lokal:** [SQFLite](https://pub.dev/packages/sqflite) (SQLite untuk Flutter)
- **Penyimpanan Lokal:** [Shared Preferences](https://pub.dev/packages/shared_preferences) (Untuk pengaturan tema/settings)
- **UI Components:** Google Material Design 3, `flutter_slidable`, `intl`, `image_picker`.

## 📸 Screenshots

Berikut adalah tampilan antarmuka dari aplikasi:

| Beranda | Menu Navigasi | Keuangan | Kalender | Profil & Statistik |
| <img src="android/public/asset/img/beranda.jpeg" width="200" alt="Beranda"> | <img src="android/public/asset/img/WhatsApp%20Image%202026-01-11%20at%2015.07.31.jpeg" width="200" alt="Menu Drawer"> | <img src="android/public/asset/img/keuangan.jpeg" width="200" alt="Keuangan"> | <img src="android/public/asset/img/Kalender.jpeg" width="200" alt="Kalender"> | <img src="android/public/asset/img/WhatsApp%20Image%202026-01-11%20at%2015.07.32.jpeg" width="200" alt="Profil User"> |


## 🚀 Cara Menjalankan (Instalasi)

Ikuti langkah ini untuk menjalankan project di lokal komputer Anda:

1.  **Clone Repositori ini:**
    ```bash
    git clone [https://github.com/egaa884/To-do-list-app.git](https://github.com/egaa884/To-do-list-app.git)
    cd To-do-list-app
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Konfigurasi Firebase (PENTING ⚠️):**
    - Buat project di [Firebase Console](https://console.firebase.google.com/).
    - Download file `google-services.json` dari project Firebase Anda.
    - Letakkan file tersebut di folder: `android/app/google-services.json`.

4.  **Jalankan Aplikasi:**
    Pastikan emulator Android sudah jalan atau HP terhubung.
    ```bash
    flutter run
    ```

## 📂 Struktur Folder

- `lib/main.dart`: Entry point, routing, dan logika inisialisasi.
- `lib/auth_page.dart`: Halaman Login & Register.
- `lib/database_helper.dart`: Pengelola koneksi database SQLite.
- `lib/task_model.dart` & `transaction_model.dart`: Model data.
- `lib/notification_service.dart`: (Opsional) Service notifikasi.

## 🔜 Roadmap (Rencana Selanjutnya)

- [ ] Sinkronisasi data tugas & keuangan ke Cloud Firestore (Multi-device).
- [ ] Notifikasi Push lokal yang lebih kompleks.
- [ ] Export laporan keuangan ke PDF/Excel.

## 🤝 Kontribusi

Jika ingin berkontribusi, silakan *fork* repositori ini dan buat *Pull Request*. Saran dan masukan sangat dihargai!

---
**Developed by [Ega](https://github.com/egaa884)**
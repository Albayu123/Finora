# Finora (`finora_app`)

Aplikasi pencatat pemasukan dan pengeluaran **offline-first** berbasis **Flutter** dan **Dart** dengan antarmuka berbahasa Indonesia. Seluruh transaksi disimpan terlebih dahulu di **SQLite** lokal sebagai *Single Source of Truth*, lalu dapat dicadangkan secara satu arah ke **Cloud Firestore** setelah pengguna masuk akun.

Target platform aktif saat ini: **Linux Desktop** dan **Web**.

## Fitur Utama

- **Penyimpanan Lokal Offline-First (SQLite):** Mencatat, mengubah, dan menghapus transaksi (`income` / `expense`) dengan ID UUID v4 dan penanda `is_synced`. Menggunakan `sqflite_common_ffi` di Linux Desktop/test serta `sqflite_common_ffi_web` di Web.
- **Ringkasan Saldo & Filter:** Menghitung saldo bersih, total pemasukan, total pengeluaran, pencarian transaksi, dan filter kategori arus kas (`Semua`, `Pemasukan`, `Pengeluaran`).
- **Konversi Kurs USD / IDR:** Terintegrasi dengan ExchangeRate-API v6 (`/v6/<KEY>/latest/USD`) dengan cache lokal di `SharedPreferences` agar konversi tetap berjalan saat offline.
- **Autentikasi Sederhana & Cadangan Cloud Firestore:** Login dan pendaftaran Email/Password serta sinkronisasi satu arah transaksi yang belum tercadang (`is_synced = 0`) ke koleksi `users/{uid}/transactions/{id}` pada project Firebase `finora-app-a0531`.
- **Mode Terang & Gelap:** Pergantian tema yang tersimpan di `SharedPreferences`.

## Arsitektur & Struktur Proyek

Proyek ini mengikuti pola **MVVM (Model-View-ViewModel)** dengan **Provider**:

```text
.
├── .env.example                      # Template variabel environment lokal
├── lib/
│   ├── main.dart                     # Entry point, load .env, Firebase init, & MultiProvider
│   ├── firebase_options.dart         # Konfigurasi Firebase Web (finora-app-a0531)
│   ├── config/
│   │   └── env_config.dart           # Loader file .env dari Flutter asset
│   ├── models/
│   │   └── transaction_model.dart    # Model transaksi, kategori, & serialisasi SQLite/Firestore
│   ├── services/
│   │   ├── auth_service.dart         # Autentikasi FirebaseAuth (Web) & REST fallback (Linux)
│   │   ├── currency_api_service.dart # Klien ExchangeRate-API v6 & cache kurs
│   │   ├── database_helper.dart      # CRUD SQLite lokal
│   │   └── firestore_service.dart    # Cadangan Cloud Firestore (Web) & REST fallback (Linux)
│   ├── theme/
│   │   └── app_theme.dart            # Konfigurasi Material 3 tema terang & gelap
│   ├── utils/
│   │   └── formatters.dart           # Pemformatan angka IDR/USD & tanggal
│   ├── viewmodels/
│   │   ├── auth_viewmodel.dart       # State autentikasi
│   │   ├── theme_viewmodel.dart      # State tema terang/gelap
│   │   └── transaction_viewmodel.dart# Logika bisnis transaksi, kurs, & sinkronisasi
│   └── views/
│       ├── home_screen.dart          # Dashboard ringkasan saldo, konverter, & daftar transaksi
│       ├── add_transaction_screen.dart# Form tambah/ubah transaksi
│       └── auth_dialog.dart          # Dialog masuk, daftar akun, & keluar
├── test/                             # Unit test dan widget test
└── docs/
    ├── ARCHITECTURE.md               # Catatan arsitektur teknis & integrasi
    └── DESIGN.md                     # Panduan arah desain UI
```

## Persiapan & Cara Menjalankan

### 1. Konfigurasi API Key (`.env`)

Salin template `.env.example` menjadi `.env`, lalu isi `EXCHANGE_RATE_API_KEY` dari ExchangeRate-API:

```bash
cp .env.example .env
```

Isi file `.env`:

```dotenv
EXCHANGE_RATE_API_KEY=api_key_anda
```

File `.env` sudah terdaftar di `.gitignore` agar tidak ikut ter-commit, dan didaftarkan di `pubspec.yaml` (`assets:`) sehingga terbaca otomatis baik di Linux maupun Web tanpa flag `--dart-define`. Jika perlu menimpa key saat build/run, `--dart-define=EXCHANGE_RATE_API_KEY=...` juga tetap didukung sebagai fallback.

### 2. Pengaturan Firebase Console (`finora-app-a0531`)

1. Buka **Authentication -> Sign-in method**, lalu aktifkan provider **Email/Password**.
2. Buka **Firestore Database -> Create database** dan atur Security Rules agar setiap pengguna hanya dapat mengakses `users/{userId}/transactions/{transactionId}` miliknya sendiri (`request.auth != null && request.auth.uid == userId`).

### 3. Install Dependency & Jalankan Aplikasi

```bash
flutter pub get

# Jalankan di Linux Desktop
flutter run -d linux

# Jalankan di Web (Chrome)
flutter run -d chrome
```

## Pengujian & Verifikasi

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed .
```

Seluruh pengujian unit dan widget (`test/transaction_model_test.dart`, `test/database_helper_test.dart`, `test/currency_api_service_test.dart`, `test/transaction_viewmodel_test.dart`, dan `test/widget_test.dart`) berjalan menggunakan `sqflite_common_ffi` in-memory dan mock HTTP client.

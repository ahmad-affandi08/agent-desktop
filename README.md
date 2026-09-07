# RSSG Agent Desktop

Aplikasi Flutter Desktop terpadu untuk SilentPrint (port 3007) serta automasi biometrik BPJS SidikJari dan BPJS FRISTA (port 3009).

## Fitur Biometrik Terpadu (SidikJari & FRISTA)

Release Windows tidak membutuhkan helper eksternal, instalasi Python, atau AutoHotkey. Seluruh alur ditangani langsung oleh aplikasi:

- Membuka aplikasi resmi BPJS (`After.exe` untuk SidikJari atau `frista.exe` untuk FRISTA) bila belum berjalan.
- Menggunakan kembali (*reuse*) jendela aplikasi yang sudah aktif.
- Menangani aktivasi window ke baris paling depan (*foreground*).
- Mengisi nomor NIK / BPJS ke field input pasien secara otomatis.
- Menyediakan endpoint HTTP lokal untuk diintegrasikan dengan SIMRS:
  - `POST /open-sidikjari`: automasi aplikasi SidikJari.
  - `POST /open-frista`: automasi aplikasi FRISTA.
  - `POST /open-biometric`: automasi biometrik fleksibel (parameter `type: "sidikjari" | "frista"`).
  - `POST /frista/reset` dan `GET /frista/health`.

Lokasi default executable:
- SidikJari: `C:\Program Files (x86)\Aplikasi Sidik Jari BPJS Kesehatan\After.exe`
- FRISTA: `C:\Users\User\Documents\frista.exe` (dapat disesuaikan di tab **Settings**)

## Build Windows

```powershell
flutter pub get
flutter build windows --release
```

Distribusikan seluruh isi folder berikut sebagai satu paket:

```text
build\windows\x64\runner\Release\
```

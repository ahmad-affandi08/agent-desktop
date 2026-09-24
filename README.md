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

## Rilis & Update ke PC Loket

1. Naikkan `version` di `pubspec.yaml`, commit, lalu buat tag:
   ```bash
   git tag v1.2.0 && git push origin main --tags
   ```
2. GitHub Actions membuild `RSSG-Agent-Setup-1.2.0.exe` dan memasangnya di halaman **Releases**.
3. Di PC loket cukup jalankan setup tersebut. Installer otomatis menutup agent yang masih berjalan
   (termasuk yang tersembunyi di tray), menimpa file, lalu menjalankannya kembali — tanpa restart PC
   dan tanpa hak admin. Pengaturan di tab **Settings** tetap tersimpan.

Installer langsung menimpa folder agent yang sedang berjalan (termasuk hasil copy manual versi lama).
Jika agent tidak berjalan, dipakai folder install sebelumnya, atau `%LOCALAPPDATA%\Programs\RSSG Agent Desktop`
untuk instalasi baru. Tersedia opsi autostart saat Windows menyala. Aplikasi bersifat *single instance*: membuka exe lagi hanya memunculkan window
yang sudah berjalan.

Build installer secara lokal (Windows, Inno Setup 6):

```powershell
flutter build windows --release
iscc /DAppVersion=1.2.0 installer\rssg_agent_desktop.iss
```

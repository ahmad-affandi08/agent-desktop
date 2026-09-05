# RSSG Agent Desktop

Aplikasi Flutter Desktop terpadu untuk SilentPrint (port 3007) dan automasi
BPJS SidikJari (port 3009).

## SidikJari tanpa helper

Release Windows tidak membutuhkan `sidikjari-autofill.exe`, instalasi Python,
atau AutoHotkey. Seluruh alur berikut ditangani oleh aplikasi:

- membuka `After.exe` bila belum berjalan;
- menangani dialog **Setting Koneksi** pada pemasangan pertama;
- login menggunakan kredensial dari Settings;
- memilih jenis identitas NIK atau BPJS dan mengisi nomor pasien; dan
- menggunakan kembali sesi aplikasi yang masih aktif.

Automasi memakai API Win32 melalui Windows PowerShell bawaan sistem. Aksi GUI
dijalankan secara berurutan agar request pasien yang bersamaan tidak saling
menimpa.

Satu-satunya aplikasi eksternal yang harus terpasang adalah aplikasi resmi BPJS
SidikJari, dengan lokasi default:

```text
C:\Program Files (x86)\Aplikasi Sidik Jari BPJS Kesehatan\After.exe
```

Lokasi, username, dan password dapat diubah dari tab **Settings**.

## Build Windows

```powershell
flutter pub get
flutter build windows --release
```

Distribusikan seluruh isi folder berikut sebagai satu paket:

```text
build\windows\x64\runner\Release\
```

Workflow GitHub Actions juga menghasilkan `rssg_agent_desktop-windows.zip`.

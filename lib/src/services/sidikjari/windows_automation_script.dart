/// Self-contained Windows automation used by `SidikJariService`.
///
/// It is encoded and executed in Windows PowerShell, which is part of the OS.
/// The release therefore needs no Python, AutoHotkey, or helper executable.
const windowsSidikJariAutomationScript = r'''
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class RssgSidikJariNative {
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT {
        public uint type;
        public InputUnion data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mouse;
        [FieldOffset(0)] public KEYBDINPUT keyboard;
        [FieldOffset(0)] public HARDWAREINPUT hardware;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extraData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool ShowWindowAsync(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter,
        int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT rectangle);

    [DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    private static extern void mouse_event(uint flags, uint dx, uint dy,
        uint data, UIntPtr extraInfo);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, INPUT[] inputs, int size);

    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint KEYEVENTF_UNICODE = 0x0004;
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_A = 0x41;

    static RssgSidikJariNative() {
        try { SetProcessDPIAware(); } catch { }
    }

    public static IntPtr FindWindowContaining(string included, string excluded) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) return true;
            StringBuilder title = new StringBuilder(512);
            GetWindowText(hWnd, title, title.Capacity);
            string value = title.ToString();
            bool includes = value.IndexOf(included, StringComparison.OrdinalIgnoreCase) >= 0;
            bool excludes = !String.IsNullOrEmpty(excluded) &&
                value.IndexOf(excluded, StringComparison.OrdinalIgnoreCase) >= 0;
            if (includes && !excludes) {
                found = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void ActivateAndNormalize(IntPtr hWnd) {
        if (hWnd == IntPtr.Zero) throw new InvalidOperationException("Window handle is empty");
        ShowWindowAsync(hWnd, 6);
        Thread.Sleep(50);
        ShowWindowAsync(hWnd, 9);
        SetWindowPos(hWnd, new IntPtr(-1), 0, 0, 720, 500, 0x0040);
        SetWindowPos(hWnd, new IntPtr(-2), 0, 0, 720, 500, 0x0040);
        BringWindowToTop(hWnd);
        SetForegroundWindow(hWnd);
        Thread.Sleep(200);
    }

    public static void ClickRelative(IntPtr hWnd, int x, int y) {
        RECT rectangle;
        if (!GetWindowRect(hWnd, out rectangle)) {
            throw new InvalidOperationException("Cannot read target window position");
        }
        SetCursorPos(rectangle.left + x, rectangle.top + y);
        Thread.Sleep(50);
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
    }

    private static void SendKey(ushort virtualKey, ushort scanCode, uint flags) {
        INPUT input = new INPUT();
        input.type = INPUT_KEYBOARD;
        input.data.keyboard.wVk = virtualKey;
        input.data.keyboard.wScan = scanCode;
        input.data.keyboard.dwFlags = flags;
        INPUT[] inputs = new INPUT[] { input };
        if (SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT))) == 0) {
            throw new InvalidOperationException("SendInput failed: " + Marshal.GetLastWin32Error());
        }
    }

    public static void Press(ushort virtualKey) {
        SendKey(virtualKey, 0, 0);
        SendKey(virtualKey, 0, KEYEVENTF_KEYUP);
    }

    public static void SelectAll() {
        SendKey(VK_CONTROL, 0, 0);
        Press(VK_A);
        SendKey(VK_CONTROL, 0, KEYEVENTF_KEYUP);
    }

    public static void TypeUnicode(string value, int delayMilliseconds) {
        if (value == null) return;
        foreach (char character in value) {
            SendKey(0, character, KEYEVENTF_UNICODE);
            SendKey(0, character, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP);
            if (delayMilliseconds > 0) Thread.Sleep(delayMilliseconds);
        }
    }
}
"@

function Find-MainWindow {
    $window = [RssgSidikJariNative]::FindWindowContaining(
        'Aplikasi Registrasi Sidik Jari', '')
    if ($window -eq [IntPtr]::Zero) {
        $window = [RssgSidikJariNative]::FindWindowContaining(
            'Verifikasi dan Registrasi Sidik Jari', '')
    }
    return $window
}

function Find-LoginWindow {
    $window = [RssgSidikJariNative]::FindWindowContaining(
        'Registrasi Sidik Jari', 'Aplikasi Registrasi Sidik Jari')
    $main = [RssgSidikJariNative]::FindWindowContaining(
        'Verifikasi dan Registrasi Sidik Jari', '')
    if ($window -eq $main) { return [IntPtr]::Zero }
    return $window
}

function Wait-ForWindow([scriptblock]$finder, [int]$timeoutSeconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($timeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $window = & $finder
        if ($window -ne [IntPtr]::Zero) { return $window }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}

function Set-FieldText([string]$value, [int]$delayMilliseconds) {
    [RssgSidikJariNative]::SelectAll()
    [RssgSidikJariNative]::TypeUnicode($value, $delayMilliseconds)
}

$username = $env:RSSG_SIDIKJARI_USERNAME
$password = $env:RSSG_SIDIKJARI_PASSWORD
$identifier = $env:RSSG_SIDIKJARI_IDENTIFIER
$identifierType = $env:RSSG_SIDIKJARI_IDENTIFIER_TYPE

if ([string]::IsNullOrWhiteSpace($username)) { throw 'Username BPJS kosong.' }
if ([string]::IsNullOrWhiteSpace($password)) { throw 'Password BPJS kosong.' }
if ([string]::IsNullOrWhiteSpace($identifier)) { throw 'NIK/nomor BPJS kosong.' }

try {
    Write-Output '[AUTO] Mencari window aplikasi SidikJari...'
    $mainWindow = Find-MainWindow

    if ($mainWindow -eq [IntPtr]::Zero) {
        $settingWindow = Wait-ForWindow {
            [RssgSidikJariNative]::FindWindowContaining('Setting Koneksi', '')
        } 5
        if ($settingWindow -ne [IntPtr]::Zero) {
            Write-Output '[AUTO] Setting Koneksi terdeteksi; mengisi URL service.'
            [RssgSidikJariNative]::ActivateAndNormalize($settingWindow)
            [RssgSidikJariNative]::ClickRelative($settingWindow, 235, 325)
            Set-FieldText 'https://fp.bpjs-kesehatan.go.id/finger-rest/' 0
            [RssgSidikJariNative]::ClickRelative($settingWindow, 353, 379)
            Start-Sleep -Milliseconds 500
        }
    }

    $mainWindow = Find-MainWindow
    if ($mainWindow -eq [IntPtr]::Zero) {
        $loginWindow = Wait-ForWindow { Find-LoginWindow } 15
        if ($loginWindow -eq [IntPtr]::Zero) {
            throw 'Window login SidikJari tidak muncul dalam 15 detik.'
        }

        Write-Output '[AUTO] Login ke aplikasi SidikJari...'
        [RssgSidikJariNative]::ActivateAndNormalize($loginWindow)
        Set-FieldText $username 0
        [RssgSidikJariNative]::Press(0x09)
        Set-FieldText $password 0
        [RssgSidikJariNative]::Press(0x0D)

        $mainWindow = Wait-ForWindow { Find-MainWindow } 30
        if ($mainWindow -eq [IntPtr]::Zero) {
            throw 'Login gagal atau window utama tidak muncul dalam 30 detik.'
        }
        Start-Sleep -Milliseconds 1000
    } else {
        Write-Output '[AUTO] Sesi login aktif; menggunakan window yang sudah terbuka.'
    }

    [RssgSidikJariNative]::ActivateAndNormalize($mainWindow)
    if ($identifierType -eq 'NIK') {
        [RssgSidikJariNative]::ClickRelative($mainWindow, 250, 135)
        [RssgSidikJariNative]::ClickRelative($mainWindow, 450, 135)
    } else {
        [RssgSidikJariNative]::ClickRelative($mainWindow, 450, 135)
        [RssgSidikJariNative]::ClickRelative($mainWindow, 250, 135)
    }
    [RssgSidikJariNative]::ClickRelative($mainWindow, 360, 200)
    Set-FieldText $identifier 50

    Write-Output '[AUTO] RSSG_AUTOMATION_SUCCESS'
    exit 0
} catch {
    Write-Error ("[AUTO] " + $_.Exception.Message)
    exit 1
}
''';

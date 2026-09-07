const windowsFristaAutomationScript = r'''
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class RssgFristaNative {
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
    private static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

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

    static RssgFristaNative() {
        try { SetProcessDPIAware(); } catch { }
    }

    public static IntPtr FindWindowByProcessName(string processName) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) return true;
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == 0) return true;
            try {
                var proc = System.Diagnostics.Process.GetProcessById((int)pid);
                if (proc.ProcessName.IndexOf(processName, StringComparison.OrdinalIgnoreCase) >= 0) {
                    found = hWnd;
                    return false;
                }
            } catch { }
            return true;
        }, IntPtr.Zero);
        return found;
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

    public static void ActivateAndNormalize(IntPtr hWnd, int x, int y, int width, int height) {
        if (hWnd == IntPtr.Zero) throw new InvalidOperationException("Window handle is empty");
        ShowWindowAsync(hWnd, 9);
        SetWindowPos(hWnd, new IntPtr(-1), x, y, width, height, 0x0040);
        SetWindowPos(hWnd, new IntPtr(-2), x, y, width, height, 0x0040);
        BringWindowToTop(hWnd);
        SetForegroundWindow(hWnd);
        SwitchToThisWindow(hWnd, true);
        Thread.Sleep(200);
    }

    public static void ClickInputArea(IntPtr hWnd) {
        RECT rectangle;
        if (!GetWindowRect(hWnd, out rectangle)) {
            throw new InvalidOperationException("Cannot read target window position");
        }
        int width = rectangle.right - rectangle.left;
        int height = rectangle.bottom - rectangle.top;
        int x = rectangle.left + (int)(width * 0.75);
        int y = rectangle.top + (int)(height * 0.28);
        SetCursorPos(x, y);
        Thread.Sleep(50);
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(80);
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

$identifier = $env:RSSG_FRISTA_IDENTIFIER
$titlePattern = $env:RSSG_FRISTA_WINDOW_TITLE

$posX = 685
$posY = 0
$width = 680
$height = 520

if ($env:RSSG_FRISTA_POS_X) {
    [int]::TryParse($env:RSSG_FRISTA_POS_X, [ref]$posX)
}
if ($env:RSSG_FRISTA_POS_Y) {
    [int]::TryParse($env:RSSG_FRISTA_POS_Y, [ref]$posY)
}
if ($env:RSSG_FRISTA_WIDTH) {
    [int]::TryParse($env:RSSG_FRISTA_WIDTH, [ref]$width)
}
if ($env:RSSG_FRISTA_HEIGHT) {
    [int]::TryParse($env:RSSG_FRISTA_HEIGHT, [ref]$height)
}

if ([string]::IsNullOrWhiteSpace($titlePattern)) {
    $titlePattern = 'Frista (Face Recognition BPJS Kesehatan)'
}

if ([string]::IsNullOrWhiteSpace($identifier)) {
    throw 'NIK atau nomor BPJS kosong.'
}

function Find-MainWindow {
    $proc = Get-Process -Name '*frista*' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($null -ne $proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
        return $proc.MainWindowHandle
    }
    $window = [RssgFristaNative]::FindWindowByProcessName('frista')
    if ($window -ne [IntPtr]::Zero) {
        return $window
    }
    $window = [RssgFristaNative]::FindWindowContaining('Frista (Face Recognition BPJS Kesehatan)', '')
    if ($window -ne [IntPtr]::Zero) {
        return $window
    }
    $window = [RssgFristaNative]::FindWindowContaining($titlePattern, 'Chrome,Edge,Firefox,Telegram,WhatsApp,Agent')
    if ($window -ne [IntPtr]::Zero) {
        return $window
    }
    $window = [RssgFristaNative]::FindWindowContaining('Face Recognition', 'Chrome,Edge,Firefox,Telegram,WhatsApp,Agent')
    if ($window -ne [IntPtr]::Zero) {
        return $window
    }
    return [IntPtr]::Zero
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
    [RssgFristaNative]::SelectAll()
    Start-Sleep -Milliseconds 50
    [RssgFristaNative]::Press(0x08)
    Start-Sleep -Milliseconds 50
    [RssgFristaNative]::TypeUnicode($value, $delayMilliseconds)
}

try {
    Write-Output '[AUTO] Mencari window aplikasi FRISTA...'
    $mainWindow = Wait-ForWindow { Find-MainWindow } 15

    if ($mainWindow -eq [IntPtr]::Zero) {
        throw 'Window aplikasi FRISTA tidak ditemukan dalam 15 detik.'
    }

    Write-Output '[AUTO] Mengaktifkan window FRISTA ke foreground...'
    [RssgFristaNative]::ActivateAndNormalize($mainWindow, $posX, $posY, $width, $height)
    Start-Sleep -Milliseconds 300

    Write-Output '[AUTO] Memilih field input NIK/BPJS FRISTA...'
    [RssgFristaNative]::ClickInputArea($mainWindow)
    Start-Sleep -Milliseconds 150

    Set-FieldText $identifier 20

    Write-Output '[AUTO] RSSG_AUTOMATION_SUCCESS'
    exit 0
} catch {
    Write-Error ("[AUTO] " + $_.Exception.Message)
    exit 1
}
''';

# Backend window started by dev.ps1.
#
# Disables the "QuickEdit" mode of this console window : with it, a click in the window
# starts a text selection (title "Sélection ...") and Windows PAUSES the backend as soon as it
# writes a log line, so every request of the app hangs until Escape is pressed.

Add-Type -Namespace GardenFlow -Name ConsoleMode -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int handle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr handle, out uint mode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr handle, uint mode);
'@

$STD_INPUT_HANDLE      = -10
$ENABLE_QUICK_EDIT     = 0x40
$ENABLE_EXTENDED_FLAGS = 0x80 # required for the QuickEdit flag to be taken into account

$stdin = [GardenFlow.ConsoleMode]::GetStdHandle($STD_INPUT_HANDLE)
$mode = [uint32]0
if ([GardenFlow.ConsoleMode]::GetConsoleMode($stdin, [ref]$mode)) {
    [void][GardenFlow.ConsoleMode]::SetConsoleMode($stdin, ($mode -band (-bnot $ENABLE_QUICK_EDIT)) -bor $ENABLE_EXTENDED_FLAGS)
}

Set-Location "$PSScriptRoot\backend"
npm run dev

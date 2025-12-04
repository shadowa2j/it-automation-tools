# Move Off-Screen Windows Back to Visible Area
# This script finds windows that are positioned outside the visible desktop area
# and moves them back to a visible location

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsDelegate lpEnumFunc, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();
    
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    public delegate bool EnumWindowsDelegate(IntPtr hWnd, IntPtr lParam);
    
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_SHOWWINDOW = 0x0040;
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}
"@

# Add required assembly for screen information
try {
    Add-Type -AssemblyName System.Windows.Forms
} catch {
    Write-Error "Failed to load System.Windows.Forms assembly: $_"
    exit 1
}

# Get screen dimensions
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$screenLeft = $screen.Left
$screenTop = $screen.Top
$screenRight = $screen.Right
$screenBottom = $screen.Bottom

Write-Host "Screen bounds: Left=$screenLeft, Top=$screenTop, Right=$screenRight, Bottom=$screenBottom"
Write-Host "Searching for off-screen windows..."
Write-Host ""

$script:movedWindows = 0
$buffer = 50

# Callback function to process each window
$callback = {
    param($hWnd, $lParam)
    
    try {
        # Skip invisible and minimized windows
        if (-not [Win32]::IsWindowVisible($hWnd) -or [Win32]::IsIconic($hWnd)) {
            return $true
        }
        
        # Get window title
        $title = New-Object System.Text.StringBuilder(256)
        $length = [Win32]::GetWindowText($hWnd, $title, $title.Capacity)
        $windowTitle = $title.ToString()
        
        # Skip windows without titles (usually system windows)
        if ([string]::IsNullOrWhiteSpace($windowTitle)) {
            return $true
        }
        
        # Get window position
        $rect = New-Object RECT
        if ([Win32]::GetWindowRect($hWnd, [ref]$rect)) {
            $windowLeft = $rect.Left
            $windowTop = $rect.Top
            $windowRight = $rect.Right
            $windowBottom = $rect.Bottom
            $windowWidth = $windowRight - $windowLeft
            $windowHeight = $windowBottom - $windowTop
            
            # Validate window dimensions
            if ($windowWidth -le 0 -or $windowHeight -le 0) {
                return $true
            }
            
            # Check if window is off-screen
            $isOffScreen = $false
            $newX = $windowLeft
            $newY = $windowTop
            
            # Check if window is completely to the left of all screens
            if ($windowRight -lt $screenLeft) {
                $newX = $screenLeft + $buffer
                $isOffScreen = $true
            }
            # Check if window is completely to the right of all screens
            elseif ($windowLeft -gt $screenRight) {
                $newX = $screenRight - $windowWidth - $buffer
                $isOffScreen = $true
            }
            
            # Check if window is completely above all screens
            if ($windowBottom -lt $screenTop) {
                $newY = $screenTop + $buffer
                $isOffScreen = $true
            }
            # Check if window is completely below all screens
            elseif ($windowTop -gt $screenBottom) {
                $newY = $screenBottom - $windowHeight - $buffer
                $isOffScreen = $true
            }
            
            # Also check if window is mostly off-screen (less than buffer pixels visible)
            $visibleWidth = [Math]::Max(0, [Math]::Min($windowRight, $screenRight) - [Math]::Max($windowLeft, $screenLeft))
            $visibleHeight = [Math]::Max(0, [Math]::Min($windowBottom, $screenBottom) - [Math]::Max($windowTop, $screenTop))
            
            if ($visibleWidth -lt $buffer -or $visibleHeight -lt $buffer) {
                if ($windowLeft -lt $screenLeft) { $newX = $screenLeft + $buffer }
                if ($windowRight -gt $screenRight) { $newX = $screenRight - $windowWidth - $buffer }
                if ($windowTop -lt $screenTop) { $newY = $screenTop + $buffer }
                if ($windowBottom -gt $screenBottom) { $newY = $screenBottom - $windowHeight - $buffer }
                $isOffScreen = $true
            }
            
            # Move the window if it's off-screen
            if ($isOffScreen) {
                # Ensure the new position keeps the window on screen
                # Handle cases where window is larger than screen
                $screenWidth = $screenRight - $screenLeft
                $screenHeight = $screenBottom - $screenTop
                
                if ($windowWidth -gt $screenWidth) {
                    # Window wider than screen - center it
                    $newX = $screenLeft
                } else {
                    # Clamp X position to keep window on screen
                    $newX = [Math]::Max($screenLeft + $buffer, [Math]::Min($newX, $screenRight - $windowWidth - $buffer))
                }
                
                if ($windowHeight -gt $screenHeight) {
                    # Window taller than screen - align to top
                    $newY = $screenTop
                } else {
                    # Clamp Y position to keep window on screen
                    $newY = [Math]::Max($screenTop + $buffer, [Math]::Min($newY, $screenBottom - $windowHeight - $buffer))
                }
                
                Write-Host "Moving window: $windowTitle"
                Write-Host "  From: ($windowLeft, $windowTop) to ($newX, $newY)"
                
                $result = [Win32]::SetWindowPos($hWnd, [IntPtr]::Zero, $newX, $newY, 0, 0, 
                    [Win32]::SWP_NOSIZE -bor [Win32]::SWP_NOZORDER -bor [Win32]::SWP_SHOWWINDOW)
                
                if ($result) {
                    Write-Host "  Successfully moved!" -ForegroundColor Green
                    $script:movedWindows++
                } else {
                    Write-Host "  Failed to move window" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
    } catch {
        Write-Warning "Error processing window: $_"
    }
    
    return $true
}

# Enumerate all windows
[Win32]::EnumWindows($callback, [IntPtr]::Zero)

Write-Host "Operation completed. Moved $($script:movedWindows) window(s) back to visible area." -ForegroundColor Cyan

if ($script:movedWindows -eq 0) {
    Write-Host "No off-screen windows were found." -ForegroundColor Green
}

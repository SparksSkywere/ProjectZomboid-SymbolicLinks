#This PS script is for "Project Zomboid" and symbolic linking folders for server modding
#Hide console
function Show-Console
{
    param ([Switch]$Show,[Switch]$Hide)
    if (-not ("Console.Window" -as [type])) { 

        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    if ($Show)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        $null = [Console.Window]::ShowWindow($consolePtr, 5)
    }
    if ($Hide)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        #0 hide
        $null = [Console.Window]::ShowWindow($consolePtr, 0)
    }
}
#End of powershell console hiding
#To show the console change "-hide" to "-show"
show-console -show

# Enable Long Paths (requires reboot to take effect)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

#Get the UserDirectory
$userDir = "$env:UserProfile"
#Debug
Write-Host "Current user directory: $userDir"

#Check Steams install path via Regedit
$steamKey = Get-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
$installDir = $steamKey.GetValue("InstallPath")

#Locate "libraryfolders.vdf" file
$libraryFoldersPath = Join-Path -Path $installDir -ChildPath "steamapps\libraryfolders.vdf"
if (-not (Test-Path $libraryFoldersPath)) 
{
    #If file does not exist, Exit
    Write-Host "Could not find libraryfolders.vdf in $installDir" -ForegroundColor Red
    Exit
}

#Get the library folders from the ".vdf" file - filter only valid paths
$libraryFolders = Get-Content $libraryFoldersPath | Where-Object { $_ -match '"path"\s*"(.+?)"' } | ForEach-Object { ($_ -split '"path"\s*"')[1].Trim('"') }

#Verify each library path
$validLibraryFolders = @()
foreach ($folder in $libraryFolders) 
{
    if (Test-Path $folder) 
    {
        $validLibraryFolders += $folder
    } 
    else 
    {
        Write-Host "Invalid library path detected: $folder" -ForegroundColor Yellow
    }
}

#Check for Steam Client installation
$steamClientPaths = @()
foreach ($folder in $validLibraryFolders) 
{
    $possiblePath = Join-Path $folder "steamapps"
    if (Test-Path $possiblePath) 
    {
        $steamClientPaths += $possiblePath
    }
}

if (-not $steamClientPaths) 
{
    Write-Host "No valid Steam Client installations found." -ForegroundColor Red
} 
else 
{
    Write-Host "Found Steam Client installations in the following directories:`n$($steamClientPaths -join "`n")"
}

# Check for SteamCMD in valid library folders and fallback paths
$steamCMDPaths = @()

# Check library folders
foreach ($folder in $validLibraryFolders) 
{
    $possiblePath = Join-Path $folder "SteamCMD"
    if ((Test-Path $possiblePath) -and (Test-Path (Join-Path $possiblePath "steamcmd.exe"))) 
    {
        $steamCMDPaths += $possiblePath
    }
}

# Check fallback locations
$fallbackPaths = @("C:\SteamCMD", "D:\SteamCMD")
foreach ($path in $fallbackPaths) 
{
    if ((Test-Path $path) -and (Test-Path (Join-Path $path "steamcmd.exe"))) 
    {
        $steamCMDPaths += $path
    }
}

if (-not $steamCMDPaths) 
{
    Write-Host "No valid SteamCMD installation found." -ForegroundColor Red
} 
else 
{
    Write-Host "Found SteamCMD in the following directories:`n$($steamCMDPaths -join "`n")"
    foreach ($path in $steamCMDPaths) 
    {
        # Attach SteamCMD folder for workshops checking
        $validLibraryFolders += Join-Path -Path $path -ChildPath "steamapps"
    }
}

# Set Zomboid mods path
$zomboidPath = "$userDir\zomboid\mods"
if (-not (Test-Path -Path $zomboidPath))
{
    Write-Host "zomboid\mods Folder not found"
    Write-Host "Current user path: '$zomboidPath'"
    Exit
}
# Check each library folder in Steam for "108600"
$zomboidFolder = $null
foreach ($library in $validLibraryFolders)
{
    $folder = Join-Path $library 'workshop\content\108600'
    Write-Host "Checking workshop folder: $folder"
    if (Test-Path $folder) 
    {
        Write-Host "zomboid Workshop Found in '$folder'"
        $zomboidFolder = $folder
        break
    }
}

if (-not $zomboidFolder)
{
    #If 108600 is not found, Exit
    Write-Host "Could not find zomboid workshop folder in any Steam library" -ForegroundColor Red
    Exit
}

# Symbolic link each mod folder
$skippedLinks = 0
$newLinks = 0
foreach ($folder in $validLibraryFolders)
{
    $modPath = Join-Path $folder "workshop\content\108600"
    if (Test-Path $modPath)
    {
        # Get all directories under workshop content
        Get-ChildItem -Path $modPath -Recurse -Directory | Where-Object { $_.Name -match "(?i)^mods$" } | ForEach-Object {
            $modDir = $_.FullName
            # Inside your loop where you handle each mod folder
            if (Test-Path -LiteralPath $modDir) 
            {
                Get-ChildItem -Path $modDir -Directory | ForEach-Object {
                    $target = Join-Path $zomboidPath ([System.IO.Path]::GetFileName($_.FullName))
                    $source = $_.FullName
                    
                    # Escape special characters for PowerShell commands
                    $escapedSourceForCommand = $source -replace '\[', '`[' -replace '\]', '`]'
                    $escapedTargetForCommand = $target -replace '\[', '`[' -replace '\]', '`]'
                    
                    # Use the original path for checking existence
                    if (-not (Test-Path -LiteralPath $source)) {
                        Write-Host "Source path not found: $escapedSourceForCommand (Original: $source)" -ForegroundColor Red
                        return
                    }
                    if (Test-Path $target){
                        $skippedLinks++
                        return
                    }
                    try {
                        New-Item -ItemType SymbolicLink -Path $escapedTargetForCommand -Target $escapedSourceForCommand -Force -ErrorAction Stop
                        $newLinks++
                    } catch {
                        Write-Host "Failed to create symbolic link for $escapedSourceForCommand to $escapedTargetForCommand. Error: $_" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

Write-Host "Symbolic Link Creation Summary:"
Write-Host " - New Links Created: $newLinks"
Write-Host " - Skipped Existing Links: $skippedLinks"
Pause
#Made by Chris Masters
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

#Get the UserDirectory
$userDir = "$env:UserProfile"

#Check Steams install path via Regedit
$steamKey = Get-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
$installDir = $steamKey.GetValue("InstallPath")

#Locate "libraryfolders.vdf" file
$libraryFoldersPath = Join-Path -Path $installDir -ChildPath "steamapps\libraryfolders.vdf"
if (-not (Test-Path $libraryFoldersPath)) {
    #If file does not exit, Exit
    Write-Host "Could not find libraryfolders.vdf in $steamDir" -ForegroundColor Red
    Exit
}

#Get the library folders from the ".vdf" file
$libraryFolders = Get-Content $libraryFoldersPath | Where-Object { $_ -match '^\s*"\d+"\s*"' } | ForEach-Object { ($_ -split '\t')[3].Trim('"') }
#Attach all steamapps for workshops checking
$libraryFolders += Join-Path -Path $installDir -ChildPath "steamapps"

#Set ZB path with current logged in user
$zomboidPath = "$userDir\.Zomboid\mods"
#Now check to see if that path exists
$checkZBPath = Test-Path -Path $zomboidPath
if (-not $checkZBPath)
{
    #No ZB path detected... Exit
    Write-Host ".Zomboid\mods Folder not found"
    #Debug user
    #Write-Host "Current user path: '$zomboidPath'"
    Exit
}

#Check each library folder in steam for "108600"
foreach ($library in $libraryFolders) {
    $zomboidFolder = Join-Path $library 'workshop\content\108600'
    if (Test-Path $zomboidFolder) {
        #If 108600 is found in the workshop folder, move onto the next step
        Write-Host "Zomboid Workshop Found in '$zomboidFolder'"
        break
    }
}
if (-not $zomboidFolder) {
    #If 108600 is not found, Exit
    Write-Host "Could not find Zomboid workshop folder in any Steam library" -ForegroundColor Red
    Exit
}

#Symbolic link each mod folder to the Zomboid mods folder
foreach ($folder in $libraryFolders) {
    #Set folder to workshop and the game ID "108600"
    $modPath = Join-Path $folder "workshop\content\108600"
    if (Test-Path $modPath) {
        #For each mod folder inside 108600 (It ignores the ModID's)
        Get-ChildItem -Path $modPath -Directory | ForEach-Object {
            $modDir = Join-Path $_.FullName "Mods"
            #If Directory passes checks -> proceed
            if (Test-Path $modDir) {
                Get-ChildItem -Path $modDir -Directory | ForEach-Object {
                    #For each folder -> symbolic link to "$userDir\.Zomboid\mods"
                    $target = Join-Path $zomboidPath $_.Name
                    if (-not (Test-Path $target)) {
                        New-Item -ItemType SymbolicLink -Path $target -Target $modDir
                    }
                    #For duplicates -> Ignore 
                    else {
                        Write-Output "Symbolic link already exists for $($_.Name). Skipping."
                    }
                }
            }
        }
    }
}
#End
Exit
#Made by Chris Masters
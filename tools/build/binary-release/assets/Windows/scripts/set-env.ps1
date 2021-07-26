$script_path = split-path -parent $MyInvocation.MyCommand.Definition

function activate_buildtools() {
    Write-Host "                  Detecting and activating MS Build tools"
    Write-Host "                 ========================================="
    Write-Host ""

    $cims = Get-CimInstance MSFT_VSInstance
    $chosen_cim = $null
    foreach ($cim in $cims) {
        $install_location = $cim.InstallLocation
        if (-Not(Get-ChildItem -Path $install_location -Filter CL.exe -Recurse -ErrorAction SilentlyContinue)) {
            Write-Host "No CL found in $install_location. Skipping."
            continue
        }
        if ($chosen_cim -eq $null) {
            $chosen_cim = $cim
        }
        else {
            if ($cim.Version > $chosen_cim.Version) {
                $chosen_cim = $cim
            }
        }
    }
    if ($chosen_cim -eq $null) {
        Write-Host "No suitable installation found."
        return
    }

    $install_location = $chosen_cim.InstallLocation

    $ps_module = Get-ChildItem -Path $install_location -Filter Microsoft.VisualStudio.DevShell.dll -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-Not $ps_module) {
        Write-Host "The PowerShell setup module wasn't found."
        return
    }
    $ps_module = $ps_module.FullName

    Write-Host "Found suitable installation in $install_location."
    Import-Module $ps_module

    if ((Get-CimInstance win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit") {
        Enter-VsDevShell -VsInstallPath $install_location -SkipAutomaticLocation -DevCmdArguments "-arch=amd64"
    }
    else {
        Enter-VsDevShell -VsInstallPath $install_location -SkipAutomaticLocation -DevCmdArguments
    }
    Write-Host ""
}

function add_to_path() {
    Write-Host "                             Adding Rakudo to PATH"
    Write-Host "                            ======================="
    Write-Host ""

    $done_stuff = $null

    $rakudo_path0 = (Resolve-Path "$script_path\..\bin").Path
    $rakudo_path1 = (Resolve-Path "$script_path\..\share\perl6\site\bin").Path

    if ($env:PATH -NotLike "*$rakudo_path1*") {
        $Env:PATH = "$rakudo_path1;$Env:PATH"
        $done_stuff = $true
    }

    if ($env:PATH -NotLike "*$rakudo_path0*") {
        $Env:PATH = "$rakudo_path0;$Env:PATH"
        $done_stuff = $true
    }

    if ($done_stuff -ne $null) {
        Write-Host "Paths successfully added."
    }
    else {
        Write-Host "Paths already set. Nothing to do."
    }
}


activate_buildtools
add_to_path

Write-Host -ForegroundColor cyan @'

================================================================================
'@
Write-Host -NoNewline @'
 =========                                                             __   __
  ||_|_||                '@
Write-Host -NoNewline -ForegroundColor cyan '============================='
Write-Host -NoNewline @'                (  \,/  )
  || # ||                 '@
Write-Host -NoNewline -ForegroundColor cyan 'Welcome to the Raku Console'
Write-Host -NoNewline @'                  \_ O _/
  || # ||                '@
Write-Host -NoNewline -ForegroundColor cyan '============================='
Write-Host @'                 (_/ \_)

This console has all the tools available you need to get started using Raku.

Rakudo provides an interactive command line interpreter (a so called Read Eval
Print Loop, REPL for short) you can use to quickly try out pieces of Raku code.
Start it by typing:
'@
Write-Host -ForegroundColor green '    raku.exe'
Write-Host @'
If you already have a Raku program in a file, you can run it by typing:
'@
Write-Host -ForegroundColor green '    raku.exe path\to\my\program.raku'
Write-Host @'
To install additional modules you can use the Zef module manager:
'@
Write-Host -ForegroundColor green '    zef install Some::Module'
Write-Host ''
Write-Host -NoNewline -ForegroundColor magenta 'https://rakudo.org/'
Write-Host '           - The home of this implementation of Raku.'
Write-Host -NoNewline -ForegroundColor magenta 'https://raku.land/'
Write-Host '            - Go here to browse for Raku modules.'
Write-Host -NoNewline -ForegroundColor magenta 'https://docs.raku.org/'
Write-Host '        - The Raku documentation.'
Write-Host -NoNewline -ForegroundColor magenta 'https://web.libera.chat/#raku'
Write-Host @' - The Raku user chat. Talk to us!

                              Happy hacking!
'@
Write-Host -ForegroundColor cyan '================================================================================'
Write-Host ''

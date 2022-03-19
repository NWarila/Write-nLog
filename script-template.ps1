<#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER Confirm
        [Int] Determine what type of changes should be prompted before executing.
            0 - Confirm both environment and object changes.
            1 - Confirm only object changes. (Default)
            2 - Confirm nothing!
            Object Changes are changes that are permanent such as file modifications, registry changes, etc.
            Environment changes are changes that can normally be restored via restart, such as opening/closing applications.
            Note: This configuration will take priority over Debugger settings for confirm action preference.
    .PARAMETER Debugger
        [Int] Used primarily to quickly apply multiple arguments making script development and debugging easier. Useful only for developers.
            1. Incredibly detailed play-by-play execution of the script. Equivilent to '-Change 0',  '-LogLevel Verbose', script wide 'ErrorAction Stop', 'Set-StrictMode -latest', and lastly 'Set-PSDebug -Trace 1'
            2. Equivilent to '-Change 0', '-LogLevel Verbose', and script wide 'ErrorAction Stop'.
            3. Equivilent to '-Change 1', '-LogLevel Info', and enables verbose on PS commands.
    .PARAMETER LogLevel
        [String] Used to display log output with definitive degrees of verboseness.
            Verbose = Display everything the script is doing with extra verbose messages, helpful for debugging, useless for everything else.
            Debug   = Display all messages at a debug or higher level, useful for debugging.
            Info    = Display all informational messages and higher. (Default)
            Warn    = Display only warning and error messages.
            Error   = Display only error messages.
            None    = Display absolutely nothing.
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
    VERSION     DATE			NAME						DESCRIPTION
    ___________________________________________________________________________________________________________
    1.0         28 Sept 2020	Warilia, Nicholas R.		Initial version
    Script tested on the following Powershell Versions
        1.0   2.0   3.0   4.0   5.0   5.1
    ----- ----- ----- ----- ----- -----
        X    X      X     X     ✓    ✓
    Credits:
        (1) Script Template: https://gist.github.com/9to5IT/9620683
    To Do List:
        (1) Get Powershell Path based on version (stock powershell, core, etc.)
    Additional Information:
        #About '#Requires': https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
        Show-Command Creates GUI window with all parameter; super easy to see what options are available for a command.
        Get-Verb Shows all approved powershell versb
#>

[CmdletBinding(
    ConfirmImpact="None",
    DefaultParameterSetName="Site",
    HelpURI="",
    SupportsPaging=$False,
    SupportsShouldProcess=$True,
    PositionalBinding=$True
)] Param (
    [string]$test,
    [ValidateSet(0,1,2)]
    [Int]$Confim = 1,
    [ValidateSet(0,1,2)]
    [Int]$Debugger = 3,
    [ValidateSet("Verbose","Debug","Info","Warn","Error","Fatal","Off")]
    [String]$LogLevel = "Info",
    [ValidateSet("Log","Host","LogHost","Auto")]
    [String]$LogOutput='Auto',
    [Switch]$Testing
)

#region --------------------------------------------- [Manual Configuration] ----------------------------------------------------
    #Require Admin Privilages.
    New-Variable -Force -Name ScriptConfig -value @{
        #Should script enforce running as admin.
        RequireAdmin = $False
    }

#endregion,#')}]#")}]#'")}]

#region ----------------------------------------------- [Required Functions] -----------------------------------------------------

#endregion,#')}]#")}]#'")}]

#region----------------------------------------- [Initializations & Prerequisites] -----------------------------------------------

    #Non Write-Host dependent trap to conduct debugging before write-host is enabled.
    New-Variable -Name nLogInitialize -Value:$False -Force
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
        Trap {
            if ($nLogInitialize) {
                Write-nLog -Type Debug -Message "Failed to execute command: $([string]::join(`"`",$_.InvocationInfo.line.split(`"`n`")))"
                Write-nLog -Type Error -Message "$($_.Exception.Message) [$($_.Exception.GetType().FullName)]" -Line $_.InvocationInfo.ScriptLineNumber
            } Else {
                Write-Host -Object "Failed to execute command: $([string]::join(`"`",$_.InvocationInfo.line.split(`"`n`")))"
                Write-Host -Object "$($_.Exception.Message) [$($_.Exception.GetType().FullName)]"
            }
            Continue
        }

    #region [configure environment variables] ---------------------------------------------------------

        #Determine the Log Output Level
        Switch ($LogLevel) {
            "Debug"   {$DebugPreference = 'Continue'        ; $VerbosePreference = 'Continue'        ; $InformationPreference = 'Continue'        ; $WarningPreference = 'Continue'        ; $ErrorPreference = 'Continue'        }
            "Verbose" {$DebugPreference = 'SilentlyContinue'; $VerbosePreference = 'Continue'        ; $InformationPreference = 'Continue'        ; $WarningPreference = 'Continue'        ; $ErrorPreference = 'Continue'        }
            "Info"    {$DebugPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $InformationPreference = 'Continue'        ; $WarningPreference = 'Continue'        ; $ErrorPreference = 'Continue'        }
            "Warn"    {$DebugPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'; $WarningPreference = 'Continue'        ; $ErrorPreference = 'Continue'        }
            "Error"   {$DebugPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'; $WarningPreference = 'SilentlyContinue'; $ErrorPreference = 'Continue'        }
            "Off"     {$DebugPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'; $WarningPreference = 'SilentlyContinue'; $ErrorPreference = 'SilentlyContinue'}
        }

        #Converts Verbose Prefernce to bool so it can be used in "-Verbose:" arguments.
        [Bool]$Verbose = ($VerbosePreference -eq 'Continue')

        #Create CommandSplat variable.
        New-Variable -Force -Verbose:$Verbose -Name CommandSplat -Value (New-Object -TypeName HashTable -ArgumentList 0,([StringComparer]::OrdinalIgnoreCase))
        $CommandSplat.Add('Verbose',$Verbose)

        #Set Set Debug Level
        Switch ($Debugger) {
            0       { $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Inquire  ; Set-StrictMode -Version Latest ; Set-PsDebug -Trace 2}
            1       { $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Inquire  ; Set-StrictMode -Version Latest ; Set-PsDebug -Trace 1}
            2       { $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Inquire  ; Set-StrictMode -Version Latest }
            Default { $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop     }
        }
    #endregion [configure environment variables],#')}]#")}]#'")}]

    #region [Determine ScriptEnv properties] ---------------------------------------------------------
        #Variable used to store certain sometimes useful script related information.
        New-Variable -Name ScriptEnv -Force -scope Script -value @{
            RunMethod      = [String]::Empty
            Interactive    = [Bool]$([Environment]::GetCommandLineArgs().Contains('-NonInteractive') -or ([Environment]::UserInteractive -EQ $False))
            IsAdmin        = [Bool]$((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
            Parameters     = New-Object -TypeName "System.Text.StringBuilder"
            Script         = [System.IO.FileInfo]$Null
            Powershellpath = New-object -TypeName 'System.io.fileinfo' -ArgumentList (get-command powershell).source
            Variables      = New-Object -TypeName 'System.Collections.ArrayList'
        }

        #Create a proper parameter string.
        ForEach ($Parameter in $Script:PSBoundParameters.GetEnumerator()) {
            [void]$ScriptEnv.Parameters.Append(" -$($Parameter.key): ""$($Parameter.Value)""")
        }

        #Determine The Environment The Script is Running in.
        IF (Test-Path -Path Variable:PSise) {
            #Running as PSISE
            [String]$ScriptEnv.RunMethod = 'ISE'
            [System.IO.FileInfo]$ScriptEnv.Script = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $psISE.CurrentFile.FullPath
        } ElseIF (Test-Path -Path Variable:pseditor) {
            #Running as VSCode
            [String]$ScriptEnv.RunMethod = 'VSCode'
            [System.IO.FileInfo]$ScriptEnv.Script = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $pseditor.GetEditorContext().CurrentFile.Path
        } Else {
            #Running as AzureDevOps or Powershell
            [String]$ScriptEnv.RunMethod = 'ADPS'
            IF ($Host.Version.Major -GE 3) {
                [System.IO.FileInfo]$ScriptEnv.Script = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $PSCommandPath
            } Else {
                [System.IO.FileInfo]$ScriptEnv.Script = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $MyInvocation.MyCommand.Definition
            }
        }
    #endregion [Determine ScriptEnv properties],#')}]#")}]#'")}]

    #region [If Administrator check] ---------------------------------------------------------
    IF ($ScriptConfig.RequreAdmin -eq $True) {
        IF ($ScriptEnv.IsAdmin -eq $False) {
            Write-Warning -Message 'Warning: Script not running as administrator, relaunching as administrator.'
            IF ($ScriptEnv.RunMethod -eq 'ISE') {
                IF ($psISE.CurrentFile.IsUntitled-eq $True) {
                    Write-Error -Message 'Unable to elevate script, please save script before attempting to run.'
                    break
                } Else {
                    IF ($psISE.CurrentFile.IsSaved -eq $False) {
                        Write-Warning 'ISE Script unsaved, unexpected results may occur.'
                    }
                }
            }
            $Process = [System.Diagnostics.Process]::new()
            $Process.StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $Process.StartInfo.Arguments = "-NoLogo -ExecutionPolicy Bypass -noprofile -command &{start-process '$($ScriptEnv.Powershellpath)' {$runthis} -verb runas}"
            $Process.StartInfo.FileName = $ScriptEnv.Powershellpath
            $Process.startinfo.WorkingDirectory = $ScriptEnv.ScriptDir
            $Process.StartInfo.UseShellExecute = $False
            $Process.StartInfo.CreateNoWindow  = $True
            $Process.StartInfo.RedirectStandardOutput = $True
            $Process.StartInfo.RedirectStandardError = $False
            $Process.StartInfo.RedirectStandardInput = $False
            $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            $Process.StartInfo.LoadUserProfile = $False
            [Void]$Process.Start()
            [Void]$Process.WaitForExit()
            [Void]$Process.Close()
            exit
        }
    }
    #endregion,#')}]#")}]#'")}]

    #region [Universal Error Trapping with easier to understand output] ---------------------------------------------------------
    Trap {
        Write-nLog -Type Debug -Message "Failed to execute command: $([string]::join(`"`",$_.InvocationInfo.line.split(`"`n`")))"
        Write-nLog -Type Error -Message "$($_.Exception.Message) [$($_.Exception.GetType().FullName)]" -Line $_.InvocationInfo.ScriptLineNumber
        Continue
    }
    #endregion [Universal Error Trapping with easier to understand output],#')}]#")}]#'")}]

    #Startup Write-nLog function.
    Write-nLog -Initialize -Type Debug -Message "Starting nLog function."-SetLogLevel $LogLevel -SetWriteHost $True -SetWriteLog $True -SetTimeLocalization Local -SetLogFormat CMTrace

    #region [Script Prerequisits] ---------------------------------------------------------

    #endregion [Script Prerequisits],#')}]#")}]#'")}]

    #Remove-Variable -Name @('ScriptConfig','ScriptEnv','Process') -Force -ErrorAction SilentlyContinue
#endregion [Initializations & Prerequisites],#')}]#")}]#'")}]

#region ------------------------------------------------- [Main Script] ---------------------------------------------------------

    #region [Process Header] ---------------------------------------------------------
    write-Host "123"
    #endregion [Process Header],#')}]#")}]#'")}]

#endregion [Main Script],#')}]#")}]#'")}]

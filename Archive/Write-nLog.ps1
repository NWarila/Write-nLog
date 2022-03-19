Function Write-nLog {
        <#
            .SYNOPSIS
                Standardized & Easy to use logging function.
            .DESCRIPTION
                Easy and highly functional logging function that can be dropped into any script to add logging capability without hindering script performance.
            .PARAMETER type
                Set the event level of the log event.
                [Options]
                    Info, Warning, Error, Debug
            .PARAMETER message
                Set the message text for the event.
            .PARAMETER ErrorCode
                Set the Error code for Error & fatal level events. The error code will be displayed in front of the message text for the event.
            .PARAMETER WriteHost
                Force writing to host reguardless of SetWriteLog setting for this specific instance.
            .PARAMETER WriteLog
                Force writing to log reguardless of SetWriteLog setting for this specific instance.
            .PARAMETER SetLogLevel
                Set the log level for the nLog function for all future calls. When setting a log level all logs at
                the defined level will be logged. If you set the log level to warning (default) warning messages
                and all events above that such as error and fatal will also be logged.
                (1) Debug: Used to document events & actions within the script at a very detailed level. This level
                is normally used during script debugging or development and is rarely set once a script is put into
                production
                (2) Information: Used to document normal application behavior and milestones that may be useful to
                keep track of such. (Ex. File(s) have been created/removed, script completed successfully, etc)
                (3) Warning: Used to document events that should be reviewed or might indicate there is possibly
                unwanted behavior occuring.
                (4) Error: Used to document non-fatal errors indicating something within the script has failed.
                (5) Fatal: Used to document errors significant enough that the script cannot continue. When fatal
                errors are called with this function the script will terminate.
                [Options]
                    1,2,3,4,5
            .PARAMETER SetLogFile
                Set the fully quallified path to the log file you want used. If not defined, the log will use the
                "$Env:SystemDrive\ProgramData\Scripts\Logs" directory and will name the log file the same as the
                script name.
            .PARAMETER SetWriteHost
                Configure if the script should write events to the screen. (Default: $False)
                [Options]
                    $True,$False
            .PARAMETER SetWriteLog
                Configure if the script should write events to the screen. (Default: $True)
                [Options]
                    $True,$False
            .PARAMETER Close
                Removes all script-level variables set while nLog creates while running.
            .INPUTS
                None
            .OUTPUTS
                None
            .NOTES
            VERSION     DATE			NAME						DESCRIPTION
            ___________________________________________________________________________________________________________
            1.0			25 May 2020		Warila, Nicholas R.			Initial version
            2.0			28 Aug 2020		Warila, Nicholas R.			Complete rewrite of major portions of the script, significant improvement in script performance (about 48%), and updated log format.
            Credits:
                (1) Script Template: https://gist.github.com/9to5IT/9620683
        #>
        Param (
            [Parameter(Mandatory=$True,Position=0)]
            [ValidateSet('Debug','Info','Warning','Error','Fatal')]
            [String]$Type,
            [Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=1)]
            [String]$Message,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=2)][ValidateRange(0,9999)]
            [Int]$ErrorCode = 0,
            [Switch]$WriteHost,
            [Switch]$WriteLog,
            [Switch]$Initialize,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [ValidateSet('Debug','Info','Warning','Error','Fatal')]
            [String]$SetLogLevel,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [String]$SetLogFile,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [String]$SetLogDir,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [Bool]$SetWriteHost,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [Bool]$SetWriteLog,
            [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
            [ValidateSet('Local','UTC')]
            [String]$SetTimeLocalization,
            [ValidateSet('nLog','CMTrace')]
            [String]$SetLogFormat,
            [Int]$Line,
            [Switch]$Close
        )

        #Best practices to ensure function works exactly as expected, and prevents adding "-ErrorAction Stop" to so many critical items.
        #$Local:ErrorActionPreference = 'Stop'
        #Set-StrictMode -Version Latest

        #Allows us to turn on verbose on all powershell commands when adding -verbose
        IF ($PSBoundParameters.ContainsKey('Verbose')) {
            Set-Variable -Name Verbose -Value $True
        } Else {
            IF (Test-Path -Path Variable:\verbose) {
                Set-Variable -Name Verbose -Value ([Bool]$Script:Verbose)
            } Else {
                Set-Variable -Name Verbose -Value $False
            }
        }

        New-Variable -Name StartTime -Value ([DateTime]::Now) -Force -Verbose:$Verbose -Description "Used to calculate timestamp differences between log calls."

        #Ensure all the required script-level variables are set.
        IF ((-Not (Test-Path variable:Script:nLogInitialize)) -OR $Initialize) {
            New-Variable -Name SetTimeLocalization -Verbose:$Verbose -Scope Script -Force -Value ([DateTime]::Now)
            New-Variable -Name nLogFormat          -Verbose:$Verbose -Scope Script -Force -Value "nLog"
            New-Variable -Name nLogLevel           -Verbose:$Verbose -Scope Script -Force -Value ([String]"Info")
            New-Variable -Name nLogInitialize      -Verbose:$Verbose -Scope Script -Force -Value $True
            New-Variable -Name nLogWriteHost       -Verbose:$Verbose -Scope Script -Force -Value $False
            New-Variable -Name nLogWriteLog        -Verbose:$Verbose -Scope Script -Force -Value $True
            New-Variable -Name nLogLastTimeStamp   -Verbose:$Verbose -Scope Script -Force -Value $StartTime

            New-Variable -Name nLogDir             -Verbose:$Verbose -Scope Script -Force -Value $ScriptEnv.Script.DirectoryName
            New-Variable -Name nLogFile            -Verbose:$Verbose -Scope Script -Force -Value "$($ScriptEnv.Script.BaseName)`.log"
            New-Variable -Name nLogFullName        -Verbose:$Verbose -Scope Script -Force -Value "$nLogDir\$nLogFile"
            New-Variable -Name nLogFileValid       -Verbose:$Verbose -Scope Script -Force -Value $False

            New-Variable -Name nLogLevels        -Verbose:$Verbose -Scope Script -Force -Value $([HashTable]@{
                Debug   = @{ Text = "[DEBUG]  "; LogLevel = [Int]'1'; tForeGroundColor = "Cyan";   }
                Info    = @{ Text = "[INFO]   "; LogLevel = [Int]'2'; tForeGroundColor = "White";  }
                Warning = @{ Text = "[WARNING]"; LogLevel = [Int]'3'; tForeGroundColor = "DarkRed";}
                Error   = @{ Text = "[ERROR]  "; LogLevel = [Int]'4'; tForeGroundColor = "Red";    }
                Fatal   = @{ Text = "[FATAL]  "; LogLevel = [Int]'5'; tForeGroundColor = "Red";    }
            })
        }

        Switch($PSBoundParameters.Keys) {
            'SetLogLevel'  {Set-Variable -Name nLogLevel     -Verbose:$Verbose -Scope Script -Force -Value $SetLogLevel  }
            'SetLogFormat' {Set-Variable -Name nLogFormat    -Verbose:$Verbose -Scope Script -Force -Value $SetLogFormat}
            'SetWriteHost' {Set-Variable -Name nLogWriteHost -Verbose:$Verbose -Scope Script -Force -Value $SetWriteHost }
            'SetWriteLog'  {Set-Variable -Name nLogWriteLog  -Verbose:$Verbose -Scope Script -Force -Value $SetWriteLog  }
            'SetLogDir'    {
                Set-Variable -Name nLogDir       -Verbose:$Verbose -Scope Script -Force -Value $SetLogDir
                Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $False
            }
            'SetLogFile'   {
                Set-Variable -Name nLogFile      -Verbose:$Verbose -Scope Script -Force -Value "$($SetLogFile -replace "[$([string]::join('',([System.IO.Path]::GetInvalidFileNameChars())) -replace '\\','\\')]",'_')"
                Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $False
            }
            'SetTimeLocalization' {
                #Prevent issues where timestamp will show huge differences in time between code calls when converting UCT and Local
                If ($Script:nLogTimeLocalization -ne $SetTimeLocalization -AND -NOT [String]::IsNullOrWhiteSpace($Script:nLogLastTimeStamp)) {
                    If ($Script:nLogTimeLocalization -eq 'Local') {
                        Set-Variable -Name nLogLastTimeStamp -Verbose:$Verbose -Scope Script -Force -Value $nLogLastTimeStamp.ToLocalTime()
                    } Else {
                        Set-Variable -Name nLogLastTimeStamp -Verbose:$Verbose -Scope Script -Force -Value $nLogLastTimeStamp.ToUniversalTime()
                    }
                }
                Set-Variable -Name nLogTimeLocalization -Verbose:$Verbose -Scope Script -Force -Value $SetTimeLocalization
            }
        }

        IF (-NOT $PSBoundParameters.ContainsKey('Line')) {
            Set-Variable Line -Verbose:$Verbose -Force -Value $MyInvocation.ScriptLineNumber
        }
        IF ($PSBoundParameters.ContainsKey('WriteHost')) { $tWriteHost = $True } Else { $tWriteHost = $Script:nLogWriteHost }
        IF ($PSBoundParameters.ContainsKey('WriteLog'))  { $tWriteLog  = $True } Else { $tWriteLog  = $Script:nLogWriteLog  }

        #Determine if script log level greater than or equal to current log event level and we actually are configured to write something.
        IF ($Script:nLogLevels[$Type]["LogLevel"] -ge $Script:nLogLevels[$Script:nLogLevel]["LogLevel"] -AND $Script:nLogLevel -ne 0 -AND ($tWriteHost -EQ $True -OR $tWriteLog -EQ $True)) {

            #Convert TimeStamp if needed
            IF ($Script:nLogTimeLocalization -eq 'UTC') {
                Set-Variable -Name StartTime -Value ($StartTime.ToUniversalTime().ToString("s",[System.Globalization.CultureInfo]::InvariantCulture))
            }

            #Code Block if writing out to log file.
            If ($tWriteLog) {
                IF ($Script:nLogFileValid -eq $False) {
                    Set-Variable -Name nLogFullName      -Verbose:$Verbose -Scope Script -Force -Value (Join-Path -Path $Script:nLogDir -ChildPath $Script:nLogFile)

                    #[Test Write access to results file.]
                    If ([system.io.file]::Exists($Script:nLogFullName)) {
                        Try {
                            (New-Object -TypeName 'System.IO.FileStream' -ArgumentList $Script:nLogFullName,([System.IO.FileMode]::Open),([System.IO.FileAccess]::Write),([System.IO.FileShare]::Write),4096,([System.IO.FileOptions]::None)).Close()
                        } Catch {
                            Write-Error -Message "Unable to open $Script:nLogFile. (Full Path: '$Script:nLogFullName')"
                            exit
                        }
                    } Else {
                        Try {
                            (New-Object -TypeName 'System.IO.FileStream' -ArgumentList $Script:nLogFullName,([System.IO.FileMode]::Create),([System.IO.FileAccess]::ReadWrite),([System.IO.FileShare]::ReadWrite),4096,([System.IO.FileOptions]::DeleteOnClose)).Close()
                        } Catch {
                            Write-Error -Message "Unable to create $Script:nLogFile. (Full Path: '$Script:nLogFullName')"
                        }
                    }
                    Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $True
                }

                New-Variable -Force -Verbose:$Verbose -Name FileStream   -Value (New-Object -TypeName 'System.IO.FileStream' -ArgumentList $Script:nLogFullName,([System.IO.FileMode]::Append),([System.IO.FileAccess]::Write),([System.IO.FileShare]::Write),4096,([System.IO.FileOptions]::WriteThrough))
                New-Variable -Force -Verbose:$Verbose -Name StreamWriter -Value (New-Object -TypeName 'System.IO.StreamWriter' -ArgumentList $FileStream,([Text.Encoding]::Default),4096,$False)

                Switch ($Script:nLogFormat) {
                    'CMTrace'    {
                        [String]$WriteLine = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">' -f `
                        $Message,
                        ([DateTime]$StartTime).ToString('HH:mm:ss.fff+000'),
                        ([DateTime]$StartTime).ToString('MM-dd-yyyy'),
                        "$($ScriptEnv.Script.Name):$($Line)",
                        "1"
                    }
                    'nLog' {
                        $WriteLine = "$StartTime||$Env:COMPUTERNAME||$Type||$($ErrorCode.ToString(`"0000`"))||$Line)||$Message"
                    }
                }
                $StreamWriter.WriteLine($WriteLine)
                $StreamWriter.Close()
            }

            #Code Block if writing out to log host.
            IF ($tWriteHost) {
                Write-Host -ForegroundColor $Script:nLogLevels[$Type]["tForeGroundColor"] -Verbose:$Verbose "$StartTime ($(((New-TimeSpan -Start $Script:nLogLastTimeStamp -End $StartTime -Verbose:$Verbose).Seconds).ToString('0000'))s) $($Script:nLogLevels[$Type]['Text']) [$($ErrorCode.ToString('0000'))] [Line: $($Line.ToString('0000'))] $Message"
            }

            #Ensure we have the timestamp of the last log execution.
            Set-Variable -Name nLogLastTimeStamp -Scope Script -Value $StartTime -Force -Verbose:$Verbose
        }

        #Remove Function Level Variables. This isn't needed unless manually running portions of the code instead of calling it via a funtion.
        #Remove-Variable -Name @("Message","SetLogLevel","SetLogFile","Close","SetWriteLog","SetWriteHost","LineNumber","ErrorCode","tWriteHost","WriteHost","tWriteLog","WriteLog","StartTime") -ErrorAction SilentlyContinue

        IF ($PSBoundParameters.ContainsKey('Close') -or $Type -eq 'Fatal') {
            Remove-Variable -Name @("nLogLastTimeStamp","nLogFileValid","nLogFile","nLogDir","nLogWriteLog","nLogWriteHost","nLogInitialize","nLogLastTimeStamp","nLogLevels","nLogFullName","nLogLevel") -Scope Script -ErrorAction SilentlyContinue
        }

        #Allow us to exit the script from the logging function.
        If ($Type -eq 'Fatal') {
            Exit
        }
    }

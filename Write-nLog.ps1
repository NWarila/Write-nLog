Function Write-nLog {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'nLog',
        HelpURI = '',
        SupportsPaging = $False,
        PositionalBinding = $False
    )]Param(
        [Parameter(Mandatory, ParameterSetName = 'Error')]
        [Parameter(Mandatory, ParameterSetName = 'nLog')]
        [String]$Message,

        #nLog Parameters
        [Parameter(ParameterSetName = 'nLog')]
        [ValidatePattern(('^Debug|Verbose|Information|'+
                'Warning|Error|\b([1-9]|[0-9][0-9]{1,2})\b'))]
        [String]$Type,
        [Switch]$WriteHost,
        [Switch]$WriteLog,
        [Switch]$Initialize,

        #nLog Configuration Parameters
        [ValidatePattern(('^Debug|Verbose|Information|'+
                'Warning|Error|\b([1-9]|[0-9][0-9]{1,2})\b'))]
        [String]$SetLevel = '400',
        [Bool]$SetWriteHost = $True,
        [Bool]$SetWriteLog = $True,
        [ValidateSet('Local', 'UTC')]
        [String]$SetTimeLocalization = 'Local',
        [ValidateSet('nLog', 'CMTrace')]
        [String]$SetFormat = 'CMTrace',
        [Int]$Line = $MyInvocation.ScriptLineNumber,
        [String]$SetLog = 'Auto',

        #Write-Information Output
        [Parameter(Mandatory, ParameterSetName = 'Information')]
        [Alias('MessageData', 'Writer')]
        [Object]$InputObject,
        [Parameter(ParameterSetName = 'Information')]
        [String[]]$Tags,

        #Write-Error Properties
        [Parameter(ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorCategory]$Category,
        [Parameter(ParameterSetName = 'Error')]
        [String]$CategoryActivity,
        [Parameter(ParameterSetName = 'Error')]
        [String]$CategoryReason,
        [Parameter(ParameterSetName = 'Error')]
        [String]$CategoryTargetName,
        [Parameter(ParameterSetName = 'Error')]
        [String]$CategoryTargetType,
        [Parameter(ParameterSetName = 'Error')]
        [String]$ErrorId,
        [Parameter(ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(ParameterSetName = 'Error')]
        [System.Exception]$Exception,
        [Parameter(ParameterSetName = 'Error')]
        [String]$RecommendedAction,
        [Parameter(ParameterSetName = 'Error')]
        [Object]$TargetObject
    )
    begin {
        #region ------ [ Out-Of-Cycle Declarations ] --------------------------------------------------------------
            New-Variable -Name:'StartTime' -Value:([DateTime]::Now)

            If (-NOT $PSBoundParameters.ContainsKey('Verbose')) {
                If (Test-Path -Path Variable:\verbose) {
                    Set-Variable -Name Verbose -Value ([Bool]$Script:Verbose)
                }
            }

            New-Variable -Scope:'Private' -Name:'vSplat' -Value:@{'Force'=$True;'Verbose'=$False}
            New-Variable -Scope:'Private' -Name:'LogLevels' -Value:@{'Verbose'='600';
                'Debug'='500';'Information'='400';'Warning'='300';'Error'='200';'Fatal'='0';
            }
            $Initialize = $Initialize -or (-Not (Test-Path -LiteralPath:'variable:Script:nLogInitialize'))

            #Log levels must include Verbose, Debug, Information, Warning, and Error otherwise it will cause issues.
            <# To be implemented.
            New-Variable -Force -Scope:'Private' -Name:'LogLevels' -Value:@{
                '600' = @{'FullName'='Verbose'    ;'ShortName'='Trace';'FGColor'='';'BGColor'=''};
                '500' = @{'FullName'='Debug'      ;'ShortName'='Debug';'FGColor'='';'BGColor'=''};
                '400' = @{'FullName'='Information';'ShortName'='Info' ;'FGColor'='';'BGColor'=''};
                '300' = @{'FullName'='Warning'    ;'ShortName'='Warn' ;'FGColor'='';'BGColor'=''};
                '200' = @{'FullName'='Error'      ;'ShortName'='Error';'FGColor'='';'BGColor'=''};
                '100' = @{'FullName'='Fatal'      ;'ShortName'='Fatal';'FGColor'='';'BGColor'=''};
            }
            #>
        #endregion --- [ Out-Of-Cycle Declarations ] --------------------------------------------------------------

        #region ------ [ Script nLog Initialization ] --------------------------------------------------------------
            #If Write-nLog needs to be initalized, do that before anything.
            If ($Initialize) {
                Try {
                    #Ensure Alias are configured properly to intercept with Write-nLog
                    ForEach ($Alias in @('Verbose','Debug','Information','Warning','Error')) {
                        Set-Alias -Force -Scope:1 -Name:"Write-$Alias" -Value:'Write-nLog'
                    }

                    #Initalize Script-level variables
                    New-Variable @vSplat -Scope:Script -Name:'nLogLastTimeStamp' -Value:$StartTime
                    New-Variable @vSplat -Scope:Script -Name:'nLogFileValid' -Value:$False
                    New-Variable @vSplat -Scope:Script -Name:'nLogLevel' -Value:$LogLevels[$SetLevel]

                    ForEach ($Param in @('Format','WriteHost','WriteLog','Log','TimeLocalization')) {
                        New-Variable  @vSplat -Scope:'Script' -Name:"nLog$Param" -Value:(
                            Get-Variable -Name:"Set$Param" -ValueOnly
                        )
                    }

                    #If initalization was successful; mark nlog as initalized.
                    New-Variable @vSplat -Scope:Script -Name:'nLogInitialize' -Value:$True
                } Catch {
                    Remove-Variable -Scope:Script -Name:'nLogInitialize'
                    Throw $_
                }
            }
        #endregion --- [ Script nLog Initialization ] ------------------------------------------------------------

        #region ------ [Parameter Validation] --------------------------------------------------------------------

            #Determine Event Category
            If ([String]::IsNullOrWhiteSpace($Type)) {
                Switch($MyInvocation.InvocationName.Split('-')[1]) {
                    {$LogLevels.Keys -contains $PSItem} {
                        $Type = $LogLevels[$PSItem]; break
                    }
                    'nLog' {Throw 'Type needs to be defined'}
                    Default {Throw "Unknown Invocation name of '$($MyInvocation.InvocationName)'."}
                }
            }
        #endregion --- [ Parameter Validation ] ------------------------------------------------------------------

        #region ------ [Process Parameters] ----------------------------------------------------------------------
            Switch -Regex ($PSBoundParameters.Keys) {
                #Parameters that don't require additional Validation.
                '^Set(?:Write|Log)?(?:Format|Host|Log)$' {
                    Set-Variable @vSplat -Scope:Script -Name:"nLog$($PSItem.SubString(3))" -Value:(
                        $PSBoundParameters[$PSItem]
                    )
                }
                'SetLevel' {
                    If ($LogLevels.Keys -contains $SetLevel) {
                        Set-Variable @vSplat -Scope:Script -Name:'nLogLevel' -Value:$LogLevels[$SetLevel]
                    } Else {
                        Set-Variable @vSplat -Scope:Script -Name:'nLogLevel' -Value:$SetLevel
                    }
                }
                'SetLog' {
                    Set-Variable @vSplat -Scope:Script -Name:'nLogFileValid' -Value:$False
                }
                'SetTimeLocalization' {
                    If ($Script:nLogTimeLocalization -ne $SetTimeLocalization) {
                        Set-Variable @vSplat -Scope:'Script' -Name:'nLogTimeLocalization' -Value:($SetTimeLocalization)
                        If ($SetTimeLocalization -eq 'Local') {
                            Set-Variable @vSplat -Scope:Script -Name:nLogLastTimeStamp -Value:(
                                $Script:nLogLastTimeStamp.ToLocalTime()
                            )
                        } Else {
                            Set-Variable @vSplat -Scope:Script -Name:nLogLastTimeStamp -Value:(
                                $Script:nLogLastTimeStamp.ToUniversalTime()
                            )
                        }
                    }
                }
            }

            #Configure the one-off over ride functions.
            ForEach ($_Param in @('WriteHost','WriteLog')) {
                If (-Not $PSBoundParameters.ContainsKey('WriteHost')) {
                    Set-Variable @vSplat -Name:$_Param -Value:(
                        Get-Variable -Name:"nLog$_Param" -ValueOnly
                    )
                }
            }
        #endregion --- [Process Parameters] ----------------------------------------------------------------------

        #region
        If (($Type -le $Script:nLogLevel) -and ($WriteHost -or $WriteLog)) {
            #Write-host $MyInvocation.InvocationName
            If ($Script:nLogTimeLocalization -eq 'UTC') {
                $StartTime = $StartTime.ToUniversalTime()
            }
            $_Loginterval = New-TimeSpan -Start:$Script:nLogLastTimeStamp -End:$StartTime
            Set-Variable @vSplat -Scope:Script -Name:'nLogLastTimeStamp' -Value:$StartTime
            New-Variable @vSplat -Name:ParentInvocation -Value:(
                Get-Variable -Scope:1 -Name:MyInvocation -ValueOnly
            )

            #Categorize

        }
    }
    Process {
        If (($Type -le $Script:nLogLevel) -and ($WriteHost -or $WriteLog)) {


            If ($WriteHost) {
                Write-Host -NoNewline -ForegroundColor:'Green' -Object:(
                    "$($StartTime.ToString('yyyy-MM-dd hh:mm:ss.fff')) " +
                    "($($_Loginterval.Seconds.ToString('0000'))s) "
                )
                Write-Host -NoNewline -ForegroundColor:'Blue' -Object:(
                    "[$($Line.ToString('0000'))] "
                )

                Write-Host -NoNewline -ForegroundColor:Cyan -Object:(
                    ($ParentInvocation.MyCommand.Name[0..19] -join '').PadRight(20, ' ')
                )

                Write-Host -NoNewline -ForegroundColor:Cyan -Object:(
                    "[$((($LogLevels.GetEnumerator().Where({ [int]$_.Value -le $Type }) |
                    Sort-Object -Descending -Property:'Value' |
                    Select-Object -First:1 -ExpandProperty:'Name')[0..4] -join '').PadRight(5, ' '))] "
                )
                Write-Host
            }
        }


    }
    End {

        IF ($PSBoundParameters.ContainsKey('Close') -or $Type -eq 'Fatal') {
            Remove-Variable -Name:"nLog*" -Scope:'Script' -ErrorAction:'SilentlyContinue'
        }

    }
}

Write-nLog -Message:'nLog' -Type:113
Write-nLog -Message:'nLog' -Type:110
Write-Host 'nLog Initalized'
Write-nLog -Message:'nLog' -Type:123
Write-Verbose -Message:'Verbose' -SetLevel:Verbose
Write-Debug -Message:'Debug' -SetWriteHost:$True
Write-Warning -Message:'Warning' -SetWriteLog:$False
Write-Information -Message:'Information' -SetTimeLocalization:'UTC'
Write-Information -InputObject:'something','somethingelse' -SetFormat:nLog -SetLog:'C:\Temp\log.log'
Write-Error -Message:'123' -ErrorId:123
Remove-Variable -Name:"nLog*"

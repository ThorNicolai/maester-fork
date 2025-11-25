<#
.SYNOPSIS
    Tests if users have inactive authentication methods that have not been used recently.

.DESCRIPTION
    This function checks all users for authentication methods that have not been used
    within a specified number of days. Authentication methods that are registered but
    never used (null lastUsedDateTime) or have not been used for a long time may indicate
    stale credentials that should be reviewed or removed.

    The test retrieves authentication methods for each user and evaluates the lastUsedDateTime
    property to determine if any methods are inactive.

.PARAMETER InactiveDays
    The number of days after which an authentication method is considered inactive.
    Default is 90 days. Methods with lastUsedDateTime older than this threshold or
    with null lastUsedDateTime will be flagged as inactive.

.OUTPUTS
    [bool] - Returns $true if no inactive authentication methods are found, $false if any are found, $null if skipped.

.EXAMPLE
    Test-MtInactiveAuthenticationMethods

    Checks all users for inactive authentication methods using the default 90-day threshold.

.EXAMPLE
    Test-MtInactiveAuthenticationMethods -InactiveDays 180

    Checks all users for authentication methods not used in the last 180 days.

.LINK
    https://maester.dev/docs/commands/Test-MtInactiveAuthenticationMethods
#>

function Test-MtInactiveAuthenticationMethods {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple authentication methods for all users.')]
    [OutputType([bool])]
    param(
        [Parameter()]
        [int]$InactiveDays = 90
    )

    # Early exit if Graph connection is not available
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    # Define authentication method type mapping for display names
    $authMethodTypeMap = @{
        '#microsoft.graph.emailAuthenticationMethod'                        = 'Email'
        '#microsoft.graph.externalAuthenticationMethod'                     = 'External Authentication Method'
        '#microsoft.graph.fido2AuthenticationMethod'                        = 'FIDO2'
        '#microsoft.graph.hardwareOathAuthenticationMethod'                 = 'Hardware OATH'
        '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'       = 'Microsoft Authenticator'
        '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod' = 'Passwordless Microsoft Authenticator'
        '#microsoft.graph.passwordAuthenticationMethod'                     = 'Password'
        '#microsoft.graph.phoneAuthenticationMethod'                        = 'Phone (SMS or Voice)'
        '#microsoft.graph.platformCredentialAuthenticationMethod'           = 'Platform Credential'
        '#microsoft.graph.qrCodePinAuthenticationMethod'                    = 'QR Code PIN'
        '#microsoft.graph.softwareOathAuthenticationMethod'                 = 'Software OATH'
        '#microsoft.graph.temporaryAccessPassAuthenticationMethod'          = 'Temporary Access Pass'
        '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod'      = 'Windows Hello for Business'
    }

    try {
        Write-Verbose "Step 1: Retrieving all users..."

        # Retrieve all users - we need to iterate through users to check their auth methods
        $allUsers = Invoke-MtGraphRequest -RelativeUri 'users' -Select 'id,userPrincipalName,displayName' -ErrorAction Stop

        Write-Verbose "Found $($allUsers.Count) users."

        if ($allUsers.Count -eq 0) {
            Add-MtTestResultDetail -Result "No users found in the tenant."
            return $true
        }

        Write-Verbose "Step 2: Checking authentication methods for each user..."

        # Calculate the threshold date
        $thresholdDate = (Get-Date).AddDays(-$InactiveDays)

        # Collections to store results
        $inactiveMethodsFound = [System.Collections.Generic.List[PSCustomObject]]::new()
        $usersChecked = 0
        $usersWithInactiveMethods = 0

        foreach ($user in $allUsers) {
            $usersChecked++

            try {
                # Get authentication methods for this user using beta API (required for lastUsedDateTime)
                $userAuthMethods = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "users/$($user.id)/authentication/methods" -ErrorAction Stop

                foreach ($method in $userAuthMethods) {
                    $methodType = $method.'@odata.type'

                    # Skip password authentication method as it's always present and doesn't have meaningful lastUsedDateTime
                    if ($methodType -eq '#microsoft.graph.passwordAuthenticationMethod') {
                        continue
                    }

                    $lastUsed = $method.lastUsedDateTime
                    $isInactive = $false
                    $inactiveReason = ''

                    if ($null -eq $lastUsed -or [string]::IsNullOrEmpty($lastUsed)) {
                        $isInactive = $true
                        $inactiveReason = 'Never used'
                    } elseif ([DateTime]$lastUsed -lt $thresholdDate) {
                        $isInactive = $true
                        $inactiveReason = "Last used: $([DateTime]$lastUsed.ToString('yyyy-MM-dd'))"
                    }

                    if ($isInactive) {
                        $methodDisplayName = if ($authMethodTypeMap.ContainsKey($methodType)) {
                            $authMethodTypeMap[$methodType]
                        } else {
                            ($methodType -replace '#microsoft.graph.', '') -replace 'AuthenticationMethod', ''
                        }

                        $inactiveMethodsFound.Add([PSCustomObject]@{
                            UserId          = $user.id
                            UserPrincipalName = $user.userPrincipalName
                            DisplayName     = $user.displayName
                            MethodType      = $methodDisplayName
                            MethodId        = $method.id
                            InactiveReason  = $inactiveReason
                        })
                    }
                }

                if ($inactiveMethodsFound | Where-Object { $_.UserId -eq $user.id }) {
                    $usersWithInactiveMethods++
                }

            } catch {
                Write-Verbose "Could not retrieve authentication methods for user $($user.userPrincipalName): $($_.Exception.Message)"
            }
        }

        Write-Verbose "Summary - Users checked: $usersChecked, Users with inactive methods: $usersWithInactiveMethods, Total inactive methods: $($inactiveMethodsFound.Count)"

        # Determine test result
        $testPassed = ($inactiveMethodsFound.Count -eq 0)

        # Generate detailed markdown report
        if ($testPassed) {
            $testResultMarkdown = "**Well done!** No inactive authentication methods were found.`n`n"
            $testResultMarkdown += "**Summary:** Checked $usersChecked user(s). All registered authentication methods have been used within the last $InactiveDays days."
        } else {
            $testResultMarkdown = "**Action Required:** Found $($inactiveMethodsFound.Count) inactive authentication method(s) across $usersWithInactiveMethods user(s).`n`n"
            $testResultMarkdown += "Authentication methods that have not been used in $InactiveDays days or have never been used should be reviewed.`n`n"

            # Create table of inactive methods
            $testResultMarkdown += "| User | Method Type | Status |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"

            foreach ($inactiveMethod in $inactiveMethodsFound) {
                $userLink = "[$($inactiveMethod.UserPrincipalName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($inactiveMethod.UserId))"
                $testResultMarkdown += "| $userLink | $($inactiveMethod.MethodType) | $($inactiveMethod.InactiveReason) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

    } catch {
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "**Error** checking inactive authentication methods: $($_.Exception.Message)"
        return $false
    }

    return $testPassed
}

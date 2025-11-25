<#
.SYNOPSIS
    Tests if users have inactive Phone (SMS or Voice) authentication methods.

.DESCRIPTION
    This function checks all users for Phone (SMS or Voice) authentication methods that
    have not been used within the specified number of days. Phone authentication methods that are
    registered but inactive may indicate stale credentials that should be reviewed or removed.

    The test retrieves authentication methods for each user and evaluates the lastUsedDateTime
    property to identify phone methods that are inactive.

.PARAMETER InactiveDays
    The number of days after which a Phone (SMS or Voice) authentication method is considered inactive.
    Default is 90 days. This can be overridden via the maester-config.json file by setting
    the InactiveDays property for test MT.1106.

.OUTPUTS
    [bool] - Returns $true if no inactive phone authentication methods are found, $false if any are found, $null if skipped.

.EXAMPLE
    Test-MtInactiveAuthenticationMethods

    Checks all users for inactive Phone (SMS or Voice) authentication methods using the default 90-day threshold.

.EXAMPLE
    Test-MtInactiveAuthenticationMethods -InactiveDays 180

    Checks all users for phone authentication methods not used in the last 180 days.

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

    # Check for config override of InactiveDays
    $testConfig = Get-MtMaesterConfigTestSetting -TestId 'MT.1106'
    if ($testConfig -and $testConfig.InactiveDays) {
        $InactiveDays = $testConfig.InactiveDays
        Write-Verbose "Using InactiveDays from config: $InactiveDays"
    }

    # Phone authentication method type
    $phoneMethodType = '#microsoft.graph.phoneAuthenticationMethod'
    $phoneMethodDisplayName = 'Phone (SMS or Voice)'

    try {
        Write-Verbose "Step 1: Retrieving all users..."

        # Retrieve all users - we need to iterate through users to check their auth methods
        $allUsers = Invoke-MtGraphRequest -RelativeUri 'users' -Select 'id,userPrincipalName,displayName' -ErrorAction Stop

        Write-Verbose "Found $($allUsers.Count) users."

        if ($allUsers.Count -eq 0) {
            Add-MtTestResultDetail -Result "No users found in the tenant."
            return $true
        }

        Write-Verbose "Step 2: Checking Phone (SMS or Voice) authentication methods for each user..."

        # Calculate the threshold date
        $thresholdDate = (Get-Date).AddDays(-$InactiveDays)

        # Collections to store results
        $inactiveMethodsFound = [System.Collections.Generic.List[PSCustomObject]]::new()
        $usersWithInactiveMethodsSet = [System.Collections.Generic.HashSet[string]]::new()
        $skippedUsers = [System.Collections.Generic.List[PSCustomObject]]::new()
        $usersChecked = 0

        foreach ($user in $allUsers) {
            $usersChecked++

            try {
                # Get authentication methods for this user using beta API (required for lastUsedDateTime)
                $userAuthMethods = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "users/$($user.id)/authentication/methods" -ErrorAction Stop

                foreach ($method in $userAuthMethods) {
                    $methodType = $method.'@odata.type'

                    # Only check Phone (SMS or Voice) authentication methods
                    if ($methodType -ne $phoneMethodType) {
                        continue
                    }

                    $lastUsed = $method.lastUsedDateTime
                    $isInactive = $false
                    $inactiveReason = ''

                    if ($null -eq $lastUsed -or [string]::IsNullOrEmpty($lastUsed)) {
                        $isInactive = $true
                        $inactiveReason = 'Never used'
                    } else {
                        # Safely parse the date
                        $parsedDate = $null
                        if ([DateTime]::TryParse($lastUsed, [ref]$parsedDate)) {
                            if ($parsedDate -lt $thresholdDate) {
                                $isInactive = $true
                                $inactiveReason = "Last used: $($parsedDate.ToString('yyyy-MM-dd'))"
                            }
                        } else {
                            Write-Verbose "Could not parse lastUsedDateTime '$lastUsed' for method $methodType"
                        }
                    }

                    if ($isInactive) {
                        $inactiveMethodsFound.Add([PSCustomObject]@{
                            UserId            = $user.id
                            UserPrincipalName = $user.userPrincipalName
                            DisplayName       = $user.displayName
                            MethodType        = $phoneMethodDisplayName
                            MethodId          = $method.id
                            PhoneType         = $method.phoneType
                            InactiveReason    = $inactiveReason
                        })

                        # Track this user as having inactive methods
                        [void]$usersWithInactiveMethodsSet.Add($user.id)
                    }
                }

            } catch {
                $skippedUsers.Add([PSCustomObject]@{
                    UserId            = $user.id
                    UserPrincipalName = $user.userPrincipalName
                    DisplayName       = $user.displayName
                    Reason            = $_.Exception.Message
                })
                Write-Verbose "Could not retrieve authentication methods for user $($user.userPrincipalName): $($_.Exception.Message)"
            }
        }

        $usersWithInactiveMethods = $usersWithInactiveMethodsSet.Count

        Write-Verbose "Summary - Users checked: $usersChecked, Users skipped: $($skippedUsers.Count), Users with inactive phone methods: $usersWithInactiveMethods, Total inactive phone methods: $($inactiveMethodsFound.Count)"

        # Determine test result
        $testPassed = ($inactiveMethodsFound.Count -eq 0)

        # Generate detailed markdown report
        if ($testPassed) {
            $testResultMarkdown = "**Well done!** No inactive Phone (SMS or Voice) authentication methods were found.`n`n"
            $testResultMarkdown += "**Summary:** Checked $usersChecked user(s). All registered Phone (SMS or Voice) authentication methods have been used within the last $InactiveDays days."
            if ($skippedUsers.Count -gt 0) {
                $testResultMarkdown += "`n`n**Note:** $($skippedUsers.Count) user(s) could not be checked (possibly due to permissions or disabled accounts):`n`n"
                $testResultMarkdown += "| User | Reason |`n"
                $testResultMarkdown += "| --- | --- |`n"
                foreach ($skippedUser in $skippedUsers) {
                    $userLink = "[$($skippedUser.UserPrincipalName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedUser.UserId))"
                    $testResultMarkdown += "| $userLink | $($skippedUser.Reason) |`n"
                }
            }
        } else {
            $testResultMarkdown = "**Action Required:** Found $($inactiveMethodsFound.Count) inactive Phone (SMS or Voice) authentication method(s) across $usersWithInactiveMethods user(s).`n`n"
            $testResultMarkdown += "Phone (SMS or Voice) authentication methods that have not been used in $InactiveDays days or have never been used should be reviewed and removed.`n`n"

            # Create table of inactive methods (without phone numbers for PII protection)
            $testResultMarkdown += "| User | Phone Type | Status |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"

            foreach ($inactiveMethod in $inactiveMethodsFound) {
                $userLink = "[$($inactiveMethod.UserPrincipalName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($inactiveMethod.UserId))"
                $testResultMarkdown += "| $userLink | $($inactiveMethod.PhoneType) | $($inactiveMethod.InactiveReason) |`n"
            }

            if ($skippedUsers.Count -gt 0) {
                $testResultMarkdown += "`n**Note:** $($skippedUsers.Count) user(s) could not be checked (possibly due to permissions or disabled accounts):`n`n"
                $testResultMarkdown += "| User | Reason |`n"
                $testResultMarkdown += "| --- | --- |`n"
                foreach ($skippedUser in $skippedUsers) {
                    $userLink = "[$($skippedUser.UserPrincipalName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedUser.UserId))"
                    $testResultMarkdown += "| $userLink | $($skippedUser.Reason) |`n"
                }
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

    } catch {
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "**Error** checking inactive Phone (SMS or Voice) authentication methods: $($_.Exception.Message)"
        return $false
    }

    return $testPassed
}

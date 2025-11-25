<#
.SYNOPSIS
    Tests if users have never used Phone (SMS or Voice) authentication methods.

.DESCRIPTION
    This function checks all users for Phone (SMS or Voice) authentication methods that
    have never been used (null lastUsedDateTime). Phone authentication methods that are
    registered but never used may indicate stale credentials that should be reviewed or removed.

    The test retrieves authentication methods for each user and evaluates the lastUsedDateTime
    property to identify phone methods that have never been used.

.OUTPUTS
    [bool] - Returns $true if no never-used phone authentication methods are found, $false if any are found, $null if skipped.

.EXAMPLE
    Test-MtInactiveAuthenticationMethods

    Checks all users for never-used Phone (SMS or Voice) authentication methods.

.LINK
    https://maester.dev/docs/commands/Test-MtInactiveAuthenticationMethods
#>

function Test-MtInactiveAuthenticationMethods {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple authentication methods for all users.')]
    [OutputType([bool])]
    param()

    # Early exit if Graph connection is not available
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
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

        # Collections to store results
        $neverUsedMethodsFound = [System.Collections.Generic.List[PSCustomObject]]::new()
        $usersWithNeverUsedMethodsSet = [System.Collections.Generic.HashSet[string]]::new()
        $usersChecked = 0
        $usersSkipped = 0

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

                    # Only flag methods that have never been used
                    if ($null -eq $lastUsed -or [string]::IsNullOrEmpty($lastUsed)) {
                        $neverUsedMethodsFound.Add([PSCustomObject]@{
                            UserId            = $user.id
                            UserPrincipalName = $user.userPrincipalName
                            DisplayName       = $user.displayName
                            MethodType        = $phoneMethodDisplayName
                            MethodId          = $method.id
                            PhoneNumber       = $method.phoneNumber
                            PhoneType         = $method.phoneType
                        })

                        # Track this user as having never-used methods
                        [void]$usersWithNeverUsedMethodsSet.Add($user.id)
                    }
                }

            } catch {
                $usersSkipped++
                Write-Verbose "Could not retrieve authentication methods for user $($user.userPrincipalName): $($_.Exception.Message)"
            }
        }

        $usersWithNeverUsedMethods = $usersWithNeverUsedMethodsSet.Count

        Write-Verbose "Summary - Users checked: $usersChecked, Users skipped: $usersSkipped, Users with never-used phone methods: $usersWithNeverUsedMethods, Total never-used phone methods: $($neverUsedMethodsFound.Count)"

        # Determine test result
        $testPassed = ($neverUsedMethodsFound.Count -eq 0)

        # Generate detailed markdown report
        if ($testPassed) {
            $testResultMarkdown = "**Well done!** No never-used Phone (SMS or Voice) authentication methods were found.`n`n"
            $testResultMarkdown += "**Summary:** Checked $usersChecked user(s). All registered Phone (SMS or Voice) authentication methods have been used."
            if ($usersSkipped -gt 0) {
                $testResultMarkdown += "`n`n**Note:** $usersSkipped user(s) could not be checked (possibly due to permissions or disabled accounts)."
            }
        } else {
            $testResultMarkdown = "**Action Required:** Found $($neverUsedMethodsFound.Count) never-used Phone (SMS or Voice) authentication method(s) across $usersWithNeverUsedMethods user(s).`n`n"
            $testResultMarkdown += "Phone (SMS or Voice) authentication methods that have never been used should be reviewed and removed.`n`n"

            # Create table of never-used methods
            $testResultMarkdown += "| User | Phone Number | Phone Type |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"

            foreach ($neverUsedMethod in $neverUsedMethodsFound) {
                $userLink = "[$($neverUsedMethod.UserPrincipalName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($neverUsedMethod.UserId))"
                $testResultMarkdown += "| $userLink | $($neverUsedMethod.PhoneNumber) | $($neverUsedMethod.PhoneType) |`n"
            }

            if ($usersSkipped -gt 0) {
                $testResultMarkdown += "`n**Note:** $usersSkipped user(s) could not be checked (possibly due to permissions or disabled accounts)."
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

    } catch {
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "**Error** checking never-used Phone (SMS or Voice) authentication methods: $($_.Exception.Message)"
        return $false
    }

    return $testPassed
}

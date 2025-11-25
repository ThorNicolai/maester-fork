Describe "Maester/Entra" -Tag "Maester", "Authentication", "Security" {
    It "MT.1067: Authentication method policies should not reference non-existent groups. See https://maester.dev/docs/tests/MT.1067" -Tag "MT.1067" {

        Test-MtAuthenticationPolicyReferencedObjectsExist | Should -Be $true -Because "authentication method policies should not reference deleted or non-existent groups"
    }

    It "MT.1106: Users should not have never-used Phone (SMS or Voice) authentication methods. See https://maester.dev/docs/tests/MT.1106" -Tag "MT.1106" {

        Test-MtInactiveAuthenticationMethods | Should -Be $true -Because "never-used Phone (SMS or Voice) authentication methods may indicate stale credentials that should be reviewed or removed"
    }
}

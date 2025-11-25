---
title: MT.1106 - Users should not have inactive Phone (SMS or Voice) authentication methods.
description: This test checks if users have Phone (SMS or Voice) authentication methods that have not been used recently.
slug: /tests/MT.1106
sidebar_class_name: hidden
---

## Description

This test checks if users have Phone (SMS or Voice) authentication methods registered that have not been used within the configured threshold (default: 90 days).

Phone authentication methods that are registered but inactive may indicate:

- Stale credentials that should be removed
- Methods set up but abandoned during onboarding
- Potential security concerns if users are not using expected authentication methods

The test retrieves authentication methods for each user and evaluates the `lastUsedDateTime` property to identify Phone (SMS or Voice) methods that are inactive.

The `InactiveDays` threshold can be customized via the `maester-config.json` file by setting the `InactiveDays` property for test `MT.1106`.

## How to fix

If this test fails, you should:

1. **Review the identified users and their inactive phone methods** - Determine if the methods are still needed
2. **Contact users** - Verify if they are aware of the registered phone methods and if they should be using them
3. **Remove unused methods** - If a phone method is no longer needed, remove it from the user's account

To remove a phone authentication method:

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Users** > **All users**
3. Select the user with the inactive phone method
4. Go to **Authentication methods**
5. Remove the unused phone authentication method

## Learn more

- [Authentication methods in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods)
- [Manage user authentication methods](https://learn.microsoft.com/entra/identity/authentication/howto-mfa-userdevicesettings)

## Related links

- [Entra admin center - Users](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers/menuId/AllUsers)
- [Entra admin center - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity)

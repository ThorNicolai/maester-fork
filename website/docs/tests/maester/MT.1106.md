---
title: MT.1106 - Users should not have inactive authentication methods.
description: This test checks if users have inactive authentication methods that have not been used recently.
slug: /tests/MT.1106
sidebar_class_name: hidden
---

## Description

This test checks if users have authentication methods registered that have not been used within a specified threshold (default: 90 days).

Authentication methods that are registered but have never been used, or have not been used for an extended period, may indicate:

- Stale credentials that should be removed
- Methods set up but abandoned during onboarding
- Potential security concerns if users are not using expected authentication methods

The test retrieves authentication methods for each user and evaluates the `lastUsedDateTime` property to determine if any methods are inactive.

### Authentication method types checked

| Type | Display Name |
|------|--------------|
| #microsoft.graph.emailAuthenticationMethod | Email |
| #microsoft.graph.externalAuthenticationMethod | External Authentication Method |
| #microsoft.graph.fido2AuthenticationMethod | FIDO2 |
| #microsoft.graph.hardwareOathAuthenticationMethod | Hardware OATH |
| #microsoft.graph.microsoftAuthenticatorAuthenticationMethod | Microsoft Authenticator |
| #microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod | Passwordless Microsoft Authenticator |
| #microsoft.graph.phoneAuthenticationMethod | Phone (SMS or Voice) |
| #microsoft.graph.platformCredentialAuthenticationMethod | Platform Credential |
| #microsoft.graph.qrCodePinAuthenticationMethod | QR Code PIN |
| #microsoft.graph.softwareOathAuthenticationMethod | Software OATH |
| #microsoft.graph.temporaryAccessPassAuthenticationMethod | Temporary Access Pass |
| #microsoft.graph.windowsHelloForBusinessAuthenticationMethod | Windows Hello for Business |

**Note:** Password authentication methods are excluded from this check as they are always present and don't have meaningful lastUsedDateTime values.

## How to fix

If this test fails, you should:

1. **Review the identified users and their inactive methods** - Determine if the methods are still needed
2. **Contact users** - Verify if they are aware of the registered methods and if they should be using them
3. **Remove unused methods** - If a method is no longer needed, remove it from the user's account

To remove an authentication method:

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Users** > **All users**
3. Select the user with the inactive method
4. Go to **Authentication methods**
5. Remove the unused authentication method(s)

## Learn more

- [Authentication methods in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods)
- [Manage user authentication methods](https://learn.microsoft.com/entra/identity/authentication/howto-mfa-userdevicesettings)
- [Microsoft Graph API - Authentication methods](https://learn.microsoft.com/graph/api/resources/authenticationmethods-overview)

## Related links

- [Entra admin center - Users](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers/menuId/AllUsers)
- [Entra admin center - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity)

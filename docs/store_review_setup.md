# Store review account setup

Use two real OAuth accounts. Do not add a guest login and do not commit either password to this repository.

## Accounts

| Store | Review login | App button |
| --- | --- | --- |
| Apple App Store | One dedicated Apple Account | Continue with Apple |
| Google Play | One dedicated Google Account | Continue with Google |

Both accounts must remain enabled for initial review and future update reviews. Each account must be used to sign in to the production app at least once so that its normal `User` record exists.

The two accounts act as each other's listener. The dispatcher currently keeps all registered users eligible even when their `last_active_at` value is older than seven days, so no guest or continuously active listener account is required.

## Before every submission

1. Deploy the production server and confirm `https://vtalks.net/up` returns a successful response.
2. Sign in once with the dedicated Apple review account.
3. Sign in once with the dedicated Google review account.
4. From one account, record and send a voice message.
5. From the other account, open the conversation, play the message, and send a reply.
6. Leave that conversation in place so the reviewer immediately sees working sample content.
7. Confirm that neither OAuth provider asks for an unknown recovery method or an unavailable second factor.

## App Store Connect

Select **Sign-in required** and enter the dedicated Apple review account credentials.

Suggested review notes:

> Tap "Continue with Apple" and sign in with the review account provided above. The account has full access to the production service. A sample voice conversation is already available. Open the conversation to play the existing message, then record and send a reply. No guest login, subscription, invitation code, or location restriction is required.

## Google Play Console

Open **Policy and programs → App content → Sign-in details**, then add the dedicated Google review account credentials.

Suggested access instructions:

> Tap "Continue with Google" and select "Use another account" if an account chooser appears. Sign in with the review account provided here. The account has full access to the production service. A sample voice conversation is already available. Open the conversation to play the existing message, then record and send a reply. No guest login, subscription, invitation code, or location restriction is required.

## After approval

Keep both accounts available because every app update can be reviewed again. If the seven-day production activity rule is restored later, provide a separate permanent review exception before re-enabling the commented `active_since` scope.

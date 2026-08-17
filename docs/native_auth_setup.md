# Native authentication setup

The mobile shells use plain `WKWebView` and Android `WebView`. The Rails sign-in page exposes `vtalk://sign-in` links only to the app user agents, and each app completes authentication with the provider's supported platform API.

## Google

Create the OAuth clients in the same Google Cloud project:

- A Web OAuth client. Store its client ID in `Rails.application.credentials.google.client_id`. Use the same value for the iOS `GOOGLE_SERVER_CLIENT_ID` build setting and Android `VTALK_GOOGLE_SERVER_CLIENT_ID` Gradle property.
- An iOS OAuth client for bundle ID `com.porporpor020202.vtalkios`. Put its client ID in the iOS `GOOGLE_IOS_CLIENT_ID` build setting and its reversed client ID in `REVERSED_GOOGLE_IOS_CLIENT_ID`.
- An Android OAuth client for package `com.porporpor020202.vtalkandroid` and each signing certificate SHA-1 fingerprint used to install the app.

Do not ship either app while any client ID still starts with `REPLACE_WITH`.

## Apple

- Keep the Sign in with Apple capability enabled for the iOS App ID `com.porporpor020202.vtalkios`.
- The Rails backend validates native Apple identity tokens against that bundle ID. Set `APPLE_IOS_APP_IDENTIFIER` if the production bundle ID changes.
- Android uses Apple's browser authorization flow in a Chrome Custom Tab. Keep the Apple Services ID, HTTPS callback URL, private key, key ID, and team ID in Rails credentials.

Both native token endpoints validate the issuer, audience, signature, and nonce before Rails issues a five-minute mobile session handoff token.

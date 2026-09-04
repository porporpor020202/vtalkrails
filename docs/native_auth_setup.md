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

## Browser sign-in

The web sign-in buttons POST to Rails with Turbo disabled. Rails uses a browser
authorization-code flow and creates an ordinary web session after the callback.

The Google Web OAuth client must have these authorized redirect URIs (exactly):

- `https://vtalks.net/google_oauth_sessions/callback`
- `https://www.vtalks.net/google_oauth_sessions/callback`

These were registered on 2026-09-05 for the existing `Vtalk Server` client in
project `vtalk-7951d`; the missing registrations caused `redirect_uri_mismatch`.
Rails requests `openid email profile`, then verifies Google's signed ID token.
No JavaScript origin registration is needed for this server-side flow.

Apple web sign-in uses Services ID `com.vtalk.app.signin`, not the iOS bundle ID.
Its web configuration should include each supported domain and corresponding URL:

- `https://vtalks.net/apple_oauth_sessions/callback`
- `https://www.vtalks.net/apple_oauth_sessions/callback`

On 2026-09-05, `www.vtalks.net` and its callback were added to the existing
Apple Services ID. The saved configuration retains the original `vtalks.net`
and `dev.vtalks.net` domains and callbacks. The `www` authorization request now
opens Apple's sign-in screen instead of `Invalid web redirect url`.
End-to-end Apple sign-in on `www.vtalks.net` was verified on 2026-09-05:
after the account holder authenticated, Apple returned to Rails, the existing
account's rooms appeared, and the session persisted after a page reload.

Apple returns a cross-site POST. The state, nonce, and return-location cookies use
`SameSite=None; Secure`, so browser testing must use HTTPS. A plain HTTP local
browser can discard these cookies even when controller tests succeed.

References: [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
and [Apple web configuration](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).

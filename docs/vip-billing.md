# VIP billing setup

VIP is one monthly AI-assistance subscription. Voice conversations remain free. Gifts and paid conversation unlocks are not implemented.

## Architecture

- Web: Paddle Billing checkout, billed in USD.
- iOS: StoreKit 2 auto-renewable subscription. Display StoreKit's localized price.
- Android: Google Play Billing 9.1, one monthly auto-renewing base plan without introductory offers. Display Play's localized price.
- Rails: VipSubscription is the common entitlement. Store purchase ownership is bound to users.billing_account_token, an opaque UUID, not an email.
- The native apps offer native purchases and restoration, not links to web checkout.
- The integration calls the providers directly; Pay gem is not installed. Its web-only subscription abstraction would not replace the native verification and entitlement layer.
- No live merchant accounts, store products, prices, or credentials were created by the implementation.

Run bin/rails db:migrate before deploying the new app. Production needs bin/jobs (Solid Queue) running, including the hourly RefreshVipSubscriptionsJob in config/recurring.yml. No production or development database was migrated during implementation.

## Web / Paddle

Apply for a seller account using the actual Korean company and submit the website for approval. Create an active USD monthly recurring price without a trial. Choose the dollar amount in Paddle; the code deliberately does not invent a price.

Server environment:

- PADDLE_ENVIRONMENT: sandbox initially, production after approval
- PADDLE_API_KEY: secret server API key
- PADDLE_CLIENT_TOKEN: public client-side token, same environment
- PADDLE_VIP_PRICE_ID: the monthly USD price ID (pri_...)
- PADDLE_WEBHOOK_SECRET: notification destination secret
- BILLING_PUBLIC_URL: the public HTTPS Rails origin, no path

Approve /vip as your default payment page in Paddle. Keep automatic currency conversion disabled and configure no non-USD country price overrides for USD-only web billing. Transactions explicitly request USD. The VIP page reads the configured price; checkout shows final taxes before purchase.

Configure POST https://YOUR_HOST/billing/webhooks/paddle for all subscription events. Include created, activated, updated, canceled, paused, resumed, and past_due events. The signature is checked against the untouched request body with a five-minute timestamp tolerance. Events enqueue a fresh subscription API lookup; the event's asserted status alone cannot grant access.

Checkout transactions are created server-side with the user's opaque account token in custom_data, which Paddle copies to the subscription. Checkout completion is NOT proof of access: the UI polls until the server has verified the subscription. Reopening checkout reuses an unfinished transaction. If a completed transaction hasn't synchronized, the app does not create another subscription.

The web management button creates a fresh, user-owned Paddle customer portal session. In native apps, web subscribers are directed to the subscription confirmation email for cancellation; no web upsell is included.

## Apple

Create an auto-renewable monthly subscription in App Store Connect, without introductory offers initially. Select a US/USD starting price and review the generated regional prices. Complete paid-app agreements, tax/bank details, review metadata, privacy information and subscription disclosures.

Server environment:

- APPLE_BUNDLE_ID: exact application bundle identifier
- APPLE_VIP_PRODUCT_ID: exact product ID from App Store Connect
- APPLE_IAP_ISSUER_ID: App Store Connect issuer ID
- APPLE_IAP_KEY_ID: In-App Purchase / App Store Server API key ID
- APPLE_IAP_PRIVATE_KEY: matching .p8 key content (literal or escaped newlines)
- APPLE_IAP_ENVIRONMENT: production or sandbox

Use a separate sandbox backend for TestFlight/sandbox testing. A backend verifies only its configured environment; production does not accept sandbox receipts as paid production access.

Configure App Store Server Notifications V2 at POST https://YOUR_HOST/billing/webhooks/apple. The signed notification's ES256 signature, certificate chain, Apple signing extensions, bundle and environment are checked with the bundled Apple Root CA G3. Certificate verification is offline (no OCSP request); Apple API calls independently fetch current subscription status over authenticated TLS. The certificate is from https://www.apple.com/certificateauthority/AppleRootCA-G3.cer, SHA-256 63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179.

StoreKit passes appAccountToken on purchase. Rails queries the App Store Server API and checks the returned appAccountToken, bundle, product, status, revocation and expiry. The app finishes a verified transaction only after Rails responds successfully. Restoration requires the same app account that made the purchase; no silent transfer between accounts.

## Google Play

Create the configured subscription and an active monthly auto-renewing base plan. Start without offers or free trials. Set a USD baseline and review local prices in Play Console. Upload an app to an internal test track and configure license testers; a debug APK alone cannot complete real Play billing.

Server environment:

- GOOGLE_PLAY_PACKAGE_NAME: exact Play application ID; the debug build has a .dev suffix, so test with the correct published package/backend
- GOOGLE_VIP_PRODUCT_ID: subscription product ID
- GOOGLE_VIP_BASE_PLAN_ID: monthly base plan ID
- GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: full service-account JSON with Android Publisher subscription access
- GOOGLE_RTDN_AUDIENCE: exact authenticated Pub/Sub push audience
- GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL: expected Pub/Sub push service-account email

Enable Android Publisher API and grant the service account appropriate Play Console permissions. Configure Real-time Developer Notifications through Pub/Sub to POST https://YOUR_HOST/billing/webhooks/google. Enable authenticated push. Configure the topic/publisher and service-account permissions required by Google Play/Pub/Sub.

Push OIDC tokens are verified for issuer, signature, audience and expected verified service-account email. The package name must match. Subscription/voided-purchase messages trigger an API lookup. An active/grace/canceled-but-unexpired purchase enables VIP; pending, paused, on-hold and expired purchases do not. The backend acknowledges eligible purchases only after it verifies ownership. Client claims alone never enable VIP.

## Entitlement lifecycle

Renewal cancellation keeps access until the verified paid expiry. Refund/revocation removes access when the provider reports it. Hourly reconciliation covers missed notifications and retries pending event delivery. Provider outages do not extend an expired entitlement. Already-active VIP users are not offered another purchase, but simultaneous purchases on separate devices/providers cannot be made globally atomic. Support must handle accidental cross-provider duplicate subscriptions.

Deleting an account does not cancel a store subscription. The account deletion screens warn renewing subscribers and link to management. Deleted users lose the account token and entitlements; subscriptions cannot be claimed by a newly created account with the same email. Complete subscription cancellation before deletion.

## Verification before launch

Automated tests use fake provider responses and never charge money. Before live launch, test on all three sandbox environments: purchase, restore after reinstall, same/different app account, pending payment, duplicate webhooks, renewal, cancellation, expiry, grace/on-hold, refund, and returning from checkout. Confirm that the AI endpoint returns 402 for non-VIP accounts while voice messaging remains available.

Native compilation and mocked server/browser tests are not proof that store products, account agreements, webhook permissions, or real money settlement are configured correctly. Store review approval cannot be guaranteed by this implementation.

# App Store Review response — Guideline 2.1

## App Review Information — Notes

Paste the text below into the **Notes** field after the physical-device recording is attached.

```text
Thank you for reviewing say one thing. A physical-device screen recording is attached to this App Review Information section. It begins with a fresh launch and demonstrates sign-in, the core voice-message flow, the microphone permission prompt, playback, the reporting/blocking controls, and the account-deletion entry point.

1. SCREEN RECORDING
The attached recording was captured on a physical iPhone 13 running iOS 26.6.1. It shows: launch; Continue with Google; Rooms; playing received voice messages; recording, previewing, and sending a reply; the microphone permission prompt; opening the shield icon in a conversation; the content-report form and its reason options; the separate user-blocking confirmation; and My Page > Delete Account (both destructive confirmations are cancelled so the prepared conversation and review account remain available).

2. TEST DEVICES
- iPhone 13 — iOS 26.6.1 — physical device — build 1.0 (6)

3. FUNCTIONS, AUDIENCE, PROBLEM, AND VALUE
say one thing is for people who want a low-pressure way to practice spoken English with real people. A user records one thought of up to 30 seconds. The service matches it to another registered listener, and their replies form a turn-based voice conversation. It solves the difficulty of finding frequent, short speaking practice and provides a focused human exchange without long lessons or scheduling.

4. ACCESS AND MAIN-FEATURE INSTRUCTIONS
- Tap Continue with Google.
- If an account chooser appears, tap Use another account.
- Use the review username and password entered in the fields above. Two-step verification is disabled for this dedicated account.
- The account has full production access; no invitation code, sample file, subscription, or purchase is required.
- Rooms lists voice conversations. Open a room to play its messages. When it is the account's turn, tap Reply with voice, allow microphone access, record, stop, preview, and tap Send voice.
- To start a new exchange, tap Drop a voice on Rooms.
- UGC safety: open a conversation and tap the shield icon. The in-app screen provides a report form (reason and optional details) and a separate Block user action. Reports are queued for operator safety review. Blocking ends the conversation and prevents matching in either direction.
- Account deletion: My Page > Delete Account > confirm. This permanently deletes the account and associated data. The recording cancels at the final confirmation only to keep these credentials valid for review.

5. EXTERNAL SERVICES
- Google Sign-In: optional account authentication.
- Sign in with Apple: optional account authentication.
- Apple Push Notification service (APNs): iOS reply notifications.
- vtalks.net: our production Rails backend for account management, listener matching, conversation state, and voice-message storage, backed by PostgreSQL and server-side file storage.
No AI service, payment processor, subscription system, third-party content library, or external data provider is used.

6. REGIONAL DIFFERENCES
The app functions consistently in all regions where it is available. There are no region-specific features, paid content, or content catalogs. The interface is currently in English, and voice messages are user-generated.

7. REGULATED SERVICES / PROTECTED MATERIAL
Not applicable. The app is a general English-speaking practice service, does not operate in a highly regulated industry, and does not include licensed or otherwise protected third-party media. User-generated voice content is subject to in-app reporting and blocking.

Additional disclosures: The app has no in-app purchases, subscriptions, ads, or App Tracking Transparency prompt. It does not request location, contacts, camera, or photo-library access. Microphone access is requested only when the user starts recording a voice message. Account registration occurs automatically after a successful Google or Apple sign-in.
```

## Resolution Center reply

```text
Hello App Review Team,

Thank you for the guidance. We have updated the App Review Information for version 1.0 with all requested details, including the tested physical device/OS, app purpose and target audience, access instructions, external services, regional availability, and regulated/protected-material status.

We also attached a physical-device recording captured on the latest iOS. The recording begins at app launch and demonstrates sign-in, the typical voice-message flow, microphone permission, playback, the in-app UGC report form and blocking control, and the account-deletion entry point.

The dedicated Google review account credentials are provided in the Sign-in required fields. Two-step verification is disabled and the account has full production access with no purchase, subscription, invitation code, or sample file required.

Please let us know if any additional information would be helpful.
```

## Physical-device recording checklist

Record in one continuous take on an updated physical iPhone. Enable taps only if already available; do not edit in simulator footage.

1. Start on the iPhone Home Screen, show **Settings > General > About** long enough to show `iPhone 13` and `iOS 26.6.1`, then return Home.
2. Start iOS Screen Recording and launch **say one thing**.
3. Tap **Continue with Google**, choose `alpakadev93@gmail.com`, and finish sign-in. Do not expose the password while recording; start from an already-added account chooser if possible.
4. On **Rooms**, open a prepared conversation and play the received voice message.
5. Tap **Reply with voice**. On a clean install, accept the microphone permission prompt.
6. Record a short safe sample sentence, stop, preview it, and tap **Send voice**.
7. Reopen the conversation and tap the shield icon labelled **Report or block user**.
8. Select a report reason and submit it. Show the success message.
9. Return to the safety screen and show the separate **Block user** control. Do not block the prepared partner until all required conversation footage is complete.
10. Open **My Page**, tap **Delete Account**, show the native confirmation, then tap **Cancel** so the review account remains usable.
11. Stop recording. Play the saved video once to confirm the text and audio are legible and no password, OTP, phone number, notifications, or personal information is visible.

Suggested filename: `say-one-thing-app-review-iphone13-ios26.6.1.mp4`

## Before pressing Review Update

- Update the iPhone 13 from iOS 26.5.2 to the latest public iOS release.
- Install build 1.0 (6) from TestFlight or the submitted build and complete the physical-device flow.
- Sign in once with `alpakadev93@gmail.com` so the production OAuth user exists.
- Prepare a real, playable sample conversation with a second registered account.
- Verify the Google review account can sign in from a fresh/private session without a phone prompt.
- Attach the MP4 in **App Review Information > Attachment**.
- Replace the existing one-line Notes text with the complete Notes above.
- Accept the updated Apple Developer Program License Agreement as the Account Holder.
- Save, send the Resolution Center reply, and then press **Review Update**.

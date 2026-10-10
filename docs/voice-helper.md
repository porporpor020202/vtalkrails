# Voice helper

Record up to 30 seconds, then return one English sentence, phrase or word.
The helper does not use a realtime conversation connection or store recordings
in Active Storage. Native language comes from the signed-in user's profile.

## Setup

Run `bin/rails db:migrate`. The default model is `gemini-3.5-flash-lite`. Google rejected the previous 2.5 default for new users during a live API check, so existing selections of that default are migrated too.
Open the admin page, select the model, paste its API key and save. Keys use
Active Record encryption with a dedicated key derived from the application's
`secret_key_base`. Preserve this secret when deploying or restoring a database;
changing it without a key migration makes saved keys unreadable.

Alternatively configure `GEMINI_API_KEY` in the Rails server environment,
or use encrypted Rails credentials:

```yaml
gemini:
  api_key: YOUR_KEY
openai:
  api_key: YOUR_KEY
groq:
  api_key: YOUR_KEY
```

Only Gemini is needed for the default model. OpenAI configurations require
`OPENAI_API_KEY`; Groq + Luna requires both `GROQ_API_KEY` and `OPENAI_API_KEY`.
Admin-saved keys take precedence over environment variables, which take
precedence over credentials. Blank admin fields preserve saved keys and never
echo them back to the browser. Never commit raw keys.
With the existing Kamal setup, encrypted credentials are available through
`RAILS_MASTER_KEY`. If using environment variables instead, add the necessary
variables to Kamal's secret configuration before deploying.

## Admin

Open `/admin` in a web browser, then choose **Voice helper**.
Admin pages use a separate desktop web layout and are not linked from app
settings. Requests from the iOS/Android native app user agents are forbidden.
Select **Use this model** to change the next request without restarting Rails.
The setting is shared by all users and stored in the primary database.
Key presence is displayed; it does not verify provider permissions or quotas.

The **Translation prompt** editor saves a shared prompt in the same setting.
Changes apply to the next translation request for every supported model.
`{{native_language}}` and `{{native_language_code}}` are replaced with the
signed-in user's language. The initial prompt translates speech faithfully,
removes requests such as "How do I say ... in English?", preserves single-word
inputs, and returns no explanations. The server adds the fixed JSON response
contract and displays only the `english` value. Blank prompts cannot be saved.

Monthly forecasts default to 2,000 daily users, 5 requests per user per day,
30 days, 10-second recordings and 1,341 KRW/USD. These assumptions can be edited.
They are not usage limits or actual billing data. Forecasts assume 300 input
text tokens and 30 output tokens; structured JSON, language-specific token
counts and provider thinking can increase actual cost. No automatic fallback
or retry changes the selected provider or adds a second charge.

## Providers and documentation

- Google audio: https://ai.google.dev/gemini-api/docs/audio
- Google structured output: https://ai.google.dev/gemini-api/docs/structured-output
- Google prices: https://ai.google.dev/gemini-api/docs/pricing
- OpenAI transcription: https://developers.openai.com/api/docs/guides/speech-to-text
- OpenAI Luna: https://developers.openai.com/api/docs/models/gpt-6-luna
- OpenAI prices: https://developers.openai.com/api/docs/pricing
- Groq transcription and prices: https://console.groq.com/docs/speech-to-text

Prices in `VoiceHelperSetting::MODELS` were checked on October 10, 2026.
Update this small catalog when provider prices or model availability change.
Calls are bounded HTTP requests after recording stops. There is a per-user
limit of 10 requests/minute, a 2 MB upload cap and a 30-second client recording
cap. Transcription failures, missing credentials and provider failures return
English error messages rather than sample translations.

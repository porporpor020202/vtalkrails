# Read aloud

Run `bin/rails db:migrate` and configure `/admin/text_to_speech_setting` in a web browser. The admin navigation calls this page **Read aloud**. Native app requests cannot open the admin page.

The initial model is Google Chirp 3 HD (Aoede). Google WaveNet, Neural2 and OpenAI TTS-1 / TTS-1 HD can also be selected. The OpenAI models are marked legacy: the official deprecation notice schedules their removal for January 6, 2027.

Gemini 3.8 Flash-Lite TTS and Gemini 3.8 Flash TTS are also available with separate encrypted key fields. They use AI Studio keys and the Gemini Interactions API. Their WAV output is returned with `audio/wav`; the existing player supports both WAV and MP3. No translation API key is automatically reused.

Gemini pricing is token based: estimate English text at four characters per token plus 30 style/metadata tokens, and audio at 25 tokens per second. The admin's average audio duration defaults to five seconds and can be edited. Published preview rates double January 1, 2027; the forecast applies that increase automatically. See [Gemini prices](https://ai.google.dev/gemini-api/docs/pricing) and [speech generation](https://ai.google.dev/gemini-api/docs/speech-generation).

Every model has a separate encrypted API key field. These fields do not read or change translation API keys. A blank password field preserves its saved value. Keep the application's `secret_key_base` stable so saved keys remain decryptable.

Google requires a Google Cloud project with billing and the Cloud Text-to-Speech API enabled. Configure a server API key for that API; an AI Studio Gemini key alone does not enable Cloud TTS. OpenAI models need an OpenAI API key with access to the speech endpoint.

The cost table uses paid list prices per million characters, including spaces and punctuation, sorted by estimated monthly cost. Defaults are 2,000 users, five new generations a day, 30 days, 60 characters per generation and KRW 1,341 per USD. Free allowances, taxes, retries, hosting and translation costs are excluded. Prices were checked October 10, 2026:

- [Google pricing](https://cloud.google.com/text-to-speech/pricing)
- [OpenAI TTS-1](https://developers.openai.com/api/docs/models/tts-1)
- [OpenAI TTS-1 HD](https://developers.openai.com/api/docs/models/tts-1-hd)
- [OpenAI deprecations](https://developers.openai.com/api/docs/deprecations)

Translations include a signed read-aloud token bound to the user and valid for one hour. Listen posts that token to Rails; Rails generates MP3 using the selected model and key. Raw API keys never reach the browser. The loaded MP3 is reused when replaying the same result. Closing the sheet or starting another translation stops playback and releases the audio URL.

If a browser blocks playback after the asynchronous API request, the loaded player remains visible and the user can tap Listen again or use the player's controls. No browser speech synthesis is used. Actual voice quality and iOS device playback must be checked after configuring a TTS key.

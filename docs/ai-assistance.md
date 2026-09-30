# AI conversation assistance

The room and recorder show private AI help: incoming audio transcription and native-language meaning, three reply suggestions, and native-language drafts translated into English with IPA and an approximate pronunciation guide. Pronunciation audio is explicitly labeled AI-generated. No subscription or payment checks are included.

Set OPENAI_API_KEY in the server environment or openai.api_key in Rails credentials. Never embed the key in mobile clients. Optional model settings:

- OPENAI_TEXT_MODEL (default gpt-6-luna)
- OPENAI_TRANSCRIPTION_MODEL (default gpt-transcribe)
- OPENAI_SPEECH_MODEL (default gpt-4o-mini-tts)

Run bin/rails db:migrate before starting the updated app. Run the Solid Queue worker in production (bin/jobs); development uses Rails' default async adapter. No API key means requests return a friendly 503. No actual provider requests are made by automated tests.

Requests use the signed-in session and room membership. Suggestions, drafts, and pronunciation require the current reply turn and source message. Interpretation remains available for incoming messages in active rooms. GET polling never generates new work. Audio is served through an authenticated owner-only endpoint, not a public blob URL. No generated response is sent to the partner.

Requests are deduplicated by owner, room, source message, operation, language, and draft (version 1). Failed requests may be retried. Pending work older than 15 minutes can be recovered. A conditional job claim prevents duplicate queued jobs from normally calling the provider twice; an expired worker may still complete during recovery. Provider calls have finite timeouts and no HTTP retries.

Shared Active Storage audio blobs have a single cached transcript; a row lock prevents concurrent fanout transcription. Up to six recent messages inform suggestions. This lock holds a database connection while transcription runs; size worker concurrency with the database pool. Translation and pronunciation are requested explicitly and cached. No monthly user quota is imposed.

Conversation content is untrusted prompt data, structured output is rendered with textContent, and drafts are filtered from request logs. Users are told that OpenAI processes requested content. Responses use store:false; this does not disable provider abuse-monitoring retention. Review the service privacy notice and recording consent before public rollout. Native language Other uses draft language when detectable, otherwise simple English.

Assistance records and audio are destroyed with the originating message or owner. Shared transcripts follow the lifetime of the source blob. Model instructions and API integration are isolated in app/services/ai. Changing behavior can require incrementing the request-key version to invalidate old results.

Provider output quality, actual latency, audio format compatibility, and native webview playback require live-device testing with a configured key. API fees and real requests are not simulated as successful production calls.

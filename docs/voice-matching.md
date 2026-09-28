# Voice matching

A voice drop sends one recording to at most 20 distinct eligible users. Each gets a separate room with the recording's `language_id`. That language can be either recipient preference; the tab name never affects ranking. Fewer eligible listeners means a smaller batch, with its actual count returned to the sender. No eligible listeners produces a retryable error.

## Where to change behavior

- `config/voice_matching.yml`: recipient limit, time windows, smoothing priors, load penalties, and availability defaults. Read on each selection; no schema changes are required for tuning.
- `app/services/voice_matching/candidate_query.rb`: hard exclusions (self, incomplete language setup, wrong language, blocking in either direction, active same-language conversation).
- `app/services/voice_matching/recipient_stats.rb`: batch SQL aggregation of pending conversations, deliveries, 24-hour replies, and activity hours.
- `app/services/voice_matching/recipient_selector.rb`: scoring and weighted sampling without replacement. Inject a seeded `Random` in tests.
- `app/services/voice_drop_dispatcher.rb`: idempotency, rechecking eligibility under locks, shared upload, and transactional creation. Keep ranking policy out of this file.

## Initial scoring policy

`recency = exp(-hours_since_last_activity / activity_decay_hours)`

`reply_rate = (on_time_replies + prior_successes) / (mature_deliveries + prior_successes + prior_failures)`

`weight = blend(recency) * blend(reply_rate) * blend(availability) / ((1 + pending)^pending_penalty_exponent * (1 + deliveries_last_24h / exposure_penalty_scale))`

Each blend is `floor + (1 - floor) * value`. Draw an independent uniform U for each candidate and keep the smallest `-log(1-U) / weight` keys. The selector scans eligible users in batches, retaining a bounded weighted reservoir. It does not restrict selection to the most recently active users. Reserve candidates allow replacement if eligibility changes before the transaction.

These are initial heuristics, not calibrated response probabilities or a claim of optimality. Evaluate delivered recordings answered within 24 hours before tuning. Only deliveries older than that window enter the denominator. Metrics persist after a conversation is deleted, but are removed on the associated account deletion. Pending conversation counts exclude ended conversations and cover both participant roles. The configured limit is rechecked under participant locks. Concurrent changes can produce fewer than 20 deliveries.

Browser IANA timezones are optional and validated. With little history, normal local waking hours get a mild boost; a missing timezone is neutral. With enough activity history, actual observed UTC activity hours replace the clock heuristic, supporting night-shift users without inferring geography from language. Activity is sampled at most once per five minutes and uses at most 24 aggregate rows per user; stale buckets expire according to `history_days`.

Keep window lengths, priors, scales and batch sizes positive; floors within 0..1; and recipient limits and pending limits positive integers.

## Delivery guarantees

The client creates a request UUID for each recording and keeps it on retry. `(sender_id, request_key)` is unique. Simultaneous retries return one batch, including after its rooms have been deleted. Participant locks are acquired in ID order. Block creation follows the same lock order. Language settings, active conversations and pending capacity are rechecked before creating rooms.

One validated blob is uploaded and attached to each message. The whole batch commits or rolls back together; failed or redundant uploads are purged. Room deletion destroys attachments through Active Storage's normal lifecycle; it must not explicitly purge the shared blob. Active Storage's foreign key prevents purging a blob while other attachments use it. Final attachment cleanup runs through the application's configured Active Job adapter.

The API returns `drop_id`, `recipient_count`, and the sender's language-list URL. Replies still remain one-to-one. Inbox delivery is implemented here; this code does not introduce a new push notification channel.

## Database setup

The new tables and columns are consolidated into `CreateUsers` and `CreateVoiceMessaging` for the requested clean rebuild. After intentionally resetting your development DB, seed the language rows:

```sh
bin/rails db:migrate:reset
bin/rails db:seed
```

Do not apply these rewritten initial migrations incrementally to an existing deployed database.

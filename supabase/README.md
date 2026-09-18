# CONFLUX Supabase deployment

The migrations in `migrations/` add the production application foundation,
the required onboarding fields, and the V3 conversation/Build Room foundation
without modifying the project’s unknown existing tables. They are intentionally
not auto-applied. Apply `202609180001`, `202609180002`, and then
`202609180003` in timestamp order.

Before applying it:

1. Export the live schema and check the `cf_` tables, functions, policies,
   triggers, indexes, Realtime publication, and migration history do not
   conflict with an existing production model.
2. Record profile, project, connection, and message counts before deployment.
   Migration `003` backfills a conversation per existing connection and a
   stable room slug per existing project; it does not delete application data.
3. Apply the migrations through the Supabase CLI or SQL editor using an account
   with database migration access.
4. In Supabase Auth email templates, use the `{{ .Token }}` variable in the
   Confirm signup template so the registration flow can verify the six-digit
   OTP. Keep email confirmation enabled.
5. Set the Supabase Site URL to `https://conflux.site`, and add
   `https://conflux.site/` to redirect URLs. Add `https://www.conflux.site/`
   only when that host is actively used. The application does not implement an
   auth callback route, so do not invent one.
6. Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to the
   Vercel project, then redeploy.
7. After deployment, validate the recorded counts, foreign keys, uniqueness,
   RLS as anon/member/outsider, authenticated RPC permissions, Realtime, and
   that a block removes connection and contact access.

The browser uses only the anon key. Billing webhooks, OAuth token exchange,
moderation operations, and any service-role access belong in a trusted server
or Supabase Edge Function.

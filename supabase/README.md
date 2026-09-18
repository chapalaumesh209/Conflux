# CONFLUX Supabase deployment

The migrations in `migrations/` add the production application foundation and
the required verified-profile fields without modifying the project’s unknown
existing tables. They are intentionally not auto-applied. Apply them in their
timestamp order.

Before applying it:

1. Export the live schema and check the `cf_` tables do not conflict with an
   existing production model.
2. Apply the migration through the Supabase CLI or SQL editor using an account
   with database migration access.
3. In Supabase Auth email templates, use the `{{ .Token }}` variable in the
   Confirm signup template so the registration flow can verify the six-digit
   OTP. Keep email confirmation enabled.
4. Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to the
   Vercel project, then redeploy.
5. Configure Supabase Auth redirect URLs for the deployed domain.

The browser uses only the anon key. Billing webhooks, OAuth token exchange,
moderation operations, and any service-role access belong in a trusted server
or Supabase Edge Function.

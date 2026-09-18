# CONFLUX Supabase deployment

The migration in `migrations/202609180001_conflux_production_foundation.sql`
adds the production application foundation without modifying the project’s
unknown existing tables. It is intentionally not auto-applied.

Before applying it:

1. Export the live schema and check the `cf_` tables do not conflict with an
   existing production model.
2. Apply the migration through the Supabase CLI or SQL editor using an account
   with database migration access.
3. Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to the
   Vercel project, then redeploy.
4. Configure Supabase Auth redirect URLs for the deployed domain.

The browser uses only the anon key. Billing webhooks, OAuth token exchange,
moderation operations, and any service-role access belong in a trusted server
or Supabase Edge Function.

"use client";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * Browser access is deliberately limited to the Supabase anon key. Privileged
 * operations live in RLS-protected RPCs and must never use a service-role key
 * in the browser bundle.
 */
export type ConfluxSupabaseClient = SupabaseClient<any>;

let browserClient: ConfluxSupabaseClient | undefined;

export function isSupabaseConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
}

export function getSupabaseClient(): ConfluxSupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error("CONFLUX is not connected to Supabase yet. Add the public Supabase URL and anon key to this deployment.");
  }

  browserClient ??= createClient(url, anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // OAuth uses the explicit /auth/callback route so the PKCE code exchange
      // has one clear owner and failures can be shown to the user.
      detectSessionInUrl: false,
    },
  });

  return browserClient;
}

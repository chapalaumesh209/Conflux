"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { getSupabaseClient, isSupabaseConfigured } from "../../../lib/supabase/client";

export default function AuthCallbackPage() {
  const router = useRouter();
  const [message, setMessage] = useState("Completing secure sign-in…");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!isSupabaseConfigured()) { setError("Supabase configuration is required before sign-in can finish."); return; }
    const complete = async () => {
      const parameters = new URLSearchParams(window.location.search);
      const providerError = parameters.get("error_description");
      const code = parameters.get("code");
      if (providerError) { setError(providerError); return; }
      if (!code) { setError("This sign-in link is missing its authorization code. Try again from the sign-in page."); return; }
      const supabase = getSupabaseClient();
      const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
      if (exchangeError || !data.user) { setError(exchangeError?.message ?? "We could not complete sign-in. Try again."); return; }
      if (!data.user.email) { await supabase.auth.signOut(); setError("This provider did not share a verified email address. Use email, Google, GitHub, or LinkedIn to continue."); return; }
      setMessage("Checking your builder profile…");
      const { data: profile, error: profileError } = await supabase.from("cf_profiles").select("onboarding_complete").eq("id", data.user.id).maybeSingle();
      if (profileError) { setError(profileError.message); return; }
      router.replace(profile?.onboarding_complete ? "/meet" : "/onboarding");
    };
    void complete();
  }, [router]);

  if (error) return <main className="cf-gate"><section><p className="cf-kicker">Sign-in needs attention</p><h1>We could not finish that sign-in.</h1><p>{error}</p><Link className="cf-primary" href="/login">Return to sign in</Link></section></main>;
  return <main className="cf-loading"><span className="cf-pulse" />{message}</main>;
}

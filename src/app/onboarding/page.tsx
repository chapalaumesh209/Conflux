"use client";

import { ProfileOnboarding } from "../../components/auth-forms";
import { isSupabaseConfigured } from "../../lib/supabase/client";

export default function OnboardingPage() {
  if (!isSupabaseConfigured()) return <main className="cf-loading">Supabase configuration is required before onboarding can begin.</main>;
  return <ProfileOnboarding />;
}

"use client";

import { SignInForm } from "../../components/auth-forms";
import { isSupabaseConfigured } from "../../lib/supabase/client";

export default function AuthPage() {
  if (!isSupabaseConfigured()) return <main className="cf-loading">Supabase configuration is required before sign-in can begin.</main>;
  return <SignInForm />;
}

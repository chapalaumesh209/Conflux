"use client";

import { RegisterFlow } from "../../components/auth-forms";
import { isSupabaseConfigured } from "../../lib/supabase/client";

export default function RegisterPage() {
  if (!isSupabaseConfigured()) return <main className="cf-loading">Supabase configuration is required before registration can begin.</main>;
  return <RegisterFlow />;
}

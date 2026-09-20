import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function bytes(value: string) { return new TextEncoder().encode(value); }

async function credential(username: string, secret: string) {
  const key = await crypto.subtle.importKey("raw", bytes(secret), { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, bytes(username));
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const authorization = request.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const turnUrls = (Deno.env.get("TURN_URLS") ?? "").split(",").map((value) => value.trim()).filter(Boolean);
  const turnSecret = Deno.env.get("TURN_SHARED_SECRET");
  if (!authorization || !url || !anonKey) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const supabase = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user } } = await supabase.auth.getUser();
  const { sessionId } = await request.json().catch(() => ({ sessionId: null }));
  if (!user || typeof sessionId !== "string") return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const { data: meet } = await supabase.from("cf_meet_sessions").select("id").eq("id", sessionId).maybeSingle();
  if (!meet) return new Response(JSON.stringify({ error: "Meet access required" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const iceServers: RTCIceServer[] = [{ urls: "stun:stun.l.google.com:19302" }];
  if (turnUrls.length && turnSecret) {
    const username = `${Math.floor(Date.now() / 1000) + 15 * 60}:${user.id}`;
    iceServers.push({ urls: turnUrls, username, credential: await credential(username, turnSecret) });
  }
  return new Response(JSON.stringify({ iceServers }), { headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" } });
});

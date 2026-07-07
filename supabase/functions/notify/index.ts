// IGProspect — Edge Function "notify"
// Recebe um evento do app (ex.: lead enviou contato, nova mensagem) e envia
// uma notificação push para todos os aparelhos do MESMO espaço (org),
// menos o de quem gerou o evento.
//
// Secrets necessários (Project Settings > Edge Functions > Secrets, ou via CLI):
//   VAPID_PUBLIC_KEY   (a mesma do config.js)
//   VAPID_PRIVATE_KEY  (a chave privada — NUNCA exponha no front-end)
//   VAPID_SUBJECT      (ex.: mailto:rep.jacksoncorrea@gmail.com)
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já são injetados automaticamente.

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:contato@igprospect.app";

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) return json({ error: "sem token" }, 401);

    // Cliente com o JWT do usuário só para identificar QUEM chamou.
    const asUser = createClient(SUPA_URL, SERVICE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await asUser.auth.getUser(jwt);
    if (!user) return json({ error: "não autenticado" }, 401);

    const body = await req.json().catch(() => ({}));
    const { title, body: msg, url, tag } = body;
    if (!title) return json({ error: "faltou title" }, 400);

    // Service role: ignora RLS para descobrir o org e ler as inscrições da equipe.
    const admin = createClient(SUPA_URL, SERVICE_KEY);
    const { data: prof } = await admin.from("profiles").select("org_id").eq("id", user.id).single();
    if (!prof?.org_id) return json({ error: "sem espaço" }, 400);

    const { data: subs } = await admin
      .from("push_subscriptions")
      .select("*")
      .eq("org_id", prof.org_id)
      .neq("user_id", user.id);          // não notifica quem gerou o evento

    const payload = JSON.stringify({ title, body: msg || "", url: url || "/", tag });
    const dead: string[] = [];
    let sent = 0;

    await Promise.all((subs || []).map(async (s) => {
      const sub = { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } };
      try {
        await webpush.sendNotification(sub, payload);
        sent++;
      } catch (err: any) {
        const code = (err && (err.statusCode || err.status)) || 0;
        if (code === 404 || code === 410) dead.push(s.endpoint);   // inscrição expirada
      }
    }));

    if (dead.length) await admin.from("push_subscriptions").delete().in("endpoint", dead);
    return json({ sent, removed: dead.length, total: (subs || []).length });
  } catch (e: any) {
    return json({ error: String(e?.message || e) }, 500);
  }
});

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

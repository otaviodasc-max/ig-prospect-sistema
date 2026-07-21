// IGProspect SaaS — configuração
// Chaves públicas do Supabase (a proteção real é o RLS no banco).
window.IGP_CONFIG = {
  SUPABASE_URL:      'https://guuecwrhwuzbwfetehix.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1dWVjd3Jod3V6YndmZXRlaGl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1NzA2NjAsImV4cCI6MjA5NzE0NjY2MH0.GISYZrdloR5GGezNwMUMKsdVG5E5VstnXeeAxsNqtOY',
  // Notificações push (Web Push). Chave PÚBLICA VAPID — pode ficar exposta.
  // A chave PRIVADA correspondente vai como secret na Edge Function "notify" (NÃO colocar aqui).
  VAPID_PUBLIC_KEY:  'BA1Oos8-GIpl3JxcOD5yRJt5uf9H_1LaOt7BekaTYvoIZUehfrUt5lEGZmUkxUG3KDCUB3LotlIWEg27KDQrIQQ',
  // Destino das chamadas "Agendor". Agora aponta para o CRM do HUB DO CORRETOR,
  // que responde no mesmo dialeto da API do Agendor (endpoint /api/agendor/v3).
  // O CRM já envia os cabeçalhos de CORS para *.netlify.app, então NÃO precisa
  // mais do Cloudflare Worker. O token configurado nas Configurações passa a ser
  // o token de API do CRM (Configurações → API), no formato cota_xxx.
  AGENDOR_PROXY_URL: 'https://hubcorretorconsorcio.com.br/api/agendor/v3',
  // Valor anterior (proxy do Agendor real), guardado para rollback:
  // AGENDOR_PROXY_URL: 'https://sweet-butterfly-7f2b.otaviodasc.workers.dev',
};

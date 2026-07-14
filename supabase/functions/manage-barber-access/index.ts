const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

type BarberPayload = {
  action?: "create" | "reset-password";
  displayName?: string;
  email?: string;
  password?: string;
  phone?: string;
  bio?: string;
  serviceCommission?: number;
  productCommission?: number;
  active?: boolean;
  showOnSite?: boolean;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Variavel de ambiente ausente: ${name}`);
  return value.replace(/\/$/, "");
}

async function supabaseFetch(path: string, options: RequestInit = {}) {
  const url = requiredEnv("SUPABASE_URL");
  const serviceRole = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(`${url}${path}`, {
    ...options,
    headers: {
      apikey: serviceRole,
      authorization: `Bearer ${serviceRole}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=representation",
      ...(options.headers || {})
    }
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = body?.msg || body?.message || text || path;
    throw new Error(String(message));
  }
  return body;
}

async function findBarberProfileId(displayName: string) {
  const encoded = encodeURIComponent(displayName);
  const rows = await supabaseFetch(`/rest/v1/profiles?select=id,name,role&name=eq.${encoded}&role=eq.barber&limit=1`, {
    method: "GET",
    headers: { Prefer: "return=representation" }
  });
  return rows?.[0]?.id || "";
}

async function currentUser(request: Request) {
  const auth = request.headers.get("authorization") || "";
  if (!auth.toLowerCase().startsWith("bearer ")) return null;
  const url = requiredEnv("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY") || "";
  const response = await fetch(`${url}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization: auth }
  });
  if (!response.ok) return null;
  return response.json();
}

async function assertAdmin(request: Request) {
  const user = await currentUser(request);
  if (!user?.id) throw new Error("Sessao invalida.");
  const rows = await supabaseFetch(`/rest/v1/profiles?select=id,role&id=eq.${encodeURIComponent(user.id)}&limit=1`, {
    method: "GET",
    headers: { Prefer: "return=representation" }
  });
  const role = rows?.[0]?.role;
  if (!["owner", "admin"].includes(role)) throw new Error("Apenas administradores podem criar acesso de barbeiro.");
  return user;
}

Deno.serve(async request => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ ok: false, error: "Metodo nao permitido." }, 405);

  try {
    await assertAdmin(request);
    const payload = await request.json() as BarberPayload;
    const action = payload.action || "create";
    const displayName = String(payload.displayName || "").trim();
    const email = String(payload.email || "").trim().toLowerCase();
    const password = String(payload.password || "");
    if (displayName.length < 2) throw new Error("Informe o nome de exibicao do barbeiro.");
    if (password.length < 6) throw new Error("A senha inicial precisa ter no minimo 6 caracteres.");

    let userId = "";
    if (action === "reset-password") {
      userId = await findBarberProfileId(displayName);
      if (!userId) throw new Error("Perfil de barbeiro nao encontrado. Crie o acesso primeiro.");
      await supabaseFetch(`/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: "PUT",
        body: JSON.stringify({ password, user_metadata: { name: displayName, role: "barber" } })
      });
    } else {
      if (!email.includes("@")) throw new Error("Informe um e-mail valido.");
      const created = await supabaseFetch("/auth/v1/admin/users", {
        method: "POST",
        body: JSON.stringify({
          email,
          password,
          email_confirm: true,
          user_metadata: { name: displayName, role: "barber" }
        })
      });
      userId = created?.id;
      if (!userId) throw new Error("Nao foi possivel criar o usuario no Auth.");
    }

    await supabaseFetch("/rest/v1/profiles?on_conflict=id", {
      method: "POST",
      body: JSON.stringify([{ id: userId, name: displayName, role: "barber" }])
    });

    await supabaseFetch("/rest/v1/barbers?on_conflict=display_name", {
      method: "POST",
      body: JSON.stringify([{
        full_name: displayName,
        display_name: displayName,
        phone: String(payload.phone || ""),
        email,
        bio: String(payload.bio || ""),
        service_commission: Number(payload.serviceCommission || 0),
        product_commission: Number(payload.productCommission || 0),
        active: payload.active !== false,
        show_on_site: payload.showOnSite !== false && payload.active !== false
      }])
    });

    return jsonResponse({ ok: true, action, userId, email, displayName });
  } catch (error) {
    console.error("manage-barber-access:", error);
    return jsonResponse({ ok: false, error: error instanceof Error ? error.message : "Erro inesperado." }, 400);
  }
});

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Autenticación requerida" }, 401);
    const callerClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user: caller } } = await callerClient.auth.getUser();
    if (!caller) return json({ error: "Sesión inválida" }, 401);
    const admin = createClient(url, service);
    const { data: role } = await admin.from("perfiles_web").select("rol,activo").eq("user_id", caller.id).maybeSingle();
    if (role?.rol !== "admin" || !role.activo) return json({ error: "Solo el propietario puede crear usuarios" }, 403);
    const body = await req.json();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const nombre = String(body.nombre || "").trim();
    const rol = body.rol;
    if (!email || password.length < 10 || !nombre || !["vendedor", "admin"].includes(rol)) return json({ error: "Completa nombre, correo, rol y una contraseña de 10 caracteres como mínimo" }, 400);
    const { data: created, error: createError } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { nombre } });
    if (createError || !created.user) return json({ error: createError?.message || "No se pudo crear la cuenta" }, 400);
    const { error: profileError } = await admin.from("perfiles_web").insert({ user_id: created.user.id, nombre, rol, activo: true });
    if (profileError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: `No se guardó el perfil: ${profileError.message}` }, 500);
    }
    await admin.from("auditoria_web").insert({ actor_id: caller.id, accion: "usuario_creado", entidad: "perfiles_web", entidad_id: created.user.id, detalle: { email, nombre, rol } });
    return json({ user: { id: created.user.id, email, nombre, rol } }, 201);
  } catch (error) { return json({ error: error instanceof Error ? error.message : "Error inesperado" }, 500); }
});

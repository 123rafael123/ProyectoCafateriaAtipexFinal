-- Atipax web: migration inicial de perfiles, opiniones, promociones y auditoría.
-- Ejecutar en Supabase SQL Editor del proyecto existente.
create extension if not exists pgcrypto;
create table if not exists public.perfiles_web (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  rol text not null check (rol in ('comprador','vendedor','admin')) default 'comprador',
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create table if not exists public.opiniones_web (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  nombre_publico text not null,
  puntuacion int not null check (puntuacion between 1 and 5),
  comentario text not null check (length(comentario) between 3 and 1000),
  visible boolean not null default false,
  creado_en timestamptz not null default now()
);
create table if not exists public.promociones_web (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descripcion text not null default '',
  imagen_url text,
  codigo text,
  descuento numeric(5,2),
  empieza_en timestamptz not null default now(),
  termina_en timestamptz,
  activo boolean not null default true,
  creado_por uuid references auth.users(id),
  creado_en timestamptz not null default now()
);
create table if not exists public.auditoria_web (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  accion text not null,
  entidad text not null,
  entidad_id text,
  detalle jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists auditoria_web_creado_idx on public.auditoria_web(creado_en desc);
create index if not exists opiniones_web_visible_idx on public.opiniones_web(visible, creado_en desc);
create index if not exists promociones_web_activo_idx on public.promociones_web(activo, empieza_en, termina_en);

create or replace function public.web_rol()
returns text language sql stable security definer set search_path = public
as $$ select rol from public.perfiles_web where user_id = auth.uid() and activo = true $$;
create or replace function public.web_registrar_auditoria(p_accion text,p_entidad text,p_entidad_id text default null,p_detalle jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public
as $$ begin
  if auth.uid() is null then raise exception 'Autenticación requerida'; end if;
  insert into public.auditoria_web(actor_id,accion,entidad,entidad_id,detalle)
  values(auth.uid(),left(p_accion,100),left(p_entidad,100),left(p_entidad_id,200),coalesce(p_detalle,'{}'::jsonb));
end $$;

alter table public.perfiles_web enable row level security;
alter table public.opiniones_web enable row level security;
alter table public.promociones_web enable row level security;
alter table public.auditoria_web enable row level security;
drop policy if exists perfil_leer_propio_o_admin on public.perfiles_web;
create policy perfil_leer_propio_o_admin on public.perfiles_web for select to authenticated using (user_id=auth.uid() or public.web_rol()='admin');
drop policy if exists perfil_admin_actualizar on public.perfiles_web;
create policy perfil_admin_actualizar on public.perfiles_web for update to authenticated using(public.web_rol()='admin') with check(public.web_rol()='admin');
drop policy if exists opiniones_publicas_visibles on public.opiniones_web;
create policy opiniones_publicas_visibles on public.opiniones_web for select to anon,authenticated using(visible or public.web_rol()='admin');
drop policy if exists opiniones_insertar on public.opiniones_web;
create policy opiniones_insertar on public.opiniones_web for insert to anon,authenticated with check(visible=false and user_id is not distinct from auth.uid());
drop policy if exists opiniones_admin_gestionar on public.opiniones_web;
create policy opiniones_admin_gestionar on public.opiniones_web for all to authenticated using(public.web_rol()='admin') with check(public.web_rol()='admin');
drop policy if exists promociones_publicas_activas on public.promociones_web;
create policy promociones_publicas_activas on public.promociones_web for select to anon,authenticated using(activo and empieza_en<=now() and (termina_en is null or termina_en>=now()) or public.web_rol()='admin');
drop policy if exists promociones_admin_gestionar on public.promociones_web;
create policy promociones_admin_gestionar on public.promociones_web for all to authenticated using(public.web_rol()='admin') with check(public.web_rol()='admin');
drop policy if exists auditoria_solo_admin on public.auditoria_web;
create policy auditoria_solo_admin on public.auditoria_web for select to authenticated using(public.web_rol()='admin');
drop policy if exists auditoria_insertar_propias on public.auditoria_web;
create policy auditoria_insertar_propias on public.auditoria_web for insert to authenticated with check(actor_id=auth.uid());
grant select on public.perfiles_web to authenticated;
grant update on public.perfiles_web to authenticated;
grant select,insert on public.opiniones_web to anon,authenticated;
grant update,delete on public.opiniones_web to authenticated;
grant select on public.promociones_web to anon,authenticated;
grant insert,update,delete on public.promociones_web to authenticated;
grant select,insert on public.auditoria_web to authenticated;
grant usage,select on sequence public.auditoria_web_id_seq to authenticated;
grant execute on function public.web_registrar_auditoria(text,text,text,jsonb) to authenticated;

-- Primer dueño: crear su cuenta en Authentication > Users y sustituir el correo.
-- insert into public.perfiles_web(user_id,nombre,rol)
-- select id,'Dueño Atipax','admin' from auth.users where email='TU_CORREO';

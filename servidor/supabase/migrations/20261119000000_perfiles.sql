-- Cuentas de Vacio (Matias, 2026-11-19): el apodo de cada cuenta, que es el nombre
-- que sale en la clasificacion. Se pega entero en el editor SQL de Supabase (o con
-- `supabase db push` desde servidor/). Ver servidor/LEEME.md.

-- Un perfil por cuenta. Las cuentas (correo y contrasena) las guarda Supabase en
-- auth.users: aqui solo lo nuestro. Se borra con la cuenta.
create table if not exists public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  apodo text not null,
  creado timestamptz not null default now(),
  -- Cualquier caracter (Matias), de 1 a 16, sin espacios a los lados ni caracteres
  -- de control (un salto de linea romperia la tabla del juego).
  constraint apodo_valido check (
    char_length(apodo) between 1 and 16
    and apodo = btrim(apodo)
    and apodo !~ '[[:cntrl:]]'
  )
);

-- «Matias» y «matias» son el mismo apodo (Matias): unico sin mirar mayusculas. El
-- indice es lo que lo garantiza aunque dos se registren a la vez; apodo_libre solo
-- avisa antes.
create unique index if not exists perfiles_apodo_unico on public.perfiles (lower(apodo));

-- Nadie lee ni escribe la tabla desde fuera salvo su propio perfil. La funcion de
-- la clasificacion la lee con la clave de servicio, que se salta esto.
alter table public.perfiles enable row level security;
drop policy if exists "cada uno lee su perfil" on public.perfiles;
create policy "cada uno lee su perfil" on public.perfiles
  for select to authenticated using (auth.uid() = id);

-- Permisos a mano: Supabase esta dejando de darlos solo a las tablas nuevas, y sin
-- ellos ni la clave de servicio llega. Leer y nada mas; a quien no tiene sesion, nada.
revoke all on table public.perfiles from anon, authenticated;
grant select on table public.perfiles to authenticated, service_role;

-- Al registrarse, el juego manda el apodo en los datos de la cuenta
-- (raw_user_meta_data). Este disparador crea el perfil en la misma transaccion: si
-- el apodo esta cogido o no vale, falla el registro entero y no queda una cuenta
-- sin apodo.
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.perfiles (id, apodo) values (new.id, new.raw_user_meta_data ->> 'apodo');
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil();

-- Para avisar en el formulario antes de enviar: true si nadie lo tiene (sin mirar
-- mayusculas ni los espacios de los lados). Solo dice si/no: no deja listar apodos.
create or replace function public.apodo_libre(p_apodo text) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (
    select 1 from public.perfiles where lower(apodo) = lower(btrim(p_apodo))
  );
$$;

revoke all on function public.apodo_libre(text) from public;
grant execute on function public.apodo_libre(text) to anon, authenticated;

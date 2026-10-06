-- Ejecuta este script en Supabase: SQL Editor > New query > Run

create table if not exists public.resultados_examen (
  id              uuid primary key,
  examen          text        not null,
  nombre          text        not null,
  matricula       text        not null,
  grupo           text,
  aciertos        int         not null check (aciertos >= 0),
  total_preguntas int         not null,
  calificacion    numeric(5,2) not null check (calificacion between 0 and 100),
  motivo_fin      text        not null check (motivo_fin in ('manual','tiempo','violaciones')),
  num_faltas      int         not null default 0,
  faltas          jsonb       not null default '[]'::jsonb,
  respuestas      jsonb       not null default '[]'::jsonb,
  detalle_temas   jsonb,
  inicio          timestamptz,
  fin             timestamptz,
  duracion_seg    int,
  user_agent      text,
  created_at      timestamptz not null default now()
);

create index if not exists resultados_examen_matricula_idx on public.resultados_examen (examen, matricula);

-- Seguridad: los alumnos (rol anon) solo pueden INSERTAR. No pueden leer, editar ni borrar.
alter table public.resultados_examen enable row level security;

drop policy if exists "alumnos pueden insertar" on public.resultados_examen;
create policy "alumnos pueden insertar"
  on public.resultados_examen
  for insert
  to anon
  with check (true);

-- El docente consulta los resultados desde Table Editor / SQL Editor del panel de Supabase
-- (ahí se usa el rol de administrador, que no depende de estas políticas). Ejemplo:
-- select nombre, matricula, grupo, aciertos, calificacion, motivo_fin, num_faltas, duracion_seg
-- from public.resultados_examen
-- where examen = 'GAD-2401-U1-2.1.1'
-- order by created_at desc;


-- =====================================================================
-- MONITOREO CON CÁMARA  (ejecutar también en el SQL Editor)
-- =====================================================================

-- 1) Eventos de cada sesión: inicio, latidos, fotos, faltas, cámara, fin.
create table if not exists public.monitoreo_eventos (
  id           bigint generated always as identity primary key,
  sesion_id    uuid        not null,
  examen       text        not null,
  nombre       text        not null,
  matricula    text        not null,
  grupo        text,
  tipo         text        not null check (tipo in ('inicio','latido','captura','falta','camara_off','camara_on','fin')),
  contestadas  int,
  faltas       int,
  restante_seg int,
  detalle      jsonb       not null default '{}'::jsonb,
  storage_path text,
  created_at   timestamptz not null default now()
);
create index if not exists monitoreo_eventos_examen_idx on public.monitoreo_eventos (examen, created_at desc);
create index if not exists monitoreo_eventos_sesion_idx on public.monitoreo_eventos (sesion_id, created_at);

alter table public.monitoreo_eventos enable row level security;

drop policy if exists "alumnos insertan eventos" on public.monitoreo_eventos;
create policy "alumnos insertan eventos" on public.monitoreo_eventos
  for insert to anon with check (true);

-- Solo el docente (usuario autenticado) puede leer.
drop policy if exists "docente lee eventos" on public.monitoreo_eventos;
create policy "docente lee eventos" on public.monitoreo_eventos
  for select to authenticated using (true);

drop policy if exists "docente lee resultados" on public.resultados_examen;
create policy "docente lee resultados" on public.resultados_examen
  for select to authenticated using (true);

-- 2) Tiempo real para el panel del docente.
alter publication supabase_realtime add table public.monitoreo_eventos;

-- 3) Bucket PRIVADO para las fotos. Alumnos: solo subir. Docente: ver y borrar.
insert into storage.buckets (id, name, public)
values ('capturas-examen', 'capturas-examen', false)
on conflict (id) do nothing;

drop policy if exists "alumnos suben capturas" on storage.objects;
create policy "alumnos suben capturas" on storage.objects
  for insert to anon with check (bucket_id = 'capturas-examen');

drop policy if exists "docente ve capturas" on storage.objects;
create policy "docente ve capturas" on storage.objects
  for select to authenticated using (bucket_id = 'capturas-examen');

drop policy if exists "docente borra capturas" on storage.objects;
create policy "docente borra capturas" on storage.objects
  for delete to authenticated using (bucket_id = 'capturas-examen');

-- Importante: crea tu usuario docente en Authentication > Users y desactiva
-- "Allow new users to sign up" en Authentication > Providers > Email,
-- porque cualquier usuario autenticado puede ver las fotos.

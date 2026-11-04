-- =====================================================================
-- Naritva Patient Experience — Supabase schema
-- DPDP posture: no patient name, no phone, no patient ID, no exact
-- timestamp stored. A response cannot be traced back to one patient
-- from this database alone.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STAFF (the duty roster pool). Admin/IT maintains this list.
-- ---------------------------------------------------------------------
create table staff (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  role         text not null check (role in
                 ('doctor','medical_officer','nurse_sister','nurse_brother',
                  'reception','pro','housekeeping','pharmacy','lab')),
  dept         text,                      -- Gynaecology, Obstetrics, Paediatrics, ...
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- DUTY ROSTER. Admin sets this each morning; it decides which name
-- chips the patient sees. One row per staff member per day per shift.
-- ---------------------------------------------------------------------
create table duty_roster (
  id           uuid primary key default gen_random_uuid(),
  duty_date    date not null,
  staff_id     uuid not null references staff(id) on delete cascade,
  shift        text not null check (shift in ('day','night','full')),
  journey      text check (journey in ('opd','ipd','baby')),  -- null = all
  unique (duty_date, staff_id, shift)
);
create index on duty_roster (duty_date);

-- ---------------------------------------------------------------------
-- RESPONSE. One submitted feedback form.
-- week_start + shift only (no exact time) so a row can't be matched to
-- one patient by cross-referencing the hospital's own admission list.
-- ---------------------------------------------------------------------
create table response (
  id                uuid primary key default gen_random_uuid(),
  week_start        date not null,          -- Monday of that week
  journey           text not null check (journey in ('opd','ipd','baby')),
  shift             text not null check (shift in ('day','night')),
  language          text not null check (language in ('gu','hi','en')),

  doctor_id         uuid references staff(id),
  doctor_strengths  text[] not null default '{}',   -- explained, listened, ...
  doctor_wishes     text[] not null default '{}',   -- more_time, more_explain
  doctor_score      smallint not null default 0,    -- count of strengths, 0-4

  positives         text[] not null default '{}',   -- row ids answered 'great'
  would_recommend   text check (would_recommend in ('definitely','maybe','not_yet')),
  tier              smallint not null check (tier between 1 and 3),
  tier_reasons      text[] not null default '{}',
  health_flag       boolean not null default false,

  review_posted     boolean not null default false, -- did they open Google
  created_at        timestamptz not null default now()
);
create index on response (week_start);
create index on response (doctor_id);
create index on response (tier);

-- ---------------------------------------------------------------------
-- ISSUE. One row per negative chip. This is what drives the heatmap.
-- ---------------------------------------------------------------------
create table issue (
  id            uuid primary key default gen_random_uuid(),
  response_id   uuid not null references response(id) on delete cascade,
  area          text not null,   -- pharmacy, nurse_night, billing, safety, ...
  reason        text,            -- queue, slow_bell, tpa, ... (null = no chip)
  severity      char(1) not null check (severity in ('O','S','C')),
  created_at    timestamptz not null default now()
);
create index on issue (area);
create index on issue (severity);

-- ---------------------------------------------------------------------
-- STAFF SHOUT-OUT. Only names the patient actually tapped.
-- Never the whole shift.
-- ---------------------------------------------------------------------
create table shoutout (
  response_id  uuid not null references response(id) on delete cascade,
  staff_id     uuid not null references staff(id) on delete cascade,
  primary key (response_id, staff_id)
);

-- ---------------------------------------------------------------------
-- TICKET. Tier 2 / Tier 3 service recovery.
-- note_text is free text the patient typed: it CAN identify someone, so
-- it is purged by the job at the bottom of this file once resolved.
-- ---------------------------------------------------------------------
create table ticket (
  id            uuid primary key default gen_random_uuid(),
  ref           text not null unique,            -- NRT-261104-300
  response_id   uuid not null references response(id) on delete cascade,
  tier          smallint not null check (tier in (2,3)),
  routed_to     text not null,                   -- 'PRO + MS', 'Dept head'
  status        text not null default 'open'
                  check (status in ('open','in_progress','resolved','closed')),
  due_at        timestamptz not null,            -- +2h tier 3, +48h tier 2
  note_text     text,                            -- purge after resolution
  resolution    text,
  resolved_by   uuid references staff(id),
  resolved_at   timestamptz,
  patient_confirmed boolean,                     -- "did we make it right?"
  created_at    timestamptz not null default now()
);
create index on ticket (status);
create index on ticket (due_at);

-- ---------------------------------------------------------------------
-- DASHBOARD USER. Role decides what they can see.
-- ---------------------------------------------------------------------
create table dash_user (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('director','pro','doctor','admin')),
  staff_id   uuid references staff(id),  -- set for role 'doctor'
  created_at timestamptz not null default now()
);

-- =====================================================================
-- ROW LEVEL SECURITY
-- Patients submit anonymously; nobody reads without a dashboard login.
-- A doctor sees only their own responses.
-- =====================================================================
alter table response  enable row level security;
alter table issue     enable row level security;
alter table shoutout  enable row level security;
alter table ticket    enable row level security;
alter table staff     enable row level security;
alter table duty_roster enable row level security;

-- anonymous insert only (the patient form). No select for anon.
create policy anon_submit on response for insert to anon with check (true);
create policy anon_issue  on issue    for insert to anon with check (true);
create policy anon_shout  on shoutout for insert to anon with check (true);
create policy anon_ticket on ticket   for insert to anon with check (true);

-- roster is public-read so the form can show today's name chips
create policy roster_read on duty_roster for select to anon using (duty_date = current_date);
create policy staff_read  on staff       for select to anon using (active);

create or replace function my_role() returns text language sql stable as $$
  select role from dash_user where id = auth.uid()
$$;
create or replace function my_staff_id() returns uuid language sql stable as $$
  select staff_id from dash_user where id = auth.uid()
$$;

create policy resp_read on response for select to authenticated using (
  my_role() in ('director','pro','admin')
  or (my_role() = 'doctor' and doctor_id = my_staff_id())
);
create policy issue_read on issue for select to authenticated using (
  my_role() in ('director','pro','admin')
);
create policy shout_read on shoutout for select to authenticated using (true);
-- only PRO/admin touch tickets (they hold the free-text note)
create policy ticket_rw on ticket for all to authenticated using (
  my_role() in ('pro','admin')
);

-- =====================================================================
-- RETENTION: purge free text once a ticket is closed, and after 90 days
-- regardless. Schedule with pg_cron.
--   select cron.schedule('purge-notes','0 2 * * *','select purge_notes()');
-- =====================================================================
create or replace function purge_notes() returns void language sql as $$
  update ticket set note_text = null
   where note_text is not null
     and (status = 'closed' or created_at < now() - interval '90 days');
$$;

-- ============================================================================
-- Naritva Women's Medical Studio — Patient Experience & Grievance Schema
-- Database: Supabase (PostgreSQL)
-- ============================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. PATIENT REVIEWS & PX ANALYTICS
create table if not exists public.patient_reviews (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  journey text not null check (journey in ('OPD', 'IPD', 'BABY')),
  language text not null check (language in ('gu', 'hi', 'en')),
  doctor_name text,
  doctor_dept text,
  doctor_score text, -- e.g. "3 / 4"
  sister_recommend text check (sister_recommend in ('definitely', 'maybe', 'not_yet', null)),
  tier int not null check (tier in (1, 2, 3)),
  constructive_tags text[] default '{}',
  staff_appreciated text[] default '{}',
  generated_draft text,
  ticket_ref text
);

-- Index for analytics & director dashboards
create index if not exists idx_reviews_date on public.patient_reviews (created_at desc);
create index if not exists idx_reviews_journey on public.patient_reviews (journey);
create index if not exists idx_reviews_tier on public.patient_reviews (tier);
create index if not exists idx_reviews_doctor on public.patient_reviews (doctor_name);

-- 2. GRIEVANCE TICKETS (TIER 2 & 3 INCIDENT RESOLUTION)
create table if not exists public.grievance_tickets (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  ticket_ref text unique not null, -- e.g. "NRT-261104-273"
  tier int not null check (tier in (2, 3)),
  journey text not null check (journey in ('OPD', 'IPD', 'BABY')),
  areas text[] default '{}',
  reasons text[] default '{}',
  status text not null default 'open' check (status in ('open', 'contacted', 'resolved', 'escalated')),
  assigned_to text not null default 'Patient Relations Officer',
  patient_phone text,
  resolution_notes text,
  resolved_at timestamptz
);

create index if not exists idx_tickets_status on public.grievance_tickets (status);
create index if not exists idx_tickets_ref on public.grievance_tickets (ticket_ref);

-- 3. DAILY ON-DUTY STAFF ROSTER (SHIFT MANAGEMENT)
create table if not exists public.daily_roster (
  id uuid primary key default gen_random_uuid(),
  roster_date date not null default current_date unique,
  opd_doctors jsonb not null default '[]'::jsonb,
  peds_doctors jsonb not null default '[]'::jsonb,
  ipd_doctors jsonb not null default '[]'::jsonb,
  nurses_day jsonb not null default '[]'::jsonb,
  nurses_night jsonb not null default '[]'::jsonb,
  reception jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- Enable Row Level Security (RLS)
alter table public.patient_reviews enable row level security;
alter table public.grievance_tickets enable row level security;
alter table public.daily_roster enable row level security;

-- Public can submit reviews (INSERT)
create policy "Allow public review submissions" 
  on public.patient_reviews for insert 
  with check (true);

-- Public can read active daily roster (SELECT)
create policy "Allow public roster read" 
  on public.daily_roster for select 
  using (true);

-- Public can insert grievance tickets (INSERT)
create policy "Allow public grievance creation" 
  on public.grievance_tickets for insert 
  with check (true);

-- Hospital Staff / Authenticated users have full access
create policy "Allow staff full access to reviews" 
  on public.patient_reviews for all 
  using (auth.role() = 'authenticated');

create policy "Allow staff full access to tickets" 
  on public.grievance_tickets for all 
  using (auth.role() = 'authenticated');

create policy "Allow staff full access to roster" 
  on public.daily_roster for all 
  using (auth.role() = 'authenticated');

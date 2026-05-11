-- Supabase Schema für Kalender-App
-- Ausführen in: supabase.com → Dein Projekt → SQL Editor → New Query

-- Anonymous Auth aktivieren:
-- Authentication → Providers → Anonymous → Enable

-- Tabellen erstellen:

create table if not exists calendar_events (
  id text primary key,
  user_id text not null,
  data jsonb not null
);
create index if not exists idx_events_user on calendar_events(user_id);

create table if not exists todos (
  id text primary key,
  user_id text not null,
  data jsonb not null
);
create index if not exists idx_todos_user on todos(user_id);

create table if not exists week_notes (
  week_key text not null,
  user_id text not null,
  data jsonb not null,
  primary key (week_key, user_id)
);

create table if not exists series_reminders (
  id text primary key,
  user_id text not null,
  data jsonb not null
);
create index if not exists idx_reminders_user on series_reminders(user_id);

create table if not exists yearly_checklists (
  id text primary key,
  user_id text not null,
  data jsonb not null
);
create index if not exists idx_checklists_user on yearly_checklists(user_id);

-- Row Level Security (nur eigene Daten sichtbar):
alter table calendar_events enable row level security;
alter table todos enable row level security;
alter table week_notes enable row level security;
alter table series_reminders enable row level security;
alter table yearly_checklists enable row level security;

create policy "Eigene Events" on calendar_events for all using (auth.uid()::text = user_id);
create policy "Eigene Todos" on todos for all using (auth.uid()::text = user_id);
create policy "Eigene Notizen" on week_notes for all using (auth.uid()::text = user_id);
create policy "Eigene Erinnerungen" on series_reminders for all using (auth.uid()::text = user_id);
create policy "Eigene Jahresaufgaben" on yearly_checklists for all using (auth.uid()::text = user_id);

-- Realtime aktivieren:
alter publication supabase_realtime add table calendar_events;
alter publication supabase_realtime add table todos;
alter publication supabase_realtime add table series_reminders;
alter publication supabase_realtime add table yearly_checklists;

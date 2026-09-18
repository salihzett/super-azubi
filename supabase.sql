-- Super Azubi – Bestenliste, serverseitig validiert. Im Supabase SQL Editor komplett ausführen (idempotent).
-- Prinzip: der Browser darf nichts direkt in "scores" schreiben. Er holt beim Start ein Ticket (start_game)
-- und meldet am Ende nur Zählwerte (submit_score). Punkte rechnet die Datenbank selbst.

create table if not exists scores (
  id bigint generated always as identity primary key,
  name text not null,
  score int not null,
  time int not null,
  win boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists game_sessions (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  used boolean not null default false
);

alter table scores enable row level security;
alter table game_sessions enable row level security;
drop policy if exists "anyone can read" on scores;
drop policy if exists "anyone can insert" on scores;
create policy "anyone can read" on scores for select using (true);
-- KEINE insert/update/delete-Policy für anon: schreiben geht nur über die Funktionen unten.

-- Aufräumen: alte Fake-Einträge
delete from scores where score > 40000 or name in ('HACKERMAN', 'MEISTER', 'TEST');

-- Ticket beim Spielstart. Rate-Limit: max. 20 neue Spiele pro Minute insgesamt.
create or replace function start_game() returns uuid
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if (select count(*) from game_sessions where started_at > now() - interval '1 minute') >= 20 then
    raise exception 'rate limit';
  end if;
  delete from game_sessions where started_at < now() - interval '2 hours';
  insert into game_sessions default values returning id into sid;
  return sid;
end $$;

-- Ergebnis melden. Punkte werden hier berechnet, nicht im Browser.
-- Obergrenzen = was in beiden Leveln existiert (82 Kaffee, 57 Gegner, 4 Riegel, 5 Boss-Treffer).
create or replace function submit_score(
  session uuid, p_name text, coffee int, enemies int, choc int, boss_hits int, levels int, p_time int, p_win boolean
) returns int
language plpgsql security definer set search_path = public as $$
declare s game_sessions%rowtype; total int; elapsed int; min_time int;
begin
  select * into s from game_sessions where id = session for update;
  if s.id is null or s.used then raise exception 'invalid session'; end if;
  elapsed := extract(epoch from now() - s.started_at)::int;
  if p_time < 1 or p_time > 3600 or p_time > elapsed + 5 then raise exception 'implausible time'; end if;
  if p_name !~ '^[A-ZÄÖÜ0-9 _.\-]{1,12}$' then raise exception 'bad name'; end if;
  if coffee < 0 or coffee > 82 or enemies < 0 or enemies > 57 or choc < 0 or choc > 4
     or boss_hits < 0 or boss_hits > 5 or levels < 0 or levels > 2 then raise exception 'implausible counts'; end if;
  -- Mindestzeit: Level 1 dauert mindestens ~45 s, beide Level ~90 s (Laufweg / Geschwindigkeit)
  min_time := case when p_win then 90 when levels >= 1 then 45 else 0 end;
  if p_time < min_time then raise exception 'too fast'; end if;
  if p_win and (levels < 1 or boss_hits < 5) then raise exception 'win without finishing'; end if;
  total := coffee * 100 + enemies * 200 + choc * 500 + boss_hits * 1000
         + case when boss_hits >= 5 then 3000 else 0 end
         + case when levels >= 1 then 1000 else 0 end
         + case when p_win then greatest(0, 600 - p_time) * 10 else 0 end;
  update game_sessions set used = true where id = session;
  insert into scores (name, score, time, win) values (p_name, total, p_time, p_win);
  return total;
end $$;

revoke all on function start_game() from public;
revoke all on function submit_score(uuid, text, int, int, int, int, int, int, boolean) from public;
grant execute on function start_game() to anon, authenticated;
grant execute on function submit_score(uuid, text, int, int, int, int, int, int, boolean) to anon, authenticated;

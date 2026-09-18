-- Super Azubi – Bestenliste. Im Supabase SQL Editor ausführen (idempotent).
-- Der anon-Key ist öffentlich; diese Regeln begrenzen, was damit eingetragen werden kann.

create table if not exists scores (
  id bigint generated always as identity primary key,
  name text not null,
  score int not null,
  time int not null,
  win boolean not null default false,
  created_at timestamptz not null default now()
);

alter table scores enable row level security;
drop policy if exists "anyone can read" on scores;
drop policy if exists "anyone can insert" on scores;
create policy "anyone can read"   on scores for select using (true);
create policy "anyone can insert" on scores for insert with check (true);
-- kein update/delete für anon: keine Policy = verboten

-- Plausibilität: Maximal erreichbar sind ~36.600 Punkte (alle Kaffees, alle Gegner, Boss, Bonus).
alter table scores drop constraint if exists scores_name_check;
alter table scores drop constraint if exists scores_score_check;
alter table scores drop constraint if exists scores_time_check;
alter table scores add constraint scores_name_check  check (name ~ '^[A-ZÄÖÜ0-9 _.\-]{1,12}$');
alter table scores add constraint scores_score_check check (score between 0 and 40000 and score % 10 = 0);
alter table scores add constraint scores_time_check  check (time between 1 and 3600 and (not win or time >= 60));

-- Rate-Limit: max. 5 Einträge pro 30 Sekunden insgesamt (bremst Skript-Spam).
create or replace function scores_rate_limit() returns trigger language plpgsql as $$
begin
  if (select count(*) from scores where created_at > now() - interval '30 seconds') >= 5 then
    raise exception 'rate limit';
  end if;
  return new;
end $$;
drop trigger if exists scores_rate_limit on scores;
create trigger scores_rate_limit before insert on scores for each row execute function scores_rate_limit();

-- Nur Top-Liste lesbar machen, nicht die ganze Tabelle (optional, verhindert Auslesen aller Einträge):
-- create view top_scores as select name, score, time, win from scores order by score desc, time asc limit 10;

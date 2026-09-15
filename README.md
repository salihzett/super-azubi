# Super Azubi

HTML5 Jump'n'Run. Ein IT-Azubi muss durch die Adlon-Lobby bis zum Aufzug – vorbei an
Kollegen, Gästen und Herrn Pfefferkorn („Ich hab mein Passwort vergessen!“).

`index.html` im Browser öffnen, fertig. Keine Abhängigkeiten.

**Steuerung:** Pfeile/WASD + Leertaste (Sprung), `V` = Boss verwirren, `ESC` = Titel,
`L` = Sprache (Titel). Touch-Buttons auf dem Handy.

## Level bauen
`PLACE` in `index.html` – Einträge `[Zeichen, Spalte, Zeile=9, Anzahl=1]`.
`K` Koffer, `W` Wagen, `C` PC, `N` Kabel, `S` Switch, `T` Telefon, `=` Tresen, `-` Galerie-Sims
(nur von oben fest), `~` Brunnen (tödlich), `o` Kaffee, `k` Schlüsselkarte (+1 Leben), `e` Kollege/in, `g` Gast.

## Sprites
`assets/*_sheet.png` = KI-generierte Sheets (Magenta-Hintergrund), `assets/split.py` schneidet sie in
Streifen (`python3 assets/split.py sheet.png out.png <idle-höhe> <frames>`). Streifen werden als Base64
in `index.html` eingebettet.

## Gemeinsame Bestenliste (Supabase)
Ohne Konfiguration speichert das Spiel die Bestenliste nur im Browser (`localStorage`).
Für eine geteilte Liste:

1. Auf https://supabase.com ein kostenloses Projekt anlegen.
2. SQL Editor → folgendes ausführen:

```sql
create table scores (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 12),
  score int not null check (score between 0 and 200000),
  time int not null check (time between 0 and 36000),
  win boolean not null default false,
  created_at timestamptz default now()
);
alter table scores enable row level security;
create policy "anyone can read" on scores for select using (true);
create policy "anyone can insert" on scores for insert with check (true);
```

3. Project Settings → API: **Project URL** und **anon public key** kopieren.
4. In `index.html` eintragen:

```js
const SUPABASE = { url: 'https://xxxx.supabase.co', key: 'eyJ…' };
```

Der anon-Key ist öffentlich gedacht; die Policies erlauben nur Lesen und Einfügen, kein Löschen/Ändern.

## GitHub Pages
1. Repo auf GitHub pushen (Branch `main`).
2. Repo → Settings → Pages → Source: „Deploy from a branch“, Branch `main`, Ordner `/ (root)` → Save.
3. Nach ~1 Minute: `https://<user>.github.io/<repo>/`.

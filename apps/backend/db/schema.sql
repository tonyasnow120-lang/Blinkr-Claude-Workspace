-- ============================================================
-- Blinkr Database Setup — paste this entire file into
-- Supabase SQL Editor and click "Run"
-- ============================================================

-- 1. CREATE TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.users (
  id          uuid PRIMARY KEY,
  username    text UNIQUE NOT NULL,
  display_name text,
  avatar_url  text,
  fcm_token   text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  url         text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_photos_user_id_idx ON public.user_photos(user_id);

CREATE TABLE IF NOT EXISTS public.user_stats (
  user_id         uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  wins            integer NOT NULL DEFAULT 0,
  losses          integer NOT NULL DEFAULT 0,
  current_streak  integer NOT NULL DEFAULT 0,
  longest_streak  integer NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.challenges (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          char(9) UNIQUE NOT NULL,
  challenger_id uuid NOT NULL REFERENCES public.users(id),
  opponent_id   uuid REFERENCES public.users(id),
  status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','accepted','expired','cancelled')),
  expires_at    timestamptz NOT NULL,
  used_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS challenges_code_idx        ON public.challenges(code);
CREATE INDEX IF NOT EXISTS challenges_challenger_idx  ON public.challenges(challenger_id);

CREATE TABLE IF NOT EXISTS public.matches (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id      uuid NOT NULL REFERENCES public.challenges(id),
  player_one_id     uuid NOT NULL REFERENCES public.users(id),
  player_two_id     uuid NOT NULL REFERENCES public.users(id),
  winner_id         uuid REFERENCES public.users(id),
  loser_id          uuid REFERENCES public.users(id),
  livekit_room_name text NOT NULL,
  status            text NOT NULL DEFAULT 'waiting'
                      CHECK (status IN ('waiting','countdown','live','adjudicating','completed','abandoned')),
  started_at        timestamptz,
  ended_at          timestamptz,
  duration_ms       integer,
  result_reason     text CHECK (result_reason IN ('blink','gaze_break','disconnect','simultaneous')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS matches_player_one_idx ON public.matches(player_one_id);
CREATE INDEX IF NOT EXISTS matches_player_two_idx ON public.matches(player_two_id);
CREATE INDEX IF NOT EXISTS matches_challenge_idx  ON public.matches(challenge_id);

CREATE TABLE IF NOT EXISTS public.blink_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id    uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  player_id   uuid NOT NULL REFERENCES public.users(id),
  detected_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  ear_value   numeric(5,4) NOT NULL,
  event_type  text NOT NULL CHECK (event_type IN ('blink','gaze_break'))
);

CREATE INDEX IF NOT EXISTS blink_events_match_idx ON public.blink_events(match_id);

-- 2. ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_photos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blink_events ENABLE ROW LEVEL SECURITY;

-- 3. ROW LEVEL SECURITY POLICIES
-- ============================================================
-- Drop existing policies first so this script is safe to re-run

DROP POLICY IF EXISTS "users_select"        ON public.users;
DROP POLICY IF EXISTS "users_update"        ON public.users;
DROP POLICY IF EXISTS "users_insert"        ON public.users;
DROP POLICY IF EXISTS "user_photos_select"  ON public.user_photos;
DROP POLICY IF EXISTS "user_photos_insert"  ON public.user_photos;
DROP POLICY IF EXISTS "user_photos_delete"  ON public.user_photos;
DROP POLICY IF EXISTS "stats_select"        ON public.user_stats;
DROP POLICY IF EXISTS "stats_insert"        ON public.user_stats;
DROP POLICY IF EXISTS "stats_update"        ON public.user_stats;
DROP POLICY IF EXISTS "challenges_select"   ON public.challenges;
DROP POLICY IF EXISTS "challenges_insert"   ON public.challenges;
DROP POLICY IF EXISTS "challenges_update"   ON public.challenges;
DROP POLICY IF EXISTS "challenges_delete"   ON public.challenges;
DROP POLICY IF EXISTS "matches_select"      ON public.matches;
DROP POLICY IF EXISTS "matches_update"      ON public.matches;
DROP POLICY IF EXISTS "matches_insert"      ON public.matches;
DROP POLICY IF EXISTS "blinks_insert"       ON public.blink_events;
DROP POLICY IF EXISTS "blinks_select"       ON public.blink_events;

-- users: anyone logged in can read profiles; only owner can update
CREATE POLICY "users_select"   ON public.users FOR SELECT USING (true);
CREATE POLICY "users_update"   ON public.users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "users_insert"   ON public.users FOR INSERT WITH CHECK (false); -- backend only

-- user_photos: anyone logged in can view a profile's collage; only the
-- owner can add/remove their own photos
CREATE POLICY "user_photos_select" ON public.user_photos FOR SELECT USING (true);
CREATE POLICY "user_photos_insert" ON public.user_photos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_photos_delete" ON public.user_photos FOR DELETE USING (auth.uid() = user_id);

-- user_stats: public read, backend writes
CREATE POLICY "stats_select"   ON public.user_stats FOR SELECT USING (true);
CREATE POLICY "stats_insert"   ON public.user_stats FOR INSERT WITH CHECK (false);
CREATE POLICY "stats_update"   ON public.user_stats FOR UPDATE USING (false);

-- challenges: only participants can see their challenges
CREATE POLICY "challenges_select" ON public.challenges FOR SELECT
  USING (auth.uid() = challenger_id OR auth.uid() = opponent_id);
CREATE POLICY "challenges_insert" ON public.challenges FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);
CREATE POLICY "challenges_update" ON public.challenges FOR UPDATE
  USING (auth.uid() = challenger_id);
CREATE POLICY "challenges_delete" ON public.challenges FOR DELETE
  USING (auth.uid() = challenger_id);

-- matches: only the two players can see their match
CREATE POLICY "matches_select" ON public.matches FOR SELECT
  USING (auth.uid() = player_one_id OR auth.uid() = player_two_id);
CREATE POLICY "matches_update" ON public.matches FOR UPDATE
  USING (auth.uid() = player_one_id OR auth.uid() = player_two_id);
CREATE POLICY "matches_insert" ON public.matches FOR INSERT WITH CHECK (false);

-- blink_events: players can insert their own; both players can read
CREATE POLICY "blinks_insert" ON public.blink_events FOR INSERT
  WITH CHECK (auth.uid() = player_id);
CREATE POLICY "blinks_select" ON public.blink_events FOR SELECT
  USING (
    auth.uid() IN (
      SELECT player_one_id FROM public.matches WHERE id = match_id
      UNION
      SELECT player_two_id FROM public.matches WHERE id = match_id
    )
  );

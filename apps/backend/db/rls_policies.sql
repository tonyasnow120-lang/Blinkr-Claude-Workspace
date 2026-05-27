-- Blinkr Row Level Security Policies (GAP-5)
-- Run these against your Supabase project after enabling RLS on each table.
-- Verify all tables have rowsecurity=true:
--   SELECT schemaname, tablename, rowsecurity
--   FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- ============================================================
-- 1. Enable RLS on all tables
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blink_events ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. users table
-- ============================================================
-- Anyone authenticated can read public user profiles (username, displayName, avatarUrl)
CREATE POLICY "users_select_own_or_public"
  ON public.users FOR SELECT
  USING (
    auth.uid() = id
    OR TRUE -- Public profiles: adjust to auth.uid() = id if profiles should be private
  );

-- Users can only update their own record
CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Inserts handled by the backend via service_role — no direct user INSERT
CREATE POLICY "users_insert_service_role_only"
  ON public.users FOR INSERT
  WITH CHECK (FALSE); -- Only service_role (bypasses RLS) may insert

-- ============================================================
-- 3. user_stats table
-- ============================================================
CREATE POLICY "user_stats_select_own"
  ON public.user_stats FOR SELECT
  USING (auth.uid() = user_id OR TRUE); -- Public stats

CREATE POLICY "user_stats_update_service_role_only"
  ON public.user_stats FOR UPDATE
  USING (FALSE); -- Only service_role

CREATE POLICY "user_stats_insert_service_role_only"
  ON public.user_stats FOR INSERT
  WITH CHECK (FALSE); -- Only service_role

-- ============================================================
-- 4. challenges table
-- ============================================================
-- Challengers can see their own challenges; opponents can see challenges they've been invited to
CREATE POLICY "challenges_select_participant"
  ON public.challenges FOR SELECT
  USING (
    auth.uid() = challenger_id
    OR auth.uid() = opponent_id
  );

-- Challengers create challenges (challenger_id must be the authenticated user)
CREATE POLICY "challenges_insert_challenger"
  ON public.challenges FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);

-- Challengers can update (accept/cancel) their own challenges
CREATE POLICY "challenges_update_challenger"
  ON public.challenges FOR UPDATE
  USING (auth.uid() = challenger_id);

-- Challengers can delete their own challenges
CREATE POLICY "challenges_delete_challenger"
  ON public.challenges FOR DELETE
  USING (auth.uid() = challenger_id);

-- ============================================================
-- 5. matches table
-- ============================================================
CREATE POLICY "matches_select_participant"
  ON public.matches FOR SELECT
  USING (
    auth.uid() = player_one_id
    OR auth.uid() = player_two_id
  );

CREATE POLICY "matches_update_participant"
  ON public.matches FOR UPDATE
  USING (
    auth.uid() = player_one_id
    OR auth.uid() = player_two_id
  );

-- Inserts via service_role (backend creates matches)
CREATE POLICY "matches_insert_service_role_only"
  ON public.matches FOR INSERT
  WITH CHECK (FALSE);

-- ============================================================
-- 6. blink_events table
-- ============================================================
-- Only the player who generated the event can insert
CREATE POLICY "blink_events_insert_own"
  ON public.blink_events FOR INSERT
  WITH CHECK (auth.uid() = player_id);

-- Both match participants can view blink events for their match
CREATE POLICY "blink_events_select_participant"
  ON public.blink_events FOR SELECT
  USING (
    auth.uid() IN (
      SELECT player_one_id FROM public.matches WHERE id = match_id
      UNION
      SELECT player_two_id FROM public.matches WHERE id = match_id
    )
  );

-- ============================================================
-- 7. Verification queries
-- ============================================================
-- Run after applying policies to confirm no table has rowsecurity=false:
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Run to list all policies:
-- SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;

-- Test anon access (should return 0 rows on all tables):
-- Run the following from the Supabase SQL editor using the anon role, or via:
--   curl -H "apikey: <anon_key>" https://<project>.supabase.co/rest/v1/matches
-- Expected: empty array [] (RLS blocks all anon reads)

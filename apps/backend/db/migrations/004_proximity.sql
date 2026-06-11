-- Matchmaking Feature 5: GPS radius matching (PostGIS).
-- Run once; requires the postgis extension to be enabled on the project
-- (Supabase Dashboard → Database → Extensions → postgis).
CREATE EXTENSION IF NOT EXISTS postgis;

-- Coordinates live in their own table so RLS can deny ALL client access:
-- clients never read locations directly — the backend (service role)
-- computes and returns distances only.
CREATE TABLE IF NOT EXISTS user_locations (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  location GEOGRAPHY(POINT, 4326),
  visible BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS user_locations_gist_idx ON user_locations USING GIST(location);

-- Deny-all for clients: RLS enabled with no policies. Only the service
-- role (backend) bypasses RLS. Never add a client-facing SELECT policy here.
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;

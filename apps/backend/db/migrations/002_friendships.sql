-- Matchmaking Feature 3: friendships.
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')) DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(requester_id, addressee_id)
);
CREATE INDEX IF NOT EXISTS friendships_addressee_status_idx ON friendships(addressee_id, status);

-- RLS: users can only see friendships they are part of. All writes go
-- through the backend (service role), which enforces the state machine.
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_friendships" ON friendships;
CREATE POLICY "own_friendships" ON friendships FOR SELECT
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

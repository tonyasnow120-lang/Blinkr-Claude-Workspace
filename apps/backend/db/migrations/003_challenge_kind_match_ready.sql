-- Matchmaking Features 1/4: challenge kind drives TTL (qr: 60s, others: 15min)
-- and pre-targeted opponents (friend/contact/proximity challenges).
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'link'
  CHECK (kind IN ('link', 'qr', 'friend', 'contact', 'proximity'));

-- Shared lobby: per-player ready flags. Countdown starts only when both true.
ALTER TABLE matches ADD COLUMN IF NOT EXISTS player_one_ready BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS player_two_ready BOOLEAN NOT NULL DEFAULT false;

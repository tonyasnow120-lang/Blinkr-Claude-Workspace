-- Matchmaking Feature 2: contact discovery columns on users.
-- phone_hash is the SHA-256 of the user's own E.164 number, computed
-- ON DEVICE — the raw number never reaches the server.
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_hash TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS allow_contact_discovery BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX IF NOT EXISTS users_phone_hash_idx ON users(phone_hash);

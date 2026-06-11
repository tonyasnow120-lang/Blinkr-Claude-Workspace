import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema.js'

const connectionString = process.env.DATABASE_URL
if (!connectionString) {
  throw new Error('DATABASE_URL environment variable is required')
}

// Exported for the startup migration runner (raw multi-statement SQL).
export const client = postgres(connectionString)
export const db = drizzle(client, { schema })
export type DrizzleDB = typeof db

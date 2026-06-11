import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import type { FastifyBaseLogger } from 'fastify'
import { client } from './index.js'

// Applies db/migrations/*.sql in filename order at startup. Every migration
// file is idempotent (IF NOT EXISTS / DROP POLICY IF EXISTS), so running
// the full set on every boot is safe. A failing file is logged and skipped
// so one unavailable feature (e.g. the postgis extension not yet enabled on
// the project) cannot take down the rest of the API.
export async function runMigrations(log: FastifyBaseLogger): Promise<void> {
  const dir = join(process.cwd(), 'db', 'migrations')

  let files: string[]
  try {
    files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort()
  } catch {
    log.warn({ dir }, 'No migrations directory found — skipping migrations')
    return
  }

  for (const file of files) {
    const sqlText = await readFile(join(dir, file), 'utf8')
    try {
      // unsafe() without params uses the simple query protocol, which
      // supports the multi-statement migration files.
      await client.unsafe(sqlText)
      log.info({ file }, 'Migration applied')
    } catch (err) {
      log.error(
        { file, reason: err instanceof Error ? err.message : String(err) },
        'Migration failed — continuing with remaining migrations',
      )
    }
  }
}

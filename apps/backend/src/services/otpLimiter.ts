// This app delegates OTP to Supabase, which has built-in rate limiting configurable
// in the Supabase dashboard (Auth → Rate Limits). This module provides an additional
// application-layer guard for any future custom OTP endpoints.
//
// PRODUCTION NOTE: Replace the in-memory Map with Redis (ioredis). The in-memory
// implementation does not survive restarts and does not scale across multiple instances.

interface OtpState {
  sendCount: number
  sendWindowStart: number
  failureCount: number
  lockedUntil: number | null
}

const store = new Map<string, OtpState>()

const SEND_MAX = 3
const SEND_WINDOW_MS = 10 * 60 * 1000   // 10-minute window
const VERIFY_MAX_FAILURES = 5
const LOCK_DURATION_MS = 30 * 60 * 1000 // 30-minute lockout

function getState(email: string): OtpState {
  return (
    store.get(email) ?? {
      sendCount: 0,
      sendWindowStart: Date.now(),
      failureCount: 0,
      lockedUntil: null,
    }
  )
}

export class RateLimitError extends Error {
  statusCode = 429
  constructor(message: string) {
    super(message)
    this.name = 'RateLimitError'
  }
}

export class LockedError extends Error {
  statusCode = 423
  constructor(message: string) {
    super(message)
    this.name = 'LockedError'
  }
}

export function checkOtpSendLimit(email: string): void {
  const state = getState(email)
  const now = Date.now()
  if (now - state.sendWindowStart > SEND_WINDOW_MS) {
    state.sendCount = 0
    state.sendWindowStart = now
  }
  if (state.sendCount >= SEND_MAX) {
    throw new RateLimitError('Too many OTP requests — please wait before requesting another code.')
  }
  state.sendCount++
  store.set(email, state)
}

export function recordOtpFailure(email: string): void {
  const state = getState(email)
  state.failureCount++
  if (state.failureCount >= VERIFY_MAX_FAILURES) {
    state.lockedUntil = Date.now() + LOCK_DURATION_MS
  }
  store.set(email, state)
}

export function checkOtpVerifyLock(email: string): void {
  const state = getState(email)
  if (state.lockedUntil != null && Date.now() < state.lockedUntil) {
    throw new LockedError('Too many failed attempts — this account is locked for 30 minutes.')
  }
}

export function clearOtpFailures(email: string): void {
  const state = getState(email)
  state.failureCount = 0
  state.lockedUntil = null
  store.set(email, state)
}

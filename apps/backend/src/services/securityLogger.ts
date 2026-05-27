import type { FastifyBaseLogger } from 'fastify'

export type SecurityEventType =
  | 'jwt_validation_failure'
  | 'otp_lockout'
  | 'otp_brute_force'
  | 'idor_attempt'
  | 'challenge_enumeration'
  | 'cors_violation'
  | 'invalid_deep_link'
  | 'jailbreak_reported'
  | 'app_attest_failure'
  | 'play_integrity_failure'
  | 'cert_pin_mismatch'
  | 'unknown_fcm_type'

export function logSecurityEvent(
  logger: FastifyBaseLogger,
  event: SecurityEventType,
  context: Record<string, unknown>,
): void {
  logger.warn({ security_event: event, ...context }, `SECURITY: ${event}`)
  // Future: forward to SIEM / alerting pipeline
}

export function maskEmail(email: string): string {
  const at = email.indexOf('@')
  if (at < 1) return '***'
  return `${email[0]}***@${email.slice(at + 1)}`
}

export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly statusCode: number = 400,
  ) {
    super(message)
    this.name = 'AppError'
  }
}

export const Errors = {
  unauthorized: () => new AppError('UNAUTHORIZED', 'Authentication required', 401),
  forbidden: () => new AppError('FORBIDDEN', 'Access denied', 403),
  notFound: (resource: string) =>
    new AppError('NOT_FOUND', `${resource} not found`, 404),
  gone: (resource: string) =>
    new AppError('GONE', `${resource} has expired`, 410),
  conflict: (message: string) => new AppError('CONFLICT', message, 409),
  validation: (message: string) => new AppError('VALIDATION_ERROR', message, 422),
  internal: () => new AppError('INTERNAL_ERROR', 'Internal server error', 500),
} as const

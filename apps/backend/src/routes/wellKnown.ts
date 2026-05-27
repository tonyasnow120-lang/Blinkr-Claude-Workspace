import type { FastifyInstance } from 'fastify'

// Digital Asset Links — Android App Links verification (GAP-9)
// PRODUCTION_TODO: replace sha256_cert_fingerprints with your release keystore SHA-256
const assetLinks = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.blinkr.app',
      sha256_cert_fingerprints: ['PRODUCTION_TODO:replace_with_release_keystore_sha256'],
    },
  },
]

// Apple App Site Association — iOS Universal Links (GAP-9)
// PRODUCTION_TODO: replace TEAM_ID with your Apple Developer Team ID
const appleAppSiteAssociation = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'PRODUCTION_TODO_TEAM_ID.com.blinkr.app',
        paths: ['/match/*', '/challenge/*'],
      },
    ],
  },
}

export async function wellKnownRoutes(app: FastifyInstance) {
  app.get('/.well-known/assetlinks.json', async (_request, reply) => {
    return reply.header('Content-Type', 'application/json').send(assetLinks)
  })

  app.get('/.well-known/apple-app-site-association', async (_request, reply) => {
    return reply.header('Content-Type', 'application/json').send(appleAppSiteAssociation)
  })
}

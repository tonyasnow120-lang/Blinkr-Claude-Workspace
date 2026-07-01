import type { FastifyInstance } from 'fastify'

// Digital Asset Links — Android App Links verification (GAP-9)
// Fingerprint is the SHA-256 of the release keystore certificate (public value,
// safe to serve). Regenerate this if the release keystore is ever rotated.
const assetLinks = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.blinkr.app',
      sha256_cert_fingerprints: [
        '34:5D:3C:88:1E:74:89:82:AF:78:9E:1F:C6:DA:FB:30:74:BA:EB:B5:A2:64:71:3B:CF:5B:44:1F:FB:83:57:3A',
      ],
    },
  },
]

// Apple App Site Association — iOS Universal Links (GAP-9)
// appID is <AppleTeamID>.<bundleId>; the Team ID is a public identifier.
const appleAppSiteAssociation = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'C76TA7LCHD.com.blinkr.app',
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

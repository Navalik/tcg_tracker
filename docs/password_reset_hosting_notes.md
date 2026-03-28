# Password Reset Hosting Notes

The custom Firebase email action handler lives in `bindervault-site/auth-action.html`.

## Goal

Serve the page as a static, isolated handler for Firebase password reset links with as little edge behavior as possible.

## Included in repo

- `bindervault-site/auth-action.html`
- `bindervault-site/auth-action.js`
- `bindervault-site/firebase-web-config.js`
- `bindervault-site/_headers`

If the site is deployed with Cloudflare Pages, `_headers` is supported by Cloudflare and can set response headers for static routes:
- https://developers.cloudflare.com/pages/configuration/headers/

## Recommended Cloudflare behavior

For `/auth-action`, `/auth-action.html`, `/auth-action.js`, and `/firebase-web-config.js`:

- bypass cache or respect `Cache-Control: no-store`
- do not apply bot challenge / managed challenge
- do not apply HTML rewriting or optimization features that alter the document
- do not add redirects based on query parameters

## Why `no-store`

Firebase email action links carry one-time Firebase action parameters in the URL. The handler page should always be fetched fresh and should not be cached at the browser or edge level.

Cloudflare documents that `no-store` prevents caching unless overridden by edge rules:
- https://developers.cloudflare.com/cache/concepts/default-cache-behavior/

## Important limitation

This repo does not currently contain Firebase Hosting config (`firebase.json`, `.firebaserc`). If deployment is not done with Cloudflare Pages, equivalent headers must be configured on the actual host.

## Firebase Browser API key

Firebase's custom email action handler documentation assumes a web handler configured with the project's web configuration.

Official docs:
- https://firebase.google.com/docs/auth/custom-email-handler

For this static handler:

1. create or reuse a Firebase Web app
2. copy the **Browser key** from the web app initialization snippet
3. place it in `bindervault-site/firebase-web-config.js`
4. deploy the site again

Do not rely on the `apiKey` query parameter if that key is restricted to Android or iOS.

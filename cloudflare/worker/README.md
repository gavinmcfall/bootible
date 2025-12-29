# Bootible Cloudflare Worker

URL shortener and landing page for bootible.

## Routes

| URL | Content | Description |
|-----|---------|-------------|
| `bootible.dev/` | Landing page | HTML for browsers, plain text for CLI |
| `bootible.dev/docs` | Documentation | README rendered as HTML |
| `bootible.dev/rog` | `targets/ally.ps1` | ROG Ally bootstrap script |
| `bootible.dev/deck` | `targets/deck.sh` | Steam Deck bootstrap script |
| `bootible.dev/logo.png` | Logo | 512x512 PNG |
| `bootible.dev/favicon.png` | Favicon | 32x32 PNG |
| `bootible.dev/steamdeck.png` | Steam Deck icon | Device icon |
| `bootible.dev/rog.png` | ROG Ally icon | Device icon |

## Development

```bash
cd cloudflare/worker
npm install
npm run dev
```

Test locally at `http://localhost:8787/`

## Deployment

1. Login to Cloudflare:
   ```bash
   npx wrangler login
   ```

2. Deploy:
   ```bash
   npm run deploy
   ```

## DNS Setup

Ensure `bootible.dev` has a CNAME or A record pointing to Cloudflare (proxied).

The worker route `bootible.dev/*` handles all requests.

# Bootible Cloudflare Worker

URL shortener for bootible bootstrap scripts.

## Routes

| URL | Script | Platform |
|-----|--------|----------|
| `bootible.dev/rog` | `targets/ally.ps1` | ROG Ally X (Windows) |
| `bootible.dev/deck` | `targets/deck.sh` | Steam Deck (SteamOS) |
| `bootible.dev/` | Help text | - |

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

/**
 * Bootible URL Shortener Worker
 *
 * Routes:
 *   /rog  -> targets/ally.ps1 (ROG Ally / Windows)
 *   /deck -> targets/deck.sh  (Steam Deck / SteamOS)
 *   /     -> Help text
 */

const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/gavinmcfall/bootible/main';

const ROUTES: Record<string, { path: string; description: string }> = {
  '/rog': {
    path: '/targets/ally.ps1',
    description: 'ROG Ally X (Windows)',
  },
  '/deck': {
    path: '/targets/deck.sh',
    description: 'Steam Deck (SteamOS)',
  },
};

// Cache scripts for 5 minutes
const CACHE_TTL = 300;

/**
 * Detect if request is from a browser (vs curl/PowerShell)
 */
function isBrowser(request: Request): boolean {
  const userAgent = request.headers.get('User-Agent') || '';
  const accept = request.headers.get('Accept') || '';

  // Browsers typically accept text/html and have Mozilla in UA
  return accept.includes('text/html') && userAgent.includes('Mozilla');
}

/**
 * Generate plain text help for CLI clients
 */
function getPlainTextHelp(): string {
  return `Bootible - One-liner setup for gaming handhelds

Usage:

  Steam Deck:
    curl -fsSL https://bootible.dev/deck | bash

  ROG Ally X:
    irm https://bootible.dev/rog | iex

More info: https://github.com/gavinmcfall/bootible
`;
}

/**
 * Generate HTML help for browser clients
 */
function getHtmlHelp(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bootible</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      max-width: 600px;
      margin: 40px auto;
      padding: 20px;
      background: #1a1a2e;
      color: #eee;
    }
    h1 { color: #00d4ff; }
    code {
      background: #16213e;
      padding: 2px 8px;
      border-radius: 4px;
      font-family: 'Fira Code', 'Consolas', monospace;
    }
    pre {
      background: #16213e;
      padding: 16px;
      border-radius: 8px;
      overflow-x: auto;
    }
    a { color: #00d4ff; }
    .device { margin: 24px 0; }
    .device h3 { color: #fff; margin-bottom: 8px; }
  </style>
</head>
<body>
  <h1>Bootible</h1>
  <p>One-liner setup for gaming handhelds and desktops.</p>

  <div class="device">
    <h3>Steam Deck</h3>
    <pre><code>curl -fsSL https://bootible.dev/deck | bash</code></pre>
  </div>

  <div class="device">
    <h3>ROG Ally X</h3>
    <pre><code>irm https://bootible.dev/rog | iex</code></pre>
  </div>

  <p>
    <a href="https://github.com/gavinmcfall/bootible">View on GitHub</a>
  </p>
</body>
</html>`;
}

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle root path - show help
    if (path === '/' || path === '') {
      if (isBrowser(request)) {
        return new Response(getHtmlHelp(), {
          headers: { 'Content-Type': 'text/html; charset=utf-8' },
        });
      }
      return new Response(getPlainTextHelp(), {
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }

    // Handle script routes
    const route = ROUTES[path];
    if (route) {
      const scriptUrl = `${GITHUB_RAW_BASE}${route.path}`;

      try {
        const response = await fetch(scriptUrl, {
          cf: {
            cacheTtl: CACHE_TTL,
            cacheEverything: true,
          },
        });

        if (!response.ok) {
          return new Response(`Failed to fetch script: ${response.status}`, {
            status: 502,
            headers: { 'Content-Type': 'text/plain' },
          });
        }

        const script = await response.text();

        return new Response(script, {
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': `public, max-age=${CACHE_TTL}`,
            'X-Bootible-Device': route.description,
          },
        });
      } catch (error) {
        return new Response(`Error fetching script: ${error}`, {
          status: 502,
          headers: { 'Content-Type': 'text/plain' },
        });
      }
    }

    // Unknown route
    return new Response('Not found. Try /rog or /deck', {
      status: 404,
      headers: { 'Content-Type': 'text/plain' },
    });
  },
};

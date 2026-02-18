/**
 * Symcon MCP Server – Dual-Transport MCP Server
 *  
 * Transport 1: StreamableHTTP (for HTTP-based clients like Symcon PHP-Module)
 * Transport 2: Stdio (for local VSCode clients)
 * 
 * Environment Variables:
 * - MCP_TRANSPORT: "streamable-http" (default), "stdio", or "both"
 * - MCP_PORT: Port for HTTP (default: 4096)
 * - SYMCON_API_URL: Symcon JSON-RPC endpoint
 * - MCP_AUTH_TOKEN: API key for authentication
 * - MCP_HTTPS: Enable HTTPS (1/true)
 * - MCP_TLS_CERT, MCP_TLS_KEY: Paths to TLS certificates
 */

import { createServer as createHttpServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { createServer as createHttpsServer } from 'node:https';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { SymconClient } from './symcon/SymconClient.js';
import { createToolHandlers } from './tools/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Read version from package.json
let PKG_VERSION = '2.0.0';
try {
  const pkgPath = join(__dirname, '..', 'package.json');
  const pkgJson = JSON.parse(readFileSync(pkgPath, 'utf8'));
  PKG_VERSION = pkgJson.version || '2.0.0';
} catch {
  // Fallback if package.json not found
}

const PORT = parseInt(process.env.MCP_PORT ?? '4096', 10);
const SYMCON_API_URL = process.env.SYMCON_API_URL ?? 'http://127.0.0.1:3777/api/';
/** Optional (für Remote-Zugriff auf http://<SymBox-IP>:3777/api/): Basic-Auth */
const SYMCON_API_USER = process.env.SYMCON_API_USER ?? '';
const SYMCON_API_PASSWORD = process.env.SYMCON_API_PASSWORD ?? '';
/** Optional: if set, requests must send Authorization: Bearer <token> or X-MCP-API-Key: <token> */
const MCP_AUTH_TOKEN = process.env.MCP_AUTH_TOKEN ?? '';
/** Bind on all interfaces (0.0.0.0) so the server is reachable at http(s)://<SymBox-IP>:PORT from your Mac/PC. */
const HOST = process.env.MCP_BIND ?? '0.0.0.0';
/** Optional HTTPS: MCP_HTTPS=1 und MCP_TLS_CERT / MCP_TLS_KEY (Pfade zu PEM), oder Zertifikate in ./certs/server.crt und ./certs/server.key */
const USE_HTTPS = process.env.MCP_HTTPS === '1' || process.env.MCP_HTTPS === 'true';
const TLS_CERT_PATH = process.env.MCP_TLS_CERT ?? join(process.cwd(), 'certs', 'server.crt');
const TLS_KEY_PATH = process.env.MCP_TLS_KEY ?? join(process.cwd(), 'certs', 'server.key');

// ============================================================================
// Debug Logging
// ============================================================================
const LOG_LEVEL = (process.env.MCP_LOG_LEVEL ?? 'info').toLowerCase();
const ENABLE_DEBUG = LOG_LEVEL === 'debug';

function debugLog(prefix: string, message: string): void {
  if (ENABLE_DEBUG) {
    process.stderr.write(`[${prefix}] ${message}\n`);
  }
}

function maskToken(token: string): string {
  if (token.length <= 8) return '(too short to mask)';
  return token.substring(0, 4) + '...' + token.substring(token.length - 4);
}

function constantTimeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  if (bufA.length === 0) return true;
  return timingSafeEqual(bufA, bufB);
}

function isAuthorized(req: IncomingMessage): boolean {
  const url = req.url ?? '(unknown)';
  const method = req.method ?? '(unknown)';

  debugLog('AUTH-DEBUG', `----------------------------------------`);
  debugLog('AUTH-DEBUG', `${method} ${url}`);
  debugLog('AUTH-DEBUG', `Content-Type: ${req.headers['content-type'] ?? '(none)'}`);
  debugLog('AUTH-DEBUG', `Accept: ${req.headers['accept'] ?? '(none)'}`);

  if (!MCP_AUTH_TOKEN) {
    debugLog('AUTH-DEBUG', `No MCP_AUTH_TOKEN configured – skipping auth`);
    return true;
  }

  debugLog('AUTH-DEBUG', `Expected token (masked): ${maskToken(MCP_AUTH_TOKEN)}`);
  debugLog('AUTH-DEBUG', `Expected token length: ${MCP_AUTH_TOKEN.length}`);

  const authHeader = req.headers.authorization;
  const apiKeyHeader = req.headers['x-mcp-api-key'];

  debugLog('AUTH-DEBUG', `Authorization header present: ${!!authHeader}`);
  debugLog('AUTH-DEBUG', `X-MCP-API-Key header present: ${!!apiKeyHeader}`);

  if (authHeader) {
    debugLog('AUTH-DEBUG', `Authorization header (masked): ${maskToken(authHeader)}`);
    debugLog('AUTH-DEBUG', `Authorization header length: ${authHeader.length}`);
  }
  if (apiKeyHeader && typeof apiKeyHeader === 'string') {
    debugLog('AUTH-DEBUG', `X-MCP-API-Key header (masked): ${maskToken(apiKeyHeader)}`);
  }

  if (ENABLE_DEBUG) {
    const safeHeaders = { ...req.headers };
    if (safeHeaders.authorization) safeHeaders.authorization = maskToken(String(safeHeaders.authorization));
    if (safeHeaders['x-mcp-api-key']) safeHeaders['x-mcp-api-key'] = maskToken(String(safeHeaders['x-mcp-api-key']));
    debugLog('AUTH-DEBUG', `All headers: ${JSON.stringify(safeHeaders, null, 2)}`);
  }

  const bearer = typeof authHeader === 'string' && authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : '';
  const key = typeof apiKeyHeader === 'string' ? apiKeyHeader.trim() : '';

  if (bearer) {
    debugLog('AUTH-DEBUG', `Extracted Bearer token length: ${bearer.length}`);
    debugLog('AUTH-DEBUG', `Extracted Bearer token (masked): ${maskToken(bearer)}`);
    const bearerMatch = constantTimeEqual(bearer, MCP_AUTH_TOKEN);
    if (bearerMatch) {
      debugLog('AUTH-DEBUG', `[OK] Bearer token VALID - request authorized`);
    } else {
      debugLog('AUTH-DEBUG', `[FAIL] Bearer token MISMATCH`);
      if (bearer.length !== MCP_AUTH_TOKEN.length) {
        debugLog('AUTH-DEBUG', `   Token length mismatch: got ${bearer.length}, expected ${MCP_AUTH_TOKEN.length}`);
      } else {
        debugLog('AUTH-DEBUG', `   First 4 chars – provided: '${bearer.substring(0, 4)}', expected: '${MCP_AUTH_TOKEN.substring(0, 4)}'`);
      }
    }
    if (bearerMatch) return true;
  } else {
    debugLog('AUTH-DEBUG', `No Bearer token extracted from Authorization header`);
  }

  if (key) {
    debugLog('AUTH-DEBUG', `Extracted X-MCP-API-Key length: ${key.length}`);
    const keyMatch = constantTimeEqual(key, MCP_AUTH_TOKEN);
    if (keyMatch) {
      debugLog('AUTH-DEBUG', `[OK] X-MCP-API-Key VALID - request authorized`);
    } else {
      debugLog('AUTH-DEBUG', `[FAIL] X-MCP-API-Key MISMATCH`);
    }
    if (keyMatch) return true;
  } else {
    debugLog('AUTH-DEBUG', `No X-MCP-API-Key token found`);
  }

  process.stderr.write(`[AUTH-WARN] [FAIL] 401 - Unauthorized request: ${method} ${url} from ${req.socket?.remoteAddress ?? 'unknown'}\n`);
  return false;
}

function readBody(req: import('node:http').IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw.trim()) {
        resolve(undefined);
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        resolve(undefined);
      }
    });
    req.on('error', reject);
  });
}

// ============================================================================
// Rate Limiting
// ============================================================================
const RATE_LIMIT = parseInt(process.env.MCP_RATE_LIMIT ?? '100', 10);
const RATE_WINDOW_MS = 60 * 1000; // 1 minute

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const rateLimitMap = new Map<string, RateLimitEntry>();

// Cleanup old entries every 60 seconds
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimitMap.entries()) {
    if (entry.resetAt < now) {
      rateLimitMap.delete(ip);
    }
  }
}, 60000);

function checkRateLimit(ip: string): { allowed: boolean; retryAfter?: number } {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);

  if (!entry || entry.resetAt < now) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return { allowed: true };
  }

  if (entry.count >= RATE_LIMIT) {
    const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
    return { allowed: false, retryAfter };
  }

  entry.count++;
  return { allowed: true };
}

async function main(): Promise<void> {
  // SECURITY: API key is now mandatory - server will not start without it
  if (!MCP_AUTH_TOKEN || MCP_AUTH_TOKEN.trim().length === 0) {
    process.stderr.write(
      '\n' +
      '╔═══════════════════════════════════════════════════════════════════════╗\n' +
      '║  FATAL ERROR: MCP_AUTH_TOKEN must be set                             ║\n' +
      '║                                                                       ║\n' +
      '║  The MCP server cannot start without authentication configured.      ║\n' +
      '║  This is a security requirement.                                     ║\n' +
      '║                                                                       ║\n' +
      '║  Please set MCP_AUTH_TOKEN in your .env file.                        ║\n' +
      '║                                                                       ║\n' +
      '║  Generate a secure token:                                            ║\n' +
      '║    openssl rand -hex 32                                              ║\n' +
      '║                                                                       ║\n' +
      '║  Or use the setup script:                                            ║\n' +
      '║    ./scripts/setup-env.sh                                            ║\n' +
      '╚═══════════════════════════════════════════════════════════════════════╝\n' +
      '\n'
    );
    process.exit(1);
  }

  if (MCP_AUTH_TOKEN.length < 16) {
    process.stderr.write(
      'WARNING: MCP_AUTH_TOKEN is too short (< 16 characters). ' +
      'For security, use at least 32 characters.\n'
    );
  }

  const symconAuth =
    SYMCON_API_USER && SYMCON_API_PASSWORD
      ? { type: 'basic' as const, username: SYMCON_API_USER, password: SYMCON_API_PASSWORD }
      : undefined;
  const client = new SymconClient(SYMCON_API_URL, 10000, symconAuth);
  const mcp = new McpServer(
    {
      name: 'symcon-mcp-server',
      version: PKG_VERSION,
    },
    {
      capabilities: {},
    }
  );

  const handlers = createToolHandlers(client);
  for (const [name, { description, inputSchema, handler }] of Object.entries(handlers)) {
    mcp.registerTool(
      name,
      {
        description,
        inputSchema,
      },
      handler as (args: unknown) => Promise<{ content: Array<{ type: 'text'; text: string }> }>
    );
  }

  const httpTransport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });
  await mcp.connect(httpTransport);

  const requestHandler = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    // ──── Global Request Debug Logging ────
    const clientIp = req.headers['x-forwarded-for']?.toString().split(',')[0].trim()
                     || req.socket.remoteAddress
                     || 'unknown';
    debugLog('MCP-REQ', `--- Incoming ${req.method} ${req.url} ---`);
    debugLog('MCP-REQ', `Remote: ${clientIp}`);
    debugLog('MCP-REQ', `User-Agent: ${req.headers['user-agent'] ?? '(none)'}`);

    // Health check endpoint (always accessible, no auth required)
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'ok',
        version: PKG_VERSION,
        authenticated: true,
        symconApi: SYMCON_API_URL,
        timestamp: new Date().toISOString()
      }));
      return;
    }

    // Rate limiting (check before auth to prevent brute force)
    const rateCheck = checkRateLimit(clientIp);
    if (!rateCheck.allowed) {
      res.writeHead(429, {
        'Content-Type': 'application/json',
        'Retry-After': String(rateCheck.retryAfter),
        'X-RateLimit-Limit': String(RATE_LIMIT),
        'X-RateLimit-Reset': String(rateCheck.retryAfter)
      });
      res.end(JSON.stringify({
        error: 'Too Many Requests',
        message: `Rate limit exceeded. Maximum ${RATE_LIMIT} requests per minute.`,
        retryAfter: rateCheck.retryAfter
      }));
      return;
    }

    if (req.method === 'POST' && !isAuthorized(req)) {
      debugLog('MCP-REQ', `[FAIL] Responding 401 Unauthorized for POST ${req.url}`);
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Unauthorized', message: 'Missing or invalid API key' }));
      return;
    }
    if (req.method === 'POST') {
      debugLog('MCP-REQ', `[OK] POST ${req.url} authorized - forwarding to transport`);
    }
    const allowedOrigins = [
      `http://127.0.0.1:${PORT}`, `http://localhost:${PORT}`,
      `https://127.0.0.1:${PORT}`, `https://localhost:${PORT}`,
    ];
    const origin = req.headers.origin;
    if (origin && !allowedOrigins.includes(origin) && HOST === '127.0.0.1') {
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Origin not allowed' }));
      return;
    }
    const body = req.method === 'POST' ? await readBody(req) : undefined;
    await httpTransport.handleRequest(req, res, body);
  };

  let server: import('node:http').Server | import('node:https').Server;
  if (USE_HTTPS) {
    if (!existsSync(TLS_CERT_PATH) || !existsSync(TLS_KEY_PATH)) {
      process.stderr.write(
        `HTTPS requested (MCP_HTTPS=1) but cert/key not found. Set MCP_TLS_CERT and MCP_TLS_KEY, or place server.crt and server.key in ./certs/\n` +
        `  Example (self-signed): openssl req -x509 -newkey rsa:2048 -keyout certs/server.key -out certs/server.crt -days 365 -nodes -subj /CN=localhost\n`
      );
      process.exit(1);
    }
    server = createHttpsServer(
      {
        cert: readFileSync(TLS_CERT_PATH),
        key: readFileSync(TLS_KEY_PATH),
      },
      requestHandler
    );
  } else {
    server = createHttpServer(requestHandler);
  }

  const scheme = USE_HTTPS ? 'https' : 'http';
  const transportMode = (process.env.MCP_TRANSPORT ?? 'streamable-http');

  // Support both HTTP and Stdio transports
  if (transportMode === 'stdio' || transportMode === 'both') {
    // Stdio transport for local VSCode integration
    const stdio = new StdioServerTransport();
    mcp.connect(stdio).catch((err) => {
      process.stderr.write('Stdio transport error: ' + String(err) + '\n');
    });
    process.stderr.write('✓ Stdio transport ready (for local VSCode)\n');
  }

  if (transportMode === 'streamable-http' || transportMode === 'both') {
    // HTTP transport for Symcon and remote clients
    server.listen(PORT, HOST, () => {
      process.stderr.write(
        '\n' +
        '╔═══════════════════════════════════════════════════════════════════════╗\n' +
        `║  Symcon MCP Server v${PKG_VERSION.padEnd(46)} ║\n` +
        '╠═══════════════════════════════════════════════════════════════════════╣\n' +
        `║  Listening:   ${(scheme + '://' + HOST + ':' + PORT).padEnd(52)} ║\n` +
        `║  Symcon API:  ${SYMCON_API_URL.padEnd(52)} ║\n` +
        `║  Auth:        API key required (✓)${' '.padEnd(30)} ║\n` +
        `║  Health:      ${(scheme + '://' + HOST + ':' + PORT + '/health').padEnd(52)} ║\n` +
        `║  Endpoint:    ${(scheme + '://' + HOST + ':' + PORT + '/').padEnd(52)} ║\n` +
        '║                                                                       ║\n' +
        '║  VSCode Clients:                                                    ║\n' +
        '║  Option 1: Stdio (Local Mode)                                       ║\n' +
        '║    {                                                                ║\n' +
        '║      "modelContextProtocol": {                                      ║\n' +
        '║        "servers": {                                                 ║\n' +
        '║          "symcon-mcp-stdio": {                                      ║\n' +
        '║            "command": "node",                                       ║\n' +
        `║            "args": ["path/to/node_modules/.bin/mcp-server"]   ║\n` +
        '║            "env": {                                                 ║\n' +
        '║              "MCP_TRANSPORT": "stdio",                              ║\n' +
        `║              "MCP_AUTH_TOKEN": "YOUR_KEY"                  ║\n` +
        '║              "SYMCON_API_URL": "http://localhost:3777/api/"        ║\n' +
        '║            }                                                        ║\n' +
        '║          }                                                          ║\n' +
        '║        }                                                            ║\n' +
        '║      }                                                              ║\n' +
        '║                                                                     ║\n' +
        '║  Option 2: HTTP (Remote Mode)                                       ║\n' +
        '║    {                                                                ║\n' +
        '║      "modelContextProtocol": {                                      ║\n' +
        '║        "servers": {                                                 ║\n' +
        '║          "symcon-mcp-http": {                                       ║\n' +
        '║            "command": "node",                                       ║\n' +
        `║            "args": ["path/to/http-client.js"]           ║\n` +
        '║            "env": {                                                 ║\n' +
        `║              "MCP_SERVER_URL": "${scheme}://${HOST}:${PORT}" ║\n` +
        '║              "MCP_API_KEY": "YOUR_KEY"                              ║\n' +
        '║            }                                                        ║\n' +
        '║          }                                                          ║\n' +
        '║        }                                                            ║\n' +
        '║      }                                                              ║\n' +
        '║                                                                     ║\n' +
        '╚═══════════════════════════════════════════════════════════════════════╝\n' +
        '\n'
      );
    });
  } else if (transportMode !== 'stdio') {
    process.stderr.write(`Warning: Unknown MCP_TRANSPORT="${transportMode}". Using streamable-http.\n`);
    server.listen(PORT, HOST);
  }
}

main().catch((err) => {
  process.stderr.write(String(err) + '\n');
  process.exit(1);
});

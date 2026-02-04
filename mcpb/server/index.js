#!/usr/bin/env node
/**
 * Symcon MCPB Launcher: startet den stdio→streamable-http Adapter per npx.
 * Erwartet Umgebungsvariablen: URI (Pflicht), MCP_NAME, BEARER_TOKEN (optional).
 * Der Adapter verbindet sich mit dem Symcon MCP-Server unter URI.
 */

const { spawn } = require('child_process');

const adapter = '@pyroprompts/mcp-stdio-to-streamable-http-adapter';
const uri = process.env.URI || 'http://127.0.0.1:4096';
const mcpName = process.env.MCP_NAME || 'symcon';
const bearerToken = process.env.BEARER_TOKEN || '';

const env = { ...process.env, URI: uri, MCP_NAME: mcpName };
if (bearerToken) env.BEARER_TOKEN = bearerToken;

const child = spawn('npx', ['-y', adapter], { stdio: 'inherit', env, shell: true });
child.on('close', (code) => process.exit(code == null ? 0 : code));
child.on('error', (err) => {
  console.error('Symcon MCPB Launcher:', err.message);
  process.exit(1);
});

// Proxy mínimo para Flyer GPTetal.
// Guarda la API key en el servidor y reenvía las peticiones de la app a OpenAI.
// Uso:  OPENAI_API_KEY=sk-... APP_TOKEN=algo-secreto node index.js
// En la app: Ajustes → URL del proxy = https://tu-servidor  (y deja la key vacía)

import http from "node:http";

const PORT = process.env.PORT || 8787;
const KEY = process.env.OPENAI_API_KEY;
const APP_TOKEN = process.env.APP_TOKEN; // opcional: si lo defines, la app debe mandarlo

if (!KEY) {
  console.error("Falta OPENAI_API_KEY");
  process.exit(1);
}

const ALLOWED = new Set(["/v1/images/generations", "/v1/images/edits"]);

http
  .createServer(async (req, res) => {
    if (req.method !== "POST" || !ALLOWED.has(req.url)) {
      res.writeHead(404).end("not found");
      return;
    }
    if (APP_TOKEN && req.headers["x-app-token"] !== APP_TOKEN) {
      res.writeHead(401).end("unauthorized");
      return;
    }
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const body = Buffer.concat(chunks);

    const upstream = await fetch("https://api.openai.com" + req.url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${KEY}`,
        "Content-Type": req.headers["content-type"] || "application/json",
      },
      body,
    });
    res.writeHead(upstream.status, {
      "Content-Type": upstream.headers.get("content-type") || "application/json",
    });
    res.end(Buffer.from(await upstream.arrayBuffer()));
  })
  .listen(PORT, () => console.log(`Flyer GPTetal proxy en :${PORT}`));

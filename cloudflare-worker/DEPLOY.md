# TV Livre - Cloudflare Worker

Serve o catálogo e resolve URLs de stream.

## Rotas

| Rota | Função |
|------|--------|
| `GET /catalog.json` | Proxy cacheado do catalog.json do GitHub (TTL 5min) |
| `GET /stream?url=X` | Resolve redirects e retorna URL final + status |
| `GET /health` | Health check |

## Deploy

```bash
cd cloudflare-worker
npm install
npx wrangler login      # primeira vez — abre o browser
npx wrangler deploy      # publica no Cloudflare
```

Após deploy, o Wrangler mostra a URL tipo:
`https://tv-livre-catalog.<seu-usuario>.workers.dev`

## Configurar no App

Edite `roku-tv-livre/config/catalog.json` e mude o `catalogUrl`:

```json
"catalogUrl": "https://tv-livre-catalog.<seu-usuario>.workers.dev/catalog.json"
```

## Variáveis (wrangler.toml)

- `CATALOG_URL` — URL do GitHub raw do catalog.json
- `CACHE_TTL` — segundos de cache (padrão: 300 = 5 min)

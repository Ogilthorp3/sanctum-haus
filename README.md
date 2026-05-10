# sanctum-haus

Consumer / marketing site for Sanctum at https://sanctum.haus.
Sister to the developer-facing [sanctum-docs](https://github.com/Ogilthorp3/sanctum-docs)
at https://sanctum.run.

## Why two domains

| | sanctum.haus (this repo) | sanctum.run (sanctum-docs) |
|---|---|---|
| Audience | Prepper-tech parents, podcast listeners, future Family Pass buyers | Developers, contributors, ops people |
| Voice | Warm, narrative, slightly literary | Technical, doctrine-driven |
| Purpose | Email capture → demo video → lifetime-pass purchase | Docs, runbooks, architecture |

The handoff: someone clicks "Install" on `.haus`, lands on `.run`.
Marketing-to-engineering as a domain transition.

## Local dev

```sh
pnpm install
pnpm dev          # localhost:4321
pnpm build        # → dist/
pnpm preview
```

## Deploy

GitHub Actions workflow at `.github/workflows/deploy.yml` deploys to
Cloudflare Pages on push to `main`. Mirror of the sanctum-docs deploy
flow. Requires repo secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Cloudflare Pages project name: `sanctum-haus`. After first push,
create the Pages project in the Cloudflare dashboard and point the
`sanctum.haus` apex DNS at it.

## Email capture

The `EmailCapture` component POSTs to `/api/notify-me` (a Pages
Function not yet implemented). Until that's wired, the form gracefully
falls back to a `mailto:` to `founders@sanctum.haus` so early traffic
still reaches a human.

When you wire the real backend, options ranked by solo-dev friction:

1. **Buttondown API** (~$9/mo, simplest) — POST to their `/v1/subscribers` endpoint
2. **ConvertKit API** — similar shape, more features
3. **Cloudflare KV-only** (free) — store emails in a KV namespace and export them periodically. Requires writing one line of admin tooling.

## Routes

- `/` — landing / coming-soon (also the demo-video landing later)
- `/notes/` — newsletter index (placeholder; first issue ships with founder beta)
- `/press/` — press kit (placeholder; expand when the first podcast inquiry hits)
- `/404` — gentle "lost in the haus" fallback

Future:

- `/showroom/` — hardware lifestyle SEO content
- `/stories/` — customer narratives (post-launch, when there are 5+ real users)
- `/store/` — Stripe checkout for Family Pass

## License

Marketing site; not open-sourced.

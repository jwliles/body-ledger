# Body Ledger — Web Client

Next.js 16 + React 19 + Tailwind CSS 4 + TypeScript web client for Body Ledger.

## Running Locally

```sh
npm install

# Create .env.local (not committed):
# NEXT_PUBLIC_API_URL=http://localhost:3000

npm run dev    # → http://localhost:3001 (if Rails is already on 3000)
```

The `NEXT_PUBLIC_API_URL` env var must point to the running Rails API. In production it is `https://api.bodyledger.org`.

## PWA

The web client includes a manifest, install icons, and a production-only service worker so it can be installed from Chromium-based browsers on Android and Linux desktop. Use a production build to test install behavior:

```sh
npm run build
npm run start
```

Chrome requires the app to be served from HTTPS for install prompts, except on `localhost`.

This app uses Next standalone output. `npm run build` also copies `public/` and `.next/static/` into `.next/standalone/` so the systemd service can serve the manifest, service worker, icons, and built assets from `node .next/standalone/server.js`.

## What's Built

- **Auth page** (`/`) — login and signup tabs, TOTP input field
- **Dashboard** (`/dashboard`) — health metrics, medication dose entry, BP/HR, weight, sleep, steps, editable records, medication admin update/merge flow
- **Reports** (`/reports`) — Rails-backed Datacore-parity dashboards

## In Progress

- Full history filtering
- Daily summary view
- Device management

## Stack

| | |
|---|---|
| Framework | Next.js 16.2.1 |
| UI | React 19.2.4 |
| Styling | Tailwind CSS 4 |
| Language | TypeScript 5 |
| Font | Atkinson Hyperlegible + Geist |
| Theme | Catppuccin Mocha dark |

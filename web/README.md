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

## What's Built

- **Auth page** (`/`) — login and signup tabs, TOTP input field
- **Dashboard** (`/dashboard`) — medication adherence table (last dose, time since); protected route

## In Progress

- Metric entry forms (7 types: BP, weight, sleep, activity, nutrition, symptom, medication dose)
- History view
- Daily summary view
- Settings (medications, device management)

## Stack

| | |
|---|---|
| Framework | Next.js 16.2.1 |
| UI | React 19.2.4 |
| Styling | Tailwind CSS 4 |
| Language | TypeScript 5 |
| Font | Atkinson Hyperlegible + Geist |
| Theme | Catppuccin Mocha dark |

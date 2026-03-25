"use client";

import { useState } from "react";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    // API integration coming soon
    setLoading(false);
  }

  return (
    <div className="flex flex-1 flex-col items-center justify-center px-4 bg-ctp-crust min-h-screen">
      <div className="w-full max-w-sm">
        {/* Header */}
        <div className="mb-10 text-center">
          <h1 className="text-3xl font-semibold tracking-tight text-ctp-text">
            body ledger
          </h1>
          <p className="mt-2 text-sm text-ctp-subtext0">
            Sign in to your account
          </p>
        </div>

        {/* Card */}
        <form
          onSubmit={handleSubmit}
          className="rounded-2xl bg-ctp-base p-8 flex flex-col gap-5 border border-ctp-surface0"
        >
          {/* Email */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="email" className="text-sm text-ctp-subtext1">
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
              placeholder="you@example.com"
            />
          </div>

          {/* Password */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="password" className="text-sm text-ctp-subtext1">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
              placeholder="••••••••"
            />
          </div>

          {/* TOTP */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="totp" className="text-sm text-ctp-subtext1">
              Authenticator code
            </label>
            <input
              id="totp"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              required
              maxLength={6}
              value={totp}
              onChange={(e) => setTotp(e.target.value.replace(/\D/g, ""))}
              className="rounded-lg bg-ctp-surface0 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue tracking-widest transition"
              placeholder="000000"
            />
          </div>

          {/* Error */}
          {error && (
            <p className="text-sm text-ctp-red">{error}</p>
          )}

          {/* Submit */}
          <button
            type="submit"
            disabled={loading}
            className="mt-1 rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] hover:bg-[#74c7ec] disabled:opacity-50 transition cursor-pointer"
          >
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const API = process.env.NEXT_PUBLIC_API_URL;

type Tab = "signin" | "signup";

export default function LoginPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("signin");

  // Sign-in fields
  const [siUsername, setSiUsername] = useState("");
  const [siPassword, setSiPassword] = useState("");
  const [siTotp, setSiTotp] = useState("");

  // Sign-up fields
  const [suUsername, setSuUsername] = useState("");
  const [suPassword, setSuPassword] = useState("");
  const [suEmail, setSuEmail] = useState("");

  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSignIn(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch(`${API}/api/v1/devices`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: siUsername,
          password: siPassword,
          otp_attempt: siTotp,
          name: "Web Browser",
          platform: "web",
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Something went wrong");
        return;
      }
      localStorage.setItem("device_token", data.token);
      localStorage.setItem("device_id", String(data.id));
      localStorage.setItem("username", siUsername);
      router.push("/dashboard");
    } catch {
      setError("Could not reach the server");
    } finally {
      setLoading(false);
    }
  }

  async function handleSignUp(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    try {
      const regRes = await fetch(`${API}/api/v1/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: suUsername,
          password: suPassword,
          ...(suEmail ? { email: suEmail } : {}),
          time_zone: timeZone,
        }),
      });
      const regData = await regRes.json();
      if (!regRes.ok) {
        setError(regData.error ?? "Registration failed");
        return;
      }

      const devRes = await fetch(`${API}/api/v1/devices`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: suUsername,
          password: suPassword,
          name: "Web Browser",
          platform: "web",
        }),
      });
      const devData = await devRes.json();
      if (!devRes.ok) {
        setError(devData.error ?? "Could not create device");
        return;
      }

      localStorage.setItem("device_token", devData.token);
      localStorage.setItem("device_id", String(devData.id));
      localStorage.setItem("username", suUsername);
      router.push("/dashboard");
    } catch {
      setError("Could not reach the server");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex flex-1 flex-col items-center justify-center px-4 bg-ctp-crust min-h-screen">
      <div className="w-full max-w-sm">
        {/* Header */}
        <div className="mb-10 text-center">
          <h1 className="text-3xl font-semibold tracking-tight text-ctp-text">
            body ledger
          </h1>
        </div>

        {/* Tab toggle */}
        <div className="flex rounded-xl bg-ctp-surface0 p-1 mb-6">
          <button
            type="button"
            onClick={() => { setTab("signin"); setError(null); }}
            className={`flex-1 rounded-lg py-2 text-sm font-medium transition cursor-pointer ${
              tab === "signin"
                ? "bg-ctp-base text-ctp-text shadow-sm"
                : "text-ctp-subtext1 hover:text-ctp-text"
            }`}
          >
            Sign in
          </button>
          <button
            type="button"
            onClick={() => { setTab("signup"); setError(null); }}
            className={`flex-1 rounded-lg py-2 text-sm font-medium transition cursor-pointer ${
              tab === "signup"
                ? "bg-ctp-base text-ctp-text shadow-sm"
                : "text-ctp-subtext1 hover:text-ctp-text"
            }`}
          >
            Create account
          </button>
        </div>

        {/* Card */}
        {tab === "signin" ? (
          <form
            onSubmit={handleSignIn}
            className="rounded-2xl bg-ctp-base p-8 flex flex-col gap-5 border border-ctp-surface0"
          >
            <div className="flex flex-col gap-1.5">
              <label htmlFor="si-username" className="text-sm text-ctp-subtext1">
                Username
              </label>
              <input
                id="si-username"
                type="text"
                autoComplete="username"
                required
                value={siUsername}
                onChange={(e) => setSiUsername(e.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
                placeholder="jwl"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="si-password" className="text-sm text-ctp-subtext1">
                Password
              </label>
              <input
                id="si-password"
                type="password"
                autoComplete="current-password"
                required
                value={siPassword}
                onChange={(e) => setSiPassword(e.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
                placeholder="••••••••"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="si-totp" className="text-sm text-ctp-subtext1">
                Authenticator code
              </label>
              <input
                id="si-totp"
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                required
                maxLength={6}
                value={siTotp}
                onChange={(e) => setSiTotp(e.target.value.replace(/\D/g, ""))}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition tracking-widest"
                placeholder="000000"
              />
            </div>

            {error && <p className="text-sm text-ctp-red">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="mt-1 rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] hover:bg-[#74c7ec] disabled:opacity-50 transition cursor-pointer"
            >
              {loading ? "Signing in…" : "Sign in"}
            </button>
          </form>
        ) : (
          <form
            onSubmit={handleSignUp}
            className="rounded-2xl bg-ctp-base p-8 flex flex-col gap-5 border border-ctp-surface0"
          >
            <div className="flex flex-col gap-1.5">
              <label htmlFor="su-username" className="text-sm text-ctp-subtext1">
                Username
              </label>
              <input
                id="su-username"
                type="text"
                autoComplete="username"
                required
                value={suUsername}
                onChange={(e) => setSuUsername(e.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
                placeholder="jwl"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="su-password" className="text-sm text-ctp-subtext1">
                Password
              </label>
              <input
                id="su-password"
                type="password"
                autoComplete="new-password"
                required
                value={suPassword}
                onChange={(e) => setSuPassword(e.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
                placeholder="••••••••"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="su-email" className="text-sm text-ctp-subtext1">
                Email <span className="text-ctp-overlay0">(optional)</span>
              </label>
              <input
                id="su-email"
                type="email"
                autoComplete="email"
                value={suEmail}
                onChange={(e) => setSuEmail(e.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue transition"
                placeholder="you@example.com"
              />
            </div>

            {error && <p className="text-sm text-ctp-red">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="mt-1 rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] hover:bg-[#74c7ec] disabled:opacity-50 transition cursor-pointer"
            >
              {loading ? "Creating account…" : "Create account"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

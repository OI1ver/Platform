import type { Env } from "./types";

const fallback = new Map<string, { count: number; expiresAt: number }>();
const WINDOW_SECONDS = 60;
const LIMIT = 60;

export async function rateLimit(request: Request, env: Env): Promise<number | null> {
  const ip = request.headers.get("CF-Connecting-IP") || "local";
  const installID = request.headers.get("X-Platform-Install-ID") || "missing";
  const identity = `${ip}:${installID.slice(0, 80)}`;
  const bucket = Math.floor(Date.now() / (WINDOW_SECONDS * 1_000));
  const key = `rate:${identity}:${bucket}`;

  if (env.RATE_LIMIT) {
    const count = Number((await env.RATE_LIMIT.get(key)) ?? "0") + 1;
    await env.RATE_LIMIT.put(key, String(count), { expirationTtl: WINDOW_SECONDS * 2 });
    return count > LIMIT ? secondsUntilNextWindow() : null;
  }

  const now = Date.now();
  const current = fallback.get(key);
  if (!current || current.expiresAt <= now) {
    fallback.set(key, { count: 1, expiresAt: now + WINDOW_SECONDS * 1_000 });
    return null;
  }
  current.count += 1;
  return current.count > LIMIT ? Math.ceil((current.expiresAt - now) / 1_000) : null;
}
function secondsUntilNextWindow(): number {
  const elapsed = Math.floor(Date.now() / 1_000) % WINDOW_SECONDS;
  return WINDOW_SECONDS - elapsed;
}

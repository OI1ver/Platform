import { fetchDepartureBoard, fetchServiceDetails, UpstreamError, type Fetcher } from "./darwin";
import { rateLimit } from "./rateLimit";
import { VALID_CRS_CODES } from "./stations.generated";
import type { Env } from "./types";

const JSON_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
};

export async function handleRequest(
  request: Request,
  env: Env,
  context: Pick<ExecutionContext, "waitUntil">,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  if (request.method !== "GET") return error("invalid_request", "Only GET requests are supported.", 405);

  const url = new URL(request.url);
  if (url.pathname === "/v1/health") {
    return json({ status: "ok" }, 200, { "Cache-Control": "no-store" });
  }

  const retryAfter = await rateLimit(request, env);
  if (retryAfter) {
    return error("rate_limited", "Too many requests. Please wait before refreshing.", 429, retryAfter);
  }

  const departureMatch = url.pathname.match(/^\/v1\/departures\/([A-Za-z]{3})$/);
  if (departureMatch) {
    const crs = departureMatch[1]!.toUpperCase();
    if (!VALID_CRS_CODES.has(crs)) return error("invalid_request", "Unknown station code.", 400);
    const requested = Number.parseInt(url.searchParams.get("limit") ?? "10", 10);
    if (!Number.isFinite(requested)) return error("invalid_request", "Limit must be a number.", 400);
    const limit = Math.min(Math.max(requested, 1), 10);
    return cachedResponse(request, env, context, `board:${crs}:${limit}`, () =>
      fetchDepartureBoard(env, crs, limit, fetcher));
  }

  const serviceMatch = url.pathname.match(/^\/v1\/services\/(.+)$/);
  if (serviceMatch) {
    let serviceID: string;
    try {
      serviceID = decodeURIComponent(serviceMatch[1]!);
    } catch {
      return error("invalid_request", "Invalid service identifier.", 400);
    }
    if (!serviceID || serviceID.length > 512) return error("invalid_request", "Invalid service identifier.", 400);
    return cachedResponse(request, env, context, `service:${serviceID}`, () =>
      fetchServiceDetails(env, serviceID, fetcher));
  }

  return error("not_found", "Endpoint not found.", 404);
}

async function cachedResponse(
  request: Request,
  env: Env,
  context: Pick<ExecutionContext, "waitUntil">,
  staleKey: string,
  load: () => Promise<unknown>,
): Promise<Response> {
  const cache = typeof caches !== "undefined"
    ? (caches as CacheStorage & { default: Cache }).default
    : undefined;
  const cacheKey = new Request(request.url, { method: "GET" });
  const hit = await cache?.match(cacheKey);
  if (hit) return hit;

  try {
    const value = await load();
    const response = json(value, 200, {
      "Cache-Control": "public, max-age=15, stale-if-error=120",
    });
    if (cache) context.waitUntil(cache.put(cacheKey, response.clone()));
    if (env.STALE_CACHE) {
      context.waitUntil(env.STALE_CACHE.put(staleKey, JSON.stringify(value), { expirationTtl: 120 }));
    }
    return response;
  } catch (caught) {
    const stale = await env.STALE_CACHE?.get(staleKey);
    if (stale) {
      return new Response(stale, {
        status: 200,
        headers: { ...JSON_HEADERS, "Cache-Control": "no-store", "X-Platform-Stale": "true" },
      });
    }
    if (caught instanceof UpstreamError) {
      if (caught.code === "service_expired") {
        return error("service_expired", "This service is no longer available.", 404);
      }
      if (caught.code === "invalid_response") {
        return error("upstream_unavailable", "Live rail data returned an invalid response.", 502, 30);
      }
    }
    return error("upstream_unavailable", "Live rail data is temporarily unavailable.", 503, 30);
  }
}

function json(value: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

function error(code: string, message: string, status: number, retryAfter?: number): Response {
  return json(
    { code, message, ...(retryAfter === undefined ? {} : { retryAfter }) },
    status,
    retryAfter === undefined ? { "Cache-Control": "no-store" } : {
      "Cache-Control": "no-store",
      "Retry-After": String(retryAfter),
    },
  );
}

export default {
  fetch(request: Request, env: Env, context: ExecutionContext) {
    return handleRequest(request, env, context);
  },
} satisfies ExportedHandler<Env>;

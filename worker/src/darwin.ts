import { normalizeBoard, normalizeServiceDetails } from "./normalize";
import type { DarwinBoard, DarwinServiceDetails, Env } from "./types";

export type Fetcher = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

export async function fetchDepartureBoard(
  env: Env,
  crs: string,
  limit: number,
  fetcher: Fetcher,
) {
  const url = endpoint(env.RDM_BASE_URL, env.RDM_API_KEY, env, `GetDepartureBoard/${crs}`);
  url.searchParams.set("numRows", String(limit));
  url.searchParams.set("timeOffset", "0");
  url.searchParams.set("timeWindow", "120");
  const payload = await upstreamJSON<DarwinBoard>(url, env.RDM_API_KEY, fetcher);
  return normalizeBoard(payload, crs);
}

export async function fetchServiceDetails(
  env: Env,
  serviceID: string,
  fetcher: Fetcher,
) {
  const url = endpoint(
    env.RDM_SERVICE_BASE_URL,
    env.RDM_SERVICE_API_KEY,
    env,
    `GetServiceDetails/${encodeURIComponent(serviceID)}`,
  );
  const payload = await upstreamJSON<DarwinServiceDetails | null>(url, env.RDM_SERVICE_API_KEY, fetcher);
  if (!payload) throw new UpstreamError("service_expired", 404);
  return normalizeServiceDetails(payload, serviceID);
}

export class UpstreamError extends Error {
  constructor(
    public readonly code: "service_expired" | "upstream_unavailable" | "invalid_response",
    public readonly status: number,
  ) {
    super(code);
  }
}

function endpoint(baseURL: string, apiKey: string, env: Env, operation: string): URL {
  if (!baseURL || !apiKey) {
    throw new UpstreamError("upstream_unavailable", 503);
  }
  const version = env.RDM_API_VERSION || "20220120";
  const base = new URL(baseURL);
  const cleanPath = base.pathname.replace(/\/$/, "");
  const apiRoot = cleanPath.match(/^(.*\/LDBWS\/api\/\d{8})(?:\/.*)?$/i)?.[1];

  if (apiRoot) {
    base.pathname = `${apiRoot}/${operation}`;
  } else if (/\/LDBWS$/i.test(cleanPath)) {
    base.pathname = `${cleanPath}/api/${version}/${operation}`;
  } else {
    base.pathname = `${cleanPath}/LDBWS/api/${version}/${operation}`;
  }
  return base;
}

async function upstreamJSON<T>(url: URL, apiKey: string, fetcher: Fetcher): Promise<T> {
  let lastStatus = 503;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const response = await fetcher(url, {
        headers: {
          Accept: "application/json",
          "User-Agent": "Platform/0.1",
          "x-apikey": apiKey,
        },
        signal: AbortSignal.timeout(8_000),
      });
      lastStatus = response.status;
      if (response.ok) {
        try {
          return await response.json<T>();
        } catch {
          throw new UpstreamError("invalid_response", 502);
        }
      }
      console.warn("RDM request failed", {
        host: url.host,
        path: url.pathname,
        status: response.status,
      });
      if (response.status < 500) break;
    } catch (error) {
      if (error instanceof UpstreamError) throw error;
      lastStatus = 503;
    }
  }
  throw new UpstreamError("upstream_unavailable", lastStatus >= 500 ? 503 : 502);
}

import { describe, expect, it, vi } from "vitest";
import { handleRequest } from "../src/index";
import type { Env } from "../src/types";

const env: Env = {
  RDM_BASE_URL: "https://example.test/product/LDBWS/api/20220120/GetDepartureBoard/{crs}",
  RDM_API_KEY: "consumer-key",
  RDM_SERVICE_BASE_URL: "https://example.test/service/LDBWS/api/20220120/GetServiceDetails/{serviceId}",
  RDM_SERVICE_API_KEY: "service-consumer-key",
  RDM_API_VERSION: "20220120",
};

const context = {
  waitUntil(_promise: Promise<unknown>) {},
};

describe("relay routes", () => {
  it("serves health without contacting Darwin", async () => {
    const fetcher = vi.fn();
    const response = await handleRequest(
      new Request("https://relay.test/v1/health"), env, context, fetcher,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: "ok" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("rejects unsupported methods before contacting Darwin", async () => {
    const fetcher = vi.fn();
    const response = await handleRequest(
      new Request("https://relay.test/v1/departures/CCH", { method: "POST" }),
      env,
      context,
      fetcher,
    );
    expect(response.status).toBe(405);
    expect(await response.json()).toMatchObject({ code: "invalid_request" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("validates unknown stations before the upstream request", async () => {
    const fetcher = vi.fn();
    const response = await handleRequest(
      new Request("https://relay.test/v1/departures/ZZZ"), env, context, fetcher,
    );
    expect(response.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("clamps the departure limit and keeps credentials upstream", async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(String(input));
      expect(url.pathname).toBe("/product/LDBWS/api/20220120/GetDepartureBoard/CCH");
      expect(url.searchParams.get("numRows")).toBe("10");
      expect(new Headers(init?.headers).get("x-apikey")).toBe("consumer-key");
      expect(new Headers(init?.headers).get("User-Agent")).toBe("Platform/0.1");
      return new Response(JSON.stringify({
        generatedAt: "2026-09-17T10:30:00Z",
        locationName: "Chichester",
        crs: "CCH",
        trainServices: [],
      }), { status: 200 });
    });
    const response = await handleRequest(
      new Request("https://relay.test/v1/departures/cch?limit=99", {
        headers: { "X-Platform-Install-ID": "test-install" },
      }), env, context, fetcher,
    );
    expect(response.status).toBe(200);
    expect((await response.json() as { station: { crs: string } }).station.crs).toBe("CCH");
    expect(fetcher).toHaveBeenCalledOnce();
  });

  it("maps an expired service to a stable safe error", async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(new URL(String(input)).pathname).toBe("/service/LDBWS/api/20220120/GetServiceDetails/a%2Fb");
      expect(new Headers(init?.headers).get("x-apikey")).toBe("service-consumer-key");
      return new Response("null", { status: 200 });
    });
    const response = await handleRequest(
      new Request("https://relay.test/v1/services/a%2Fb"), env, context, fetcher,
    );
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ code: "service_expired" });
  });

  it("rejects malformed encoded service identifiers", async () => {
    const fetcher = vi.fn();
    const response = await handleRequest(
      new Request("https://relay.test/v1/services/%E0%A4%A"), env, context, fetcher,
    );
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ code: "invalid_request" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("returns explicitly marked stale KV data during an upstream outage", async () => {
    const staleBoard = {
      station: { crs: "CCH", name: "Chichester" },
      generatedAt: "2026-09-17T10:30:00Z",
      services: [],
      messages: [],
    };
    const staleCache = {
      get: vi.fn(async () => JSON.stringify(staleBoard)),
      put: vi.fn(async () => undefined),
    } as unknown as KVNamespace;
    const fetcher = vi.fn(async () => {
      throw new Error("upstream offline");
    });
    const response = await handleRequest(
      new Request("https://relay.test/v1/departures/CCH", {
        headers: {
          "CF-Connecting-IP": "192.0.2.44",
          "X-Platform-Install-ID": "stale-cache-test",
        },
      }),
      { ...env, STALE_CACHE: staleCache },
      context,
      fetcher,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("X-Platform-Stale")).toBe("true");
    expect(await response.json()).toEqual(staleBoard);
  });

  it("does not expose upstream response bodies in errors", async () => {
    const fetcher = vi.fn(async () => new Response("credential dump", { status: 500 }));
    const response = await handleRequest(
      new Request("https://relay.test/v1/departures/CCH"), env, context, fetcher,
    );
    expect(response.status).toBe(503);
    expect(await response.text()).not.toContain("credential dump");
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
});

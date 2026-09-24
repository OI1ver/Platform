import { describe, expect, it } from "vitest";
import { rateLimit } from "../src/rateLimit";
import type { Env } from "../src/types";

const env = {} as Env;

describe("rate limiting", () => {
  it("allows sixty requests and rejects the sixty-first for one identity", async () => {
    const request = new Request("https://relay.test/v1/departures/CCH", {
      headers: {
        "CF-Connecting-IP": "192.0.2.60",
        "X-Platform-Install-ID": "rate-limit-boundary",
      },
    });

    for (let requestNumber = 1; requestNumber <= 60; requestNumber += 1) {
      expect(await rateLimit(request, env)).toBeNull();
    }
    const retryAfter = await rateLimit(request, env);
    expect(retryAfter).not.toBeNull();
    expect(retryAfter).toBeGreaterThan(0);
    expect(retryAfter).toBeLessThanOrEqual(60);
  });

  it("keeps separate installation identifiers in separate buckets", async () => {
    const headers = { "CF-Connecting-IP": "192.0.2.61" };
    const first = new Request("https://relay.test/v1/departures/CCH", {
      headers: { ...headers, "X-Platform-Install-ID": "installation-one" },
    });
    const second = new Request("https://relay.test/v1/departures/CCH", {
      headers: { ...headers, "X-Platform-Install-ID": "installation-two" },
    });

    for (let requestNumber = 1; requestNumber <= 60; requestNumber += 1) {
      await rateLimit(first, env);
    }
    expect(await rateLimit(first, env)).not.toBeNull();
    expect(await rateLimit(second, env)).toBeNull();
  });
});

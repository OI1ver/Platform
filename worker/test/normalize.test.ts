import { describe, expect, it } from "vitest";
import { normalizeBoard, normalizeServiceDetails } from "../src/normalize";

describe("Darwin normalization", () => {
  it("maps on-time, delayed, cancelled and unknown departures", () => {
    const board = normalizeBoard({
      generatedAt: "2026-09-17T10:30:00Z",
      locationName: "Chichester",
      crs: "CCH",
      nrccMessages: [{ Value: "<p>Check before you travel&nbsp; &amp; allow extra time.</p>" }],
      trainServices: [
        { ...service("on-time", "10:40", "On time"), length: 4 },
        { ...service("delayed", "10:45", "10:52"), length: "8", delayReason: "Signal failure&nbsp; near Clapham" },
        { ...service("cancelled", "11:00", "Cancelled"), isCancelled: true, cancelReason: "Crew shortage" },
        service("unknown", "11:15", "No report"),
      ],
    }, "CCH");

    expect(board.station).toEqual({ crs: "CCH", name: "Chichester" });
    expect(board.services.map((item) => item.status)).toEqual([
      "on_time", "delayed", "cancelled", "unknown",
    ]);
    expect(board.services[1]?.expectedDeparture).toBe("10:52");
    expect(board.services[0]?.carriageCount).toBe(4);
    expect(board.services[1]?.carriageCount).toBe(8);
    expect(board.services[1]?.delayReason).toBe("Signal failure near Clapham");
    expect(board.services[2]?.expectedDeparture).toBe("11:00");
    expect(board.messages).toEqual(["Check before you travel & allow extra time."]);
  });

  it("builds an ordered route from previous, current and subsequent points", () => {
    const details = normalizeServiceDetails({
      generatedAt: "2026-09-17T10:30:00Z",
      locationName: "Chichester",
      crs: "CCH",
      operator: "Southern",
      std: "10:38",
      etd: "10:41",
      previousCallingPoints: [{ callingPoint: [
        { locationName: "Portsmouth Harbour", crs: "PMH", st: "10:05", at: "10:06" },
      ] }],
      subsequentCallingPoints: [{ callingPoint: [
        { locationName: "Barnham", crs: "BAA", st: "10:46", et: "10:49" },
        { locationName: "Brighton", crs: "BTN", st: "11:20", et: "11:23" },
      ] }],
    }, "service/1");

    expect(details.callingPoints.map((point) => point.station.crs)).toEqual(["PMH", "CCH", "BAA", "BTN"]);
    expect(details.origins[0]?.name).toBe("Portsmouth Harbour");
    expect(details.destinations[0]?.name).toBe("Brighton");
  });
});

function service(id: string, std: string, etd: string) {
  return {
    serviceID: id,
    std,
    etd,
    platform: "2",
    operator: "Southern",
    destination: [{ locationName: "Brighton", crs: "BTN" }],
  };
}

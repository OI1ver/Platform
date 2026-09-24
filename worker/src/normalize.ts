import type {
  CallingPoint,
  DarwinBoard,
  DarwinCallingPoint,
  DarwinLocation,
  DarwinServiceDetails,
  DarwinServiceItem,
  Departure,
  DepartureBoard,
  NormalizedServiceDetails,
  ServiceStatus,
  StationReference,
} from "./types";

const TIME = /^\d{2}:\d{2}$/;

export function normalizeBoard(input: DarwinBoard, requestedCRS: string): DepartureBoard {
  return {
    station: {
      crs: (input.crs ?? requestedCRS).toUpperCase(),
      name: cleanText(input.locationName) || requestedCRS,
    },
    generatedAt: validDate(input.generatedAt),
    services: (input.trainServices ?? [])
      .filter((service): service is DarwinServiceItem & { serviceID: string; std: string } =>
        Boolean(service.serviceID && service.std),
      )
      .map(normalizeDeparture),
    messages: (input.nrccMessages ?? [])
      .map((message) => stripMarkup(typeof message === "string" ? message : message.Value ?? ""))
      .filter(Boolean),
  };
}

export function normalizeDeparture(service: DarwinServiceItem & { serviceID: string; std: string }): Departure {
  const expectedRaw = service.etd?.trim() || service.std;
  const status = deriveStatus(service, expectedRaw);
  return {
    id: service.serviceID,
    scheduledDeparture: service.std,
    expectedDeparture: TIME.test(expectedRaw) ? expectedRaw : service.std,
    destinations: normalizeLocations(service.currentDestinations?.length ? service.currentDestinations : service.destination),
    platform: cleanNullable(service.platform),
    carriageCount: normalizeCarriageCount(service.length),
    operatorName: cleanText(service.operator),
    status,
    statusText: statusText(status, expectedRaw),
    delayReason: cleanTextNullable(service.delayReason),
    cancellationReason: cleanTextNullable(service.cancelReason),
  };
}

export function normalizeServiceDetails(
  input: DarwinServiceDetails,
  serviceID: string,
): NormalizedServiceDetails {
  const previous = (input.previousCallingPoints ?? []).flatMap((group) => group.callingPoint ?? []);
  const subsequent = (input.subsequentCallingPoints ?? []).flatMap((group) => group.callingPoint ?? []);
  const currentScheduled = input.std ?? input.sta ?? "";
  const current: DarwinCallingPoint[] = input.locationName && currentScheduled
    ? [{
        locationName: input.locationName,
        ...(input.crs ? { crs: input.crs } : {}),
        st: currentScheduled,
        ...(input.etd ?? input.eta ? { et: input.etd ?? input.eta } : {}),
        ...(input.atd ?? input.ata ? { at: input.atd ?? input.ata } : {}),
        ...(input.isCancelled !== undefined ? { isCancelled: input.isCancelled } : {}),
        ...(input.cancelReason ? { cancelReason: input.cancelReason } : {}),
        ...(input.delayReason ? { delayReason: input.delayReason } : {}),
      }]
    : [];
  const points = deduplicate([...previous, ...current, ...subsequent].map(normalizeCallingPoint));
  const first = points[0]?.station;
  const last = points.at(-1)?.station;

  return {
    id: serviceID,
    operatorName: cleanText(input.operator),
    origins: first ? [first] : [],
    destinations: last ? [last] : [],
    callingPoints: points,
    generatedAt: validDate(input.generatedAt),
  };
}

function normalizeCallingPoint(point: DarwinCallingPoint): CallingPoint {
  const status = point.isCancelled
    ? "Cancelled"
    : cleanTextNullable(point.delayReason) ?? null;
  return {
    station: {
      crs: cleanNullable(point.crs)?.toUpperCase() ?? null,
      name: cleanText(point.locationName) || point.crs || "Unknown stop",
    },
    scheduledTime: point.st ?? "—",
    expectedTime: cleanNullable(point.et),
    actualTime: cleanNullable(point.at),
    platform: null,
    statusText: status,
  };
}

function normalizeLocations(locations: DarwinLocation[] | undefined): StationReference[] {
  return (locations ?? []).map((location) => ({
    crs: cleanNullable(location.crs)?.toUpperCase() ?? null,
    name: cleanText(location.locationName) || location.crs || "Unknown destination",
  }));
}

function deriveStatus(service: DarwinServiceItem, expected: string): ServiceStatus {
  const lower = expected.toLowerCase();
  if (service.isCancelled || lower.includes("cancel")) return "cancelled";
  if (lower.includes("platform change")) return "platform_changed";
  if (lower.includes("delay") || (TIME.test(expected) && expected !== service.std)) return "delayed";
  if (lower === "on time" || expected === service.std) return "on_time";
  return "unknown";
}

function statusText(status: ServiceStatus, expected: string): string {
  switch (status) {
    case "cancelled": return "Cancelled";
    case "platform_changed": return "Platform changed";
    case "delayed": return TIME.test(expected) ? `Expected ${expected}` : "Delayed";
    case "on_time": return "On time";
    case "unknown": return expected || "No live estimate";
  }
}

function validDate(value: string | undefined): string {
  if (value && !Number.isNaN(Date.parse(value))) return new Date(value).toISOString();
  return new Date().toISOString();
}

function cleanNullable(value: string | undefined): string | null {
  const cleaned = value?.trim();
  return cleaned ? cleaned : null;
}

function cleanText(value: string | undefined): string {
  return stripMarkup(value ?? "");
}

function cleanTextNullable(value: string | undefined): string | null {
  const cleaned = cleanText(value);
  return cleaned || null;
}

function normalizeCarriageCount(value: number | string | undefined): number | null {
  if (value === undefined || value === null || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value.trim());
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 99 ? parsed : null;
}

function stripMarkup(value: string): string {
  return value
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<\/p>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;|&#160;|&#x0*a0;/gi, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function deduplicate(points: CallingPoint[]): CallingPoint[] {
  const seen = new Set<string>();
  return points.filter((point) => {
    const key = `${point.station.crs ?? point.station.name}-${point.scheduledTime}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

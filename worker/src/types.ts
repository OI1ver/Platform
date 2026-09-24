export interface Env {
  RDM_BASE_URL: string;
  RDM_API_KEY: string;
  RDM_SERVICE_BASE_URL: string;
  RDM_SERVICE_API_KEY: string;
  RDM_API_VERSION?: string;
  RATE_LIMIT?: KVNamespace;
  STALE_CACHE?: KVNamespace;
}

export interface StationReference {
  crs: string | null;
  name: string;
}

export type ServiceStatus =
  | "on_time"
  | "delayed"
  | "cancelled"
  | "platform_changed"
  | "unknown";

export interface Departure {
  id: string;
  scheduledDeparture: string;
  expectedDeparture: string;
  destinations: StationReference[];
  platform: string | null;
  carriageCount: number | null;
  operatorName: string;
  status: ServiceStatus;
  statusText: string;
  delayReason: string | null;
  cancellationReason: string | null;
}

export interface DepartureBoard {
  station: { crs: string; name: string };
  generatedAt: string;
  services: Departure[];
  messages: string[];
}

export interface CallingPoint {
  station: StationReference;
  scheduledTime: string;
  expectedTime: string | null;
  actualTime: string | null;
  platform: string | null;
  statusText: string | null;
}

export interface NormalizedServiceDetails {
  id: string;
  operatorName: string;
  origins: StationReference[];
  destinations: StationReference[];
  callingPoints: CallingPoint[];
  generatedAt: string;
}

export interface DarwinLocation {
  locationName?: string;
  crs?: string;
}

export interface DarwinServiceItem {
  serviceID?: string;
  std?: string;
  etd?: string;
  platform?: string;
  length?: number | string;
  operator?: string;
  isCancelled?: boolean;
  destination?: DarwinLocation[];
  currentDestinations?: DarwinLocation[];
  cancelReason?: string;
  delayReason?: string;
}

export interface DarwinBoard {
  generatedAt?: string;
  locationName?: string;
  crs?: string;
  trainServices?: DarwinServiceItem[];
  nrccMessages?: Array<{ Value?: string } | string>;
}

export interface DarwinCallingPoint {
  locationName?: string;
  crs?: string;
  st?: string;
  et?: string;
  at?: string;
  isCancelled?: boolean;
  cancelReason?: string;
  delayReason?: string;
}

export interface DarwinServiceDetails {
  generatedAt?: string;
  locationName?: string;
  crs?: string;
  operator?: string;
  platform?: string;
  std?: string;
  etd?: string;
  atd?: string;
  sta?: string;
  eta?: string;
  ata?: string;
  isCancelled?: boolean;
  cancelReason?: string;
  delayReason?: string;
  previousCallingPoints?: Array<{ callingPoint?: DarwinCallingPoint[] }>;
  subsequentCallingPoints?: Array<{ callingPoint?: DarwinCallingPoint[] }>;
}

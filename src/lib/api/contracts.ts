/**
 * Browser-safe contracts only. Authentication, verification, matching, and
 * entitlements remain server-authoritative and are never represented as a
 * client-side source of truth.
 */
export type SystemHealth = {
  status: "UP";
  environment: string;
  checkedAt: string;
};

export type ApiProblem = {
  status: number;
  title: string;
  detail?: string;
  traceId?: string;
};

export type IdentityProvider = "EMAIL" | "GITHUB" | "LINKEDIN";

/** Read model only — the server decides whether a user can enter Meet. */
export type MeetEligibility = {
  eligible: boolean;
  missingProviders: IdentityProvider[];
};

export type ProfileIntent = "LEARN" | "BUILD" | "CONNECT" | "COLLABORATE";
export type MeetMode = "TEXT_FIRST" | "OPEN_TO_VOICE" | "OPEN_TO_VIDEO";
export type ProfileVisibility = "NETWORK" | "DISCOVERABLE" | "PRIVATE";
export type GoalCategory = "BUILD" | "LEARN" | "CONNECT" | "CAREER" | "COLLABORATE";
export type ProjectStatus = "IDEA" | "PLANNING" | "BUILDING" | "BETA" | "LIVE" | "PAUSED" | "COMPLETED";

export type ProfileCompletion = {
  readyForMatching: boolean;
  missingFields: string[];
};

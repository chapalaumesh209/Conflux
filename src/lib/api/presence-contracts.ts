export type AvailabilityState = "AVAILABLE" | "EXPIRED" | "OFFLINE";

/** A server projection; expiry and match eligibility are not browser-owned. */
export type MatchQueueStatus = {
  status: "SEARCHING" | "MATCHED" | "IDLE";
  expiresAt?: string;
};

export type MediaMode = "TEXT" | "VOICE" | "VIDEO";
export type MediaRequestStatus = "PENDING" | "ACCEPTED" | "DECLINED" | "EXPIRED" | "CANCELLED";

/** A request needs both people's consent before media negotiation can begin. */
export type MediaRequest = {
  requestId: string;
  requestedMode: MediaMode;
  status: MediaRequestStatus;
  expiresAt: string;
};

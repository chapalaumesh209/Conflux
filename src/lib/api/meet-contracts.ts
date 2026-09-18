export type MeetSessionStatus = "MATCHED" | "ACTIVE" | "COMPLETED" | "CANCELLED";

/** A V2 Meet session ends only by participant action or infrastructure safety handling. */
export type MeetSession = {
  sessionId: string;
  status: MeetSessionStatus;
  startedAt: string | null;
  reconnectUntil: string | null;
  endReason: "PARTICIPANT_LEFT" | "SKIPPED" | "BLOCKED" | "INACTIVE" | "DISCONNECTED" | null;
};

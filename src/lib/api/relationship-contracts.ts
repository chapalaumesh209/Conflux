export type MeetDecision = "CONNECT" | "NEXT";
export type ConnectionStatus = "PENDING" | "CONNECTED" | "DECLINED";

/** Server response shape; a browser never infers a mutual connection itself. */
export type ConnectionOutcome = {
  status: ConnectionStatus;
  conversationCreated: boolean;
};

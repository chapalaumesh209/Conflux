export type DiscoveryItem = {
  candidateUserId: string;
  position: number;
  matchReason: string;
};

/** Finite, server-ordered set — never an infinite-scroll cursor. */
export type DiscoveryDispatch = {
  dispatchId: string;
  expiresAt: string;
  items: DiscoveryItem[];
};

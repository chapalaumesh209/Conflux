"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  Check,
  ChevronLeft,
  CircleAlert,
  CircleDot,
  MessageCircle,
  Mic,
  MonitorUp,
  RefreshCw,
  Send,
  ShieldCheck,
  Sparkles,
  Video,
  WifiOff,
  X,
} from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMeetMedia } from "../lib/meet-media";
import { getSupabaseClient } from "../lib/supabase/client";
import type { Candidate } from "../lib/supabase/models";

type MeetCandidate = Candidate & { match_reasons?: string[] };
type MeetMessage = {
  id: string;
  sender_id: string;
  body: string;
  created_at: string;
  client_message_id?: string | null;
};
type ActiveMeet = MeetCandidate & {
  session_id: string;
  candidate_id: string;
  my_decision: "CONNECT" | "NEXT" | null;
  their_decision: "CONNECT" | "NEXT" | null;
  session_status: "PENDING_JOIN" | "ACTIVE";
  my_presence: "INVITED" | "JOINED" | "IGNORED" | "LEFT";
  peer_presence: "INVITED" | "JOINED" | "IGNORED" | "LEFT";
};

type ParticipantPresence = "INVITED" | "JOINED" | "IGNORED" | "LEFT";
type RealtimePresence = { profile_id?: string; phase?: string };
type DirectMeetStatus = "ONLINE_AVAILABLE" | "ONLINE" | "IN_MEET" | "OFFLINE";

const prompts = [
  "What are you building right now?",
  "What are you learning lately?",
  "What kind of collaboration would help most?",
];

const initials = (name: string) =>
  name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

const isMissingMediaStateRpc = (message?: string) =>
  Boolean(
    message?.includes("cf_set_meet_media_state") &&
    message.includes("schema cache"),
  );

const meetDecisionError = (message: string) =>
  message.includes("DAILY_CONNECTION_LIMIT_REACHED")
    ? "You’ve reached the limit of 10 new connections today. Try again tomorrow."
    : message;

export function FinalMeet({
  userId,
  onNotice,
  onError,
  onConnected,
}: {
  userId: string;
  onNotice: (message: string) => void;
  onError: (message: string) => void;
  onConnected: () => void;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const inviteSessionId = searchParams.get("session");
  const supabase = useMemo(() => getSupabaseClient(), []);
  const [candidate, setCandidate] = useState<MeetCandidate | null>(null);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<MeetMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [searched, setSearched] = useState(false);
  const [sending, setSending] = useState(false);
  const [decision, setDecision] = useState<"CONNECT" | "NEXT" | null>(null);
  const [peerDecision, setPeerDecision] = useState<"CONNECT" | "NEXT" | null>(
    null,
  );
  const [sessionStatus, setSessionStatus] = useState<
    "PENDING_JOIN" | "ACTIVE" | null
  >(null);
  const [myPresence, setMyPresence] = useState<ParticipantPresence | null>(
    null,
  );
  const [peerPresence, setPeerPresence] = useState<ParticipantPresence | null>(
    null,
  );
  const [peerOnline, setPeerOnline] = useState(false);
  const [joining, setJoining] = useState(false);
  const [candidateStatus, setCandidateStatus] =
    useState<DirectMeetStatus | null>(null);
  const [online, setOnline] = useState(true);
  const [isPro, setIsPro] = useState(false);
  const [meetingKind, setMeetingKind] = useState<"STANDARD" | "SHOWCASE">(
    "STANDARD",
  );
  const [skippedIds, setSkippedIds] = useState<string[]>([]);
  const [safetyOpen, setSafetyOpen] = useState(false);
  const [mutual, setMutual] = useState<{
    connectionId: string;
    conversationId: string | null;
  } | null>(null);
  const media = useMeetMedia({
    supabase,
    sessionId,
    userId,
    peerId: candidate?.id ?? null,
    onError,
    onNotice,
  });

  const hydrateMessages = useCallback(
    async (id: string) => {
      const { data, error } = await supabase
        .from("cf_meet_messages")
        .select("*")
        .eq("meet_session_id", id)
        .order("created_at");
      if (error) onError(error.message);
      else setMessages((data as MeetMessage[]) ?? []);
    },
    [onError, supabase],
  );

  const discover = useCallback(
    async (skipCurrent = false) => {
      const exclusions =
        skipCurrent && candidate
          ? Array.from(new Set([...skippedIds, candidate.id]))
          : skippedIds;
      if (skipCurrent && candidate) setSkippedIds(exclusions);
      media.stop();
      setLoading(true);
      setSearched(true);
      setCandidate(null);
      setSessionId(null);
      setMessages([]);
      setDecision(null);
      setPeerDecision(null);
      setSessionStatus(null);
      setMyPresence(null);
      setPeerPresence(null);
      setPeerOnline(false);
      onError("");
      const { data, error } = await supabase.rpc("cf_meet_candidate_preview", {
        excluded_candidate_ids: exclusions,
      });
      if (error) {
        // Migration 008 introduced the argument-based ranker. On a database
        // still running the earlier function, the legacy safe discovery RPC is
        // a real-data compatibility path, never a demo fallback.
        if (error.message.includes("schema cache")) {
          const fallback = await supabase.rpc("cf_discover_profiles", {
            result_limit: 24,
          });
          setLoading(false);
          if (fallback.error) return onError(fallback.error.message);
          const next = ((fallback.data as MeetCandidate[]) ?? []).find(
            (person) => !exclusions.includes(person.id),
          );
          if (!next && skipCurrent) {
            setSearched(false);
            setSkippedIds([]);
            onNotice(
              "That is the end of this Meet queue. You can start again when your signal changes.",
            );
          }
          setCandidate(
            next
              ? {
                  ...next,
                  match_reasons: [
                    next.match_reason ||
                      "Relevant to your current builder context",
                  ],
                }
              : null,
          );
          return;
        }
        setLoading(false);
        onError(error.message);
        return;
      }
      const next = ((data as MeetCandidate[]) ?? [])[0] ?? null;
      if (!next && skipCurrent) {
        setSearched(false);
        setSkippedIds([]);
        onNotice(
          "That is the end of this Meet queue. You can start again when your signal changes.",
        );
      }
      setCandidate(next);
      setLoading(false);
    },
    [candidate, media, onError, onNotice, skippedIds, supabase],
  );

  const restore = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.rpc("cf_get_active_meet");
    if (error) {
      setLoading(false);
      onError(error.message);
      return;
    }
    const active = ((data as ActiveMeet[]) ?? [])[0];
    if (active) {
      setCandidate({
        ...active,
        id: active.candidate_id,
        match_reasons: [
          "Your Meet is still active. Continue when you are ready.",
        ],
      });
      setSessionId(active.session_id);
      setDecision(active.my_decision);
      setPeerDecision(active.their_decision);
      setSessionStatus(active.session_status);
      setMyPresence(active.my_presence);
      setPeerPresence(active.peer_presence);
      if (active.session_status === "ACTIVE") {
        await hydrateMessages(active.session_id);
      }
    }
    setLoading(false);
  }, [hydrateMessages, onError, supabase]);

  useEffect(() => {
    void restore();
  }, [inviteSessionId, restore]);

  useEffect(() => {
    if (!candidate || sessionId) {
      setCandidateStatus(null);
      return;
    }
    let active = true;
    void supabase
      .rpc("cf_get_direct_meet_status", {
        requested_candidate_id: candidate.id,
      })
      .then(({ data, error }) => {
        if (!active) return;
        // Presence is a progressive enhancement during migration rollout. A
        // Meet invitation still retains its safe, recipient-controlled Join
        // path even when the availability RPC is not deployed yet.
        const status = Array.isArray(data) ? data[0]?.status : data?.status;
        setCandidateStatus(
          error || !status ? null : (status as DirectMeetStatus),
        );
      });
    return () => {
      active = false;
    };
  }, [candidate, sessionId, supabase]);

  useEffect(() => {
    const onlineNow = () => setOnline(true);
    const offlineNow = () => setOnline(false);
    setOnline(navigator.onLine);
    window.addEventListener("online", onlineNow);
    window.addEventListener("offline", offlineNow);
    return () => {
      window.removeEventListener("online", onlineNow);
      window.removeEventListener("offline", offlineNow);
    };
  }, []);

  useEffect(() => {
    if (!sessionId || !candidate) {
      setPeerOnline(false);
      return;
    }
    let active = true;
    const channel = supabase.channel(`meet-presence:${sessionId}`, {
      config: { private: true, presence: { key: userId } },
    });
    const sync = () => {
      const states = channel.presenceState() as Record<
        string,
        RealtimePresence[]
      >;
      const peer = Object.values(states)
        .flat()
        .find((item) => item.profile_id === candidate.id);
      if (!active) return;
      setPeerOnline(Boolean(peer));
      if (peer?.phase === "joined") setPeerPresence("JOINED");
    };
    channel
      .on("presence", { event: "sync" }, sync)
      .on("presence", { event: "join" }, sync)
      .on("presence", { event: "leave" }, sync)
      .subscribe((status) => {
        if (status !== "SUBSCRIBED") return;
        void channel
          .track({
            profile_id: userId,
            phase: myPresence === "JOINED" ? "joined" : "reviewing",
          })
          .then(sync);
      });
    return () => {
      active = false;
      setPeerOnline(false);
      void supabase.removeChannel(channel);
    };
  }, [candidate, myPresence, sessionId, supabase, userId]);

  useEffect(() => {
    if (!sessionId) return setIsPro(false);
    void supabase
      .from("cf_entitlements")
      .select("plan,status,expires_at")
      .eq("profile_id", userId)
      .maybeSingle()
      .then(({ data }) =>
        setIsPro(
          Boolean(
            data &&
            data.plan === "PRO" &&
            data.status === "ACTIVE" &&
            (!data.expires_at || new Date(data.expires_at) > new Date()),
          ),
        ),
      );
  }, [sessionId, supabase, userId]);

  useEffect(() => {
    if (!sessionId) {
      setMeetingKind("STANDARD");
      return;
    }
    let active = true;
    void supabase
      .from("cf_meet_sessions")
      .select("meeting_kind")
      .eq("id", sessionId)
      .maybeSingle()
      .then(({ data }) => {
        if (!active) return;
        setMeetingKind(
          data?.meeting_kind === "SHOWCASE" ? "SHOWCASE" : "STANDARD",
        );
      });
    return () => {
      active = false;
    };
  }, [sessionId, supabase]);

  const showMutual = useCallback(
    async (connectionId: string) => {
      const { data } = await supabase
        .from("cf_conversations")
        .select("id")
        .eq("connection_id", connectionId)
        .maybeSingle();
      setMutual({ connectionId, conversationId: data?.id ?? null });
      setSessionId(null);
      setDecision(null);
      setPeerDecision(null);
    },
    [supabase],
  );

  useEffect(() => {
    if (!sessionId) return;
    const channel = supabase
      .channel(`meet-final:${sessionId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "cf_meet_messages",
          filter: `meet_session_id=eq.${sessionId}`,
        },
        (payload) =>
          setMessages((current) =>
            current.some(
              (message) => message.id === (payload.new as MeetMessage).id,
            )
              ? current
              : [...current, payload.new as MeetMessage],
          ),
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "cf_meet_sessions",
          filter: `id=eq.${sessionId}`,
        },
        (payload) => {
          const row = payload.new as {
            status: string;
            connection_id?: string | null;
            participant_a_id: string;
            a_decision: "CONNECT" | "NEXT" | null;
            b_decision: "CONNECT" | "NEXT" | null;
          };
          const mine =
            row.participant_a_id === userId ? row.a_decision : row.b_decision;
          const theirs =
            row.participant_a_id === userId ? row.b_decision : row.a_decision;
          setDecision(mine);
          setPeerDecision(theirs);
          setSessionStatus(
            row.status === "PENDING_JOIN" || row.status === "ACTIVE"
              ? row.status
              : null,
          );
          if (row.status === "ACTIVE") {
            setMyPresence("JOINED");
            setPeerPresence("JOINED");
          }
          if (row.status === "SAFETY_CLOSED") {
            media.stop();
            setSessionId(null);
            setCandidate(null);
            onNotice("This Meet has ended.");
          } else if (row.status === "CLOSED" && row.connection_id) {
            media.stop();
            onNotice("It’s mutual — your private connection is now open.");
            void showMutual(row.connection_id);
          } else if (row.status === "CLOSED") {
            media.stop();
            setSessionId(null);
            setCandidate(null);
            setSessionStatus(null);
            setMyPresence(null);
            setPeerPresence(null);
            onNotice("This Meet invitation has ended.");
          }
        },
      )
      .subscribe();
    return () => void supabase.removeChannel(channel);
  }, [media, onNotice, sessionId, showMutual, supabase, userId]);

  const start = async () => {
    if (!candidate) return;
    setLoading(true);
    const { error } = await supabase.rpc("cf_open_meet", {
      candidate_id: candidate.id,
    });
    setLoading(false);
    if (error) return onError(error.message);
    await restore();
    onNotice("Interest sent. They can Join or Ignore privately.");
  };

  const joinMeet = async () => {
    if (!sessionId || joining) return;
    setJoining(true);
    const { error } = await supabase.rpc("cf_join_meet", {
      requested_session_id: sessionId,
    });
    setJoining(false);
    if (error) return onError(error.message);
    setSessionStatus("ACTIVE");
    setMyPresence("JOINED");
    setPeerPresence("JOINED");
    onNotice(
      "You joined the Meet. Text, mic, and camera are ready when you are.",
    );
    await hydrateMessages(sessionId);
  };

  const ignoreMeet = async () => {
    if (!sessionId || joining) return;
    setJoining(true);
    const { error } = await supabase.rpc("cf_ignore_meet", {
      requested_session_id: sessionId,
    });
    setJoining(false);
    if (error) return onError(error.message);
    media.stop();
    setSessionId(null);
    setCandidate(null);
    setSessionStatus(null);
    setMyPresence(null);
    setPeerPresence(null);
    onNotice("Meet request ignored. No connection was created.");
    void discover();
  };

  const cancelInvitation = async () => {
    if (!sessionId || joining) return;
    setJoining(true);
    const { error } = await supabase.rpc("cf_cancel_meet_invitation", {
      requested_session_id: sessionId,
    });
    setJoining(false);
    if (error) return onError(error.message);
    media.stop();
    setSessionId(null);
    setCandidate(null);
    setSessionStatus(null);
    setMyPresence(null);
    setPeerPresence(null);
    onNotice("Invitation cancelled. Finding another relevant builder.");
    void discover();
  };

  const nextDeveloper = async () => {
    if (!sessionId || joining) return;
    setJoining(true);
    const { error } = await supabase.rpc("cf_cancel_meet_invitation", {
      requested_session_id: sessionId,
    });
    setJoining(false);
    if (error) return onError(error.message);
    media.stop();
    setSessionId(null);
    setSessionStatus(null);
    setMyPresence(null);
    setPeerPresence(null);
    onNotice("Invitation cancelled. Looking for the next relevant developer.");
    await discover(true);
  };

  const send = async (event: FormEvent) => {
    event.preventDefault();
    if (!sessionId || !draft.trim() || sending || !online) return;
    const body = draft.trim();
    setDraft("");
    setSending(true);
    const { data, error } = await supabase.rpc("cf_send_meet_message", {
      requested_session_id: sessionId,
      requested_body: body,
      requested_client_message_id: crypto.randomUUID(),
    });
    setSending(false);
    if (error) {
      setDraft(body);
      return onError(error.message);
    }
    const message = data as MeetMessage;
    setMessages((current) =>
      current.some((item) => item.id === message.id)
        ? current
        : [...current, message],
    );
  };

  const choose = async (next: "CONNECT" | "NEXT") => {
    if (!sessionId || decision) return;
    setDecision(next);
    const { data, error } = await supabase.rpc("cf_record_meet_decision", {
      session_id: sessionId,
      choice: next,
    });
    if (error) {
      setDecision(null);
      return onError(meetDecisionError(error.message));
    }
    const response = Array.isArray(data) ? data[0] : null;
    if (response?.status === "MUTUAL_CONNECTION" && response.connection_id) {
      media.stop();
      onNotice("It’s mutual — your private connection is now open.");
      await showMutual(response.connection_id);
      onConnected();
    } else if (next === "NEXT" || response?.status === "CLOSED") {
      media.stop();
      setSessionId(null);
      setCandidate(null);
      onNotice("Meet ended. Finding a different relevant builder.");
      void discover();
    } else {
      onNotice("Connect is private. They can accept whenever they choose.");
    }
  };

  const persistMedia = useCallback(
    async (micEnabled: boolean, cameraEnabled: boolean) => {
      if (!sessionId) return;
      const { error } = await supabase.rpc("cf_set_meet_media_state", {
        requested_session_id: sessionId,
        requested_mic_enabled: micEnabled,
        requested_camera_enabled: cameraEnabled,
      });
      // Browser permissions control local mic/camera immediately. If an older
      // deployment has not yet loaded the optional audit RPC, do not turn a
      // working local media toggle into a visible product error.
      if (error && !isMissingMediaStateRpc(error.message))
        onError(error.message);
    },
    [onError, sessionId, supabase],
  );

  const toggleMic = async () => {
    try {
      const next = !media.hasAudio;
      if (next) {
        await media.prepare("AUDIO");
        await media.activate();
      } else media.toggleMute();
      await persistMedia(next, media.hasVideo);
    } catch (error) {
      onError(
        error instanceof Error
          ? error.message
          : "Could not change microphone state.",
      );
    }
  };

  const toggleCamera = async () => {
    try {
      const next = !media.hasVideo;
      if (next) {
        await media.prepare("VIDEO");
        await media.activate();
      } else media.toggleCamera();
      await persistMedia(media.hasAudio, next);
    } catch (error) {
      onError(
        error instanceof Error
          ? error.message
          : "Could not change camera state.",
      );
    }
  };

  const toggleScreen = async () => {
    if (!sessionId) return;
    try {
      if (media.hasScreen) {
        media.stopScreen();
        const { error } = await supabase.rpc("cf_end_meet_screen_share", {
          requested_session_id: sessionId,
        });
        if (error) throw error;
        onNotice("Screen sharing stopped.");
        return;
      }
      const { error } = await supabase.rpc("cf_begin_meet_screen_share", {
        requested_session_id: sessionId,
      });
      if (error) throw error;
      await media.startScreen();
      onNotice(
        "Screen share is live. Only Meet participants can receive the stream.",
      );
    } catch (error) {
      void supabase.rpc("cf_end_meet_screen_share", {
        requested_session_id: sessionId,
      });
      onError(
        error instanceof Error
          ? error.message
          : "Could not start screen sharing.",
      );
    }
  };

  const end = async () => {
    if (!sessionId) return;
    const { error } = await supabase.rpc("cf_end_meet", {
      requested_session_id: sessionId,
    });
    if (error) return onError(error.message);
    media.stop();
    setSessionId(null);
    setCandidate(null);
    setDecision(null);
    onNotice("Meet ended. No contact information was shared.");
  };

  const report = async () => {
    if (!candidate) return;
    const { error } = await supabase.from("cf_reports").insert({
      reporter_id: userId,
      subject_id: candidate.id,
      reason: "SAFETY",
      detail: null,
    });
    if (error) return onError(error.message);
    setSafetyOpen(false);
    onNotice(
      "Report received privately. Thank you for helping keep CONFLUX safe.",
    );
  };

  const block = async () => {
    if (!sessionId || !candidate) return;
    const { error } = await supabase.rpc("cf_block_meet_participant", {
      requested_session_id: sessionId,
      requested_subject_id: candidate.id,
    });
    if (error) return onError(error.message);
    media.stop();
    setSafetyOpen(false);
    setSessionId(null);
    setCandidate(null);
    onNotice("Blocked. They will not appear in future discovery.");
  };

  if (mutual) {
    return <MutualState mutual={mutual} />;
  }
  if (loading && !candidate) return <SearchingState />;
  if (!candidate && searched)
    return <EmptyState onRetry={() => void discover()} loading={loading} />;
  if (!candidate)
    return <IdleState onStart={() => void discover()} loading={loading} />;
  if (!sessionId)
    return (
      <CandidateState
        candidate={candidate}
        onBack={() => setCandidate(null)}
        onNext={() => void discover(true)}
        onJoin={() => void start()}
        loading={loading}
        status={candidateStatus}
      />
    );
  if (sessionStatus === "PENDING_JOIN" && myPresence === "INVITED")
    return (
      <IncomingMeetInvite
        candidate={candidate}
        isOnline={peerOnline}
        joining={joining}
        onJoin={() => void joinMeet()}
        onIgnore={() => void ignoreMeet()}
      />
    );
  if (sessionStatus === "PENDING_JOIN")
    return (
      <WaitingForMeetJoin
        candidate={candidate}
        isOnline={peerOnline}
        peerPresence={peerPresence}
        cancelling={joining}
        onCancel={() => void cancelInvitation()}
        onNext={() => void nextDeveloper()}
      />
    );

  const connectLabel =
    peerDecision === "CONNECT" && !decision
      ? "Accept"
      : decision === "CONNECT"
        ? "Connect pending"
        : "Connect";
  return (
    <section className="cf-live-meet cf-final-meet">
      <header>
        <CandidateSummary candidate={candidate} compact />
        <MeetAvailability
          isOnline={peerOnline}
          state={peerPresence}
          mediaConnected={media.status === "connected"}
        />
      </header>
      {meetingKind === "SHOWCASE" && (
        <div className="cf-showcase-meet-note">
          <MonitorUp size={17} />
          <span>
            <strong>Product showcase</strong>
            This is a text-first demo conversation. Screen sharing remains a Pro
            presenter control.
          </span>
        </div>
      )}
      {!online && (
        <div className="cf-meet-network">
          <WifiOff size={16} />
          You are offline. Your draft stays here; sending and decisions will
          resume after reconnection.
        </div>
      )}
      <div className="cf-final-live-layout">
        <section className="cf-final-media-column" aria-label="Live media">
          <div className="cf-meet-stage">
            <div
              className={`cf-media-tile ${media.remoteSpeaking ? "speaking" : ""}`}
            >
              <video
                ref={media.remoteVideoRef}
                autoPlay
                playsInline
                className={media.remoteActive ? "visible" : ""}
              />
              <span className="cf-avatar">{initials(candidate.full_name)}</span>
              <strong>{candidate.full_name}</strong>
              <small>
                {media.remoteSpeaking
                  ? "Speaking"
                  : media.remoteActive
                    ? "Live media"
                    : "Text-first Meet"}
              </small>
            </div>
            <i>
              <MessageCircle size={18} />
            </i>
            <div className="cf-media-tile cf-local-media-tile">
              <video
                ref={media.localVideoRef}
                autoPlay
                muted
                playsInline
                className={media.hasVideo || media.hasScreen ? "visible" : ""}
              />
              <span className="cf-avatar">You</span>
              <strong>You</strong>
              <small>
                {media.hasScreen
                  ? "Sharing screen"
                  : media.hasVideo
                    ? "Camera on"
                    : "Camera off"}
              </small>
            </div>
            <audio ref={media.remoteAudioRef} autoPlay />
            <p>
              {media.status === "connected"
                ? "Secure media connected."
                : "Text is ready. Turn on a mic or camera whenever you want."}
            </p>
          </div>
          <div className="cf-final-media-controls" aria-label="Media controls">
            <button
              className={media.hasAudio ? "active" : ""}
              onClick={() => void toggleMic()}
            >
              <Mic size={16} />
              {media.hasAudio ? "Mute" : "Mic"}
            </button>
            <button
              className={media.hasVideo ? "active" : ""}
              onClick={() => void toggleCamera()}
            >
              <Video size={16} />
              {media.hasVideo ? "Camera on" : "Camera"}
            </button>
            <button
              className={media.hasScreen ? "active" : ""}
              onClick={() => void toggleScreen()}
              disabled={!isPro && !media.hasScreen}
              title={
                isPro
                  ? "Share your screen"
                  : "Screen sharing is available with Pro"
              }
            >
              <MonitorUp size={16} />
              {media.hasScreen ? "Stop share" : "Share screen"}
            </button>
          </div>
          <p className="cf-media-policy">
            Mic and camera are your local browser controls. Screen sharing
            requires an active Pro entitlement.
          </p>
          <div className="cf-final-decisions">
            <button
              className="cf-quiet"
              onClick={() => setSafetyOpen((current) => !current)}
            >
              Safety
            </button>
            <button className="cf-quiet" onClick={() => void end()}>
              Leave
            </button>
            <span />
            <button
              className="cf-secondary"
              onClick={() => void choose("NEXT")}
              disabled={Boolean(decision)}
            >
              Next developer
            </button>
            <button
              className="cf-primary"
              onClick={() => void choose("CONNECT")}
              disabled={Boolean(decision)}
            >
              {connectLabel}
              <ArrowRight size={16} />
            </button>
          </div>
          {safetyOpen && (
            <div className="cf-final-safety">
              <div>
                <strong>Your space, your call.</strong>
                <p>Report or block without notifying the other person.</p>
              </div>
              <button className="cf-secondary" onClick={() => void block()}>
                Block
              </button>
              <button className="cf-primary" onClick={() => void report()}>
                Send private report
              </button>
              <button
                className="cf-quiet"
                aria-label="Close safety actions"
                onClick={() => setSafetyOpen(false)}
              >
                <X size={16} />
              </button>
            </div>
          )}
        </section>
        <section className="cf-final-chat-column" aria-label="Meet chat">
          <div className="cf-meet-prompt">
            <span>Try an opener</span>
            {prompts.map((prompt) => (
              <button key={prompt} onClick={() => setDraft(prompt)}>
                {prompt}
              </button>
            ))}
          </div>
          <div className="cf-chat" aria-live="polite">
            {messages.length ? (
              messages.map((message) => (
                <p
                  className={message.sender_id === userId ? "mine" : "theirs"}
                  key={message.id}
                >
                  {message.body}
                </p>
              ))
            ) : (
              <div className="cf-empty-small">
                <MessageCircle size={22} />
                Text is already open. Ask a real question or use an opener.
              </div>
            )}
          </div>
          <form className="cf-compose" onSubmit={send}>
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              maxLength={2000}
              disabled={!online || sending}
              placeholder="Write a thoughtful first message"
            />
            <button aria-label="Send message" disabled={!online || sending}>
              {sending ? <RefreshCw size={18} /> : <Send size={18} />}
            </button>
          </form>
        </section>
      </div>
    </section>
  );
}

function MeetAvailability({
  isOnline,
  state,
  mediaConnected,
}: {
  isOnline: boolean;
  state: ParticipantPresence | null;
  mediaConnected: boolean;
}) {
  const label = mediaConnected
    ? "Media connected"
    : state === "JOINED"
      ? isOnline
        ? "Online · ready"
        : "Disconnected"
      : isOnline
        ? "Online · in Meet"
        : "Not in Meet";
  return (
    <span className={`cf-meet-availability ${isOnline ? "online" : "offline"}`}>
      <i />
      {label}
    </span>
  );
}

function IncomingMeetInvite({
  candidate,
  isOnline,
  joining,
  onJoin,
  onIgnore,
}: {
  candidate: MeetCandidate;
  isOnline: boolean;
  joining: boolean;
  onJoin: () => void;
  onIgnore: () => void;
}) {
  return (
    <section className="cf-meet-invite">
      <div className="cf-meet-invite-copy">
        <CircleDot size={24} />
        <h1>{candidate.full_name} wants to meet.</h1>
        <p>
          {isOnline
            ? "They’re online and waiting for your response."
            : "Their invitation is waiting for you. Join when you’re ready, or ignore it privately."}
        </p>
      </div>
      <CandidateSummary candidate={candidate} compact />
      <div className="cf-meet-invite-actions">
        <button className="cf-secondary" onClick={onIgnore} disabled={joining}>
          Ignore
        </button>
        <button className="cf-primary" onClick={onJoin} disabled={joining}>
          {joining ? "Joining…" : "Join Meet"}
          <ArrowRight size={16} />
        </button>
      </div>
      <p className="cf-footnote">
        Joining opens text first. Your microphone and camera stay off until you
        turn them on.
      </p>
    </section>
  );
}

function WaitingForMeetJoin({
  candidate,
  isOnline,
  peerPresence,
  cancelling,
  onCancel,
  onNext,
}: {
  candidate: MeetCandidate;
  isOnline: boolean;
  peerPresence: ParticipantPresence | null;
  cancelling: boolean;
  onCancel: () => void;
  onNext: () => void;
}) {
  const message = isOnline
    ? peerPresence === "JOINED"
      ? "They joined. Opening the Meet now."
      : "They’re here and reviewing your invitation."
    : "Invitation sent. They’ll receive a Join or Ignore notification.";
  return (
    <section className="cf-meet-invite cf-meet-waiting">
      <div className="cf-meet-invite-copy">
        <CircleDot size={24} />
        <h1>Interest sent.</h1>
        <p>{message}</p>
      </div>
      <CandidateSummary candidate={candidate} compact />
      <div className="cf-meet-invite-actions">
        <MeetAvailability
          isOnline={isOnline}
          state={peerPresence}
          mediaConnected={false}
        />
        <span />
        <button className="cf-primary" onClick={onNext} disabled={cancelling}>
          <RefreshCw size={16} />
          {cancelling ? "Finding…" : "Next developer"}
        </button>
        <button
          className="cf-secondary"
          onClick={onCancel}
          disabled={cancelling}
        >
          {cancelling ? "Cancelling…" : "Cancel invitation"}
        </button>
      </div>
      <p className="cf-footnote">
        The conversation starts only after they choose Join. Next developer
        cancels this pending invitation and keeps the search on this page.
      </p>
    </section>
  );
}

function CandidateSummary({
  candidate,
  compact = false,
}: {
  candidate: MeetCandidate;
  compact?: boolean;
}) {
  return (
    <article className={`cf-person ${compact ? "compact" : ""}`}>
      <span className="cf-avatar large">{initials(candidate.full_name)}</span>
      <div>
        <div className="cf-person-title">
          <h2>{candidate.full_name}</h2>
          {candidate.email_verified && (
            <ShieldCheck size={16} aria-label="Email verified" />
          )}
        </div>
        <p>
          @{candidate.username} · {candidate.headline || "Builder"}
          {candidate.experience_band
            ? ` · ${candidate.experience_band.toLowerCase()}`
            : ""}
          {candidate.city ? ` · ${candidate.city}` : ""}
        </p>
      </div>
      {!compact && (
        <>
          <div className="cf-chips">
            {candidate.skills.slice(0, 5).map((skill) => (
              <span key={skill}>{skill}</span>
            ))}
          </div>
          <div className="cf-meet-reasons">
            <b>Why this person</b>
            {(candidate.match_reasons?.slice(0, 3) ?? [candidate.match_reason])
              .filter(Boolean)
              .map((reason) => (
                <span key={reason}>{reason}</span>
              ))}
          </div>
          <div className="cf-candidate-signal">
            <section>
              <b>Explores</b>
              <p>
                {candidate.domains.length
                  ? candidate.domains.join(" · ")
                  : "Current builder work"}
              </p>
            </section>
            <section>
              <b>Open to</b>
              <p>
                {candidate.goals.length
                  ? candidate.goals.join(" · ")
                  : candidate.looking_for || "A useful introduction"}
              </p>
            </section>
          </div>
          <div className="cf-person-context">
            <b>
              {candidate.current_build ? "Currently building" : "Looking for"}
            </b>
            <p>
              {candidate.current_build ||
                candidate.looking_for ||
                "Open to a useful introduction."}
            </p>
          </div>
          <div className="cf-verification">
            {candidate.email_verified && (
              <span>
                <Check size={13} />
                Email
              </span>
            )}
            {candidate.github_verified && (
              <span>
                <Check size={13} />
                GitHub
              </span>
            )}
            {candidate.linkedin_verified && (
              <span>
                <Check size={13} />
                LinkedIn
              </span>
            )}
            <small>
              Contact links stay private unless you both connect and sharing
              allows it.
            </small>
          </div>
        </>
      )}
    </article>
  );
}

function SearchingState() {
  return (
    <section className="cf-hero cf-final-searching">
      <div>
        <h1>Looking for a real reason to meet.</h1>
        <p>
          Matching your intent, current work, and availability without creating
          a feed.
        </p>
      </div>
      <div
        className="cf-search-motion"
        aria-label="Searching for a real builder"
      >
        <span />
        <span />
        <span />
        <i />
        <i />
        <i />
      </div>
    </section>
  );
}
function IdleState({
  onStart,
  loading,
}: {
  onStart: () => void;
  loading: boolean;
}) {
  return (
    <section className="cf-hero">
      <div>
        <h1>
          One person.
          <br />
          One real reason.
        </h1>
        <p>
          Meet uses your intent and current work to make one meaningful
          introduction at a time. There is no countdown and no endless feed.
        </p>
        <button className="cf-primary" onClick={onStart} disabled={loading}>
          Find a builder <Sparkles size={17} />
        </button>
      </div>
      <aside className="cf-hero-note">
        <MessageCircle size={21} />
        <strong>Text is always on</strong>
        <p>
          Turn on a microphone or camera when you want. Screen sharing is a Pro
          collaboration tool. Contact links stay private until you both connect.
        </p>
      </aside>
    </section>
  );
}
function EmptyState({
  onRetry,
  loading,
}: {
  onRetry: () => void;
  loading: boolean;
}) {
  return (
    <section className="cf-hero">
      <div>
        <h1>
          No new builder
          <br />
          right now.
        </h1>
        <p>
          You have reached the current end of eligible introductions. Try again
          later or update your profile signal.
        </p>
        <button className="cf-primary" onClick={onRetry} disabled={loading}>
          Try again <RefreshCw size={17} />
        </button>
      </div>
      <aside className="cf-hero-note">
        <Sparkles size={21} />
        <strong>Your queue stays finite</strong>
        <p>
          CONFLUX does not recycle people you already met or invent a feed when
          nobody eligible is available.
        </p>
      </aside>
    </section>
  );
}
function CandidateState({
  candidate,
  onBack,
  onNext,
  onJoin,
  loading,
  status,
}: {
  candidate: MeetCandidate;
  onBack: () => void;
  onNext: () => void;
  onJoin: () => void;
  loading: boolean;
  status: DirectMeetStatus | null;
}) {
  const isInMeet = status === "IN_MEET";
  const isAvailable = status === "ONLINE_AVAILABLE";
  const availabilityCopy =
    status === "IN_MEET"
      ? "Currently in a Meet — choose someone else and try again later."
      : status === "ONLINE_AVAILABLE"
        ? "Online and available — they can respond to your invitation now."
        : status === "ONLINE"
          ? "Online — send a private invitation and they choose whether to Join."
          : "Offline — send a private invitation for them to answer when they return.";
  return (
    <section className="cf-meet">
      <div className="cf-section-heading">
        <button className="cf-back" onClick={onBack}>
          <ChevronLeft size={16} />
          Back
        </button>
      </div>
      <CandidateSummary candidate={candidate} />
      <p
        className={`cf-candidate-availability ${isAvailable ? "available" : ""} ${isInMeet ? "busy" : ""}`}
      >
        <i />
        {availabilityCopy}
      </p>
      <div className="cf-meet-actions">
        <button className="cf-secondary" onClick={onNext} disabled={loading}>
          <RefreshCw size={17} />
          Next developer
        </button>
        <button
          className="cf-primary"
          onClick={onJoin}
          disabled={loading || isInMeet}
        >
          {isInMeet
            ? "Currently in a Meet"
            : isAvailable
              ? "Meet now"
              : "Show interest"}
          <CircleDot size={17} />
        </button>
      </div>
      <p className="cf-footnote">
        They will receive a private Join or Ignore notification. Next developer
        keeps the same relevance rules and skips this introduction.
      </p>
    </section>
  );
}
function MutualState({
  mutual,
}: {
  mutual: { connectionId: string; conversationId: string | null };
}) {
  const router = useRouter();
  return (
    <section className="cf-mutual-meet">
      <div>
        <span className="cf-mutual-mark">
          <Check size={26} />
        </span>
        <h1>
          You both chose
          <br />
          to connect.
        </h1>
        <p>
          Your private connection is ready. Continue the conversation, revisit
          their profile, or start a Build Room when the work calls for it.
        </p>
      </div>
      <div className="cf-mutual-actions">
        {mutual.conversationId && (
          <button
            className="cf-primary"
            onClick={() => router.push(`/chat/${mutual.conversationId}`)}
          >
            Open private chat <ArrowRight size={16} />
          </button>
        )}
        <button
          className="cf-secondary"
          onClick={() => router.push(`/connections/${mutual.connectionId}`)}
        >
          View connection
        </button>
        <button
          className="cf-secondary"
          onClick={() => router.push("/buildroom/new")}
        >
          Start a Build Room
        </button>
      </div>
    </section>
  );
}

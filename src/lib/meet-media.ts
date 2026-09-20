"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

export type MeetMediaKind = "AUDIO" | "VIDEO" | "SCREEN";
export type MeetMediaStatus =
  "idle" | "ready" | "connecting" | "connected" | "ended" | "error";

type Signal =
  | { type: "description"; description: RTCSessionDescriptionInit }
  | { type: "candidate"; candidate: RTCIceCandidateInit }
  | { type: "hangup" };

type MeetMediaOptions = {
  supabase: SupabaseClient;
  sessionId: string | null;
  userId: string;
  peerId: string | null;
  onError: (message: string) => void;
  onNotice: (message: string) => void;
};

const publicStunServers: RTCIceServer[] = [
  { urls: "stun:stun.l.google.com:19302" },
];

function attachStream(element: HTMLMediaElement | null, stream: MediaStream) {
  if (element && element.srcObject !== stream) element.srcObject = stream;
}

export function useMeetMedia({
  supabase,
  sessionId,
  userId,
  peerId,
  onError,
  onNotice,
}: MeetMediaOptions) {
  const localVideoRef = useRef<HTMLVideoElement | null>(null);
  const remoteVideoRef = useRef<HTMLVideoElement | null>(null);
  const remoteAudioRef = useRef<HTMLAudioElement | null>(null);
  const pcRef = useRef<RTCPeerConnection | null>(null);
  const signalRef = useRef<RealtimeChannel | null>(null);
  const localStreamRef = useRef<MediaStream | null>(null);
  const remoteStreamRef = useRef<MediaStream | null>(null);
  const activeSessionRef = useRef<string | null>(null);
  const screenTrackIdRef = useRef<string | null>(null);
  const makingOfferRef = useRef(false);
  const ignoreOfferRef = useRef(false);
  const iceServersRef = useRef<RTCIceServer[] | null>(null);
  const speakerMeterRef = useRef<{
    timer: number;
    context: AudioContext;
  } | null>(null);
  const [status, setStatus] = useState<MeetMediaStatus>("idle");
  const [hasAudio, setHasAudio] = useState(false);
  const [hasVideo, setHasVideo] = useState(false);
  const [hasScreen, setHasScreen] = useState(false);
  const [remoteActive, setRemoteActive] = useState(false);
  const [remoteSpeaking, setRemoteSpeaking] = useState(false);
  const [relayReady, setRelayReady] = useState(false);

  const localStream = useCallback(() => {
    if (!localStreamRef.current) localStreamRef.current = new MediaStream();
    return localStreamRef.current;
  }, []);

  const remoteStream = useCallback(() => {
    if (!remoteStreamRef.current) remoteStreamRef.current = new MediaStream();
    return remoteStreamRef.current;
  }, []);

  const stopSpeakerMeter = useCallback(() => {
    if (speakerMeterRef.current) {
      window.clearInterval(speakerMeterRef.current.timer);
      void speakerMeterRef.current.context.close();
      speakerMeterRef.current = null;
    }
    setRemoteSpeaking(false);
  }, []);

  const startSpeakerMeter = useCallback((stream: MediaStream) => {
    if (!stream.getAudioTracks().length || speakerMeterRef.current) return;
    try {
      const context = new AudioContext();
      const analyser = context.createAnalyser();
      analyser.fftSize = 256;
      context.createMediaStreamSource(stream).connect(analyser);
      const samples = new Uint8Array(analyser.frequencyBinCount);
      const timer = window.setInterval(() => {
        analyser.getByteFrequencyData(samples);
        const average =
          samples.reduce((total, sample) => total + sample, 0) / samples.length;
        setRemoteSpeaking(average > 9);
      }, 180);
      speakerMeterRef.current = { timer, context };
    } catch {
      // Speaking indication is progressive enhancement. Media remains usable
      // when the browser does not expose an analyser context.
      setRemoteSpeaking(false);
    }
  }, []);

  const sendSignal = useCallback(async (signal: Signal) => {
    if (!signalRef.current)
      throw new Error("Secure call channel is not ready.");
    const outcome = await signalRef.current.send({
      type: "broadcast",
      event: "signal",
      payload: signal,
    });
    if (outcome !== "ok")
      throw new Error(
        "Secure call setup could not reach the other participant.",
      );
  }, []);

  const getIceServers = useCallback(async () => {
    if (iceServersRef.current) return iceServersRef.current;
    try {
      const { data, error } = await supabase.functions.invoke(
        "meet-turn-credentials",
        { body: { sessionId } },
      );
      if (error) throw error;
      const servers = (data as { iceServers?: RTCIceServer[] } | null)
        ?.iceServers;
      if (!servers?.length)
        throw new Error("No relay configuration was returned.");
      iceServersRef.current = servers;
      setRelayReady(
        servers.some(
          (server) =>
            String(server.urls).startsWith("turn:") ||
            String(server.urls).startsWith("turns:"),
        ),
      );
      return servers;
    } catch {
      // STUN still establishes encrypted peer-to-peer calls on many networks. TURN is
      // deliberately a deployment concern because long-lived relay credentials must
      // never ship to the browser.
      iceServersRef.current = publicStunServers;
      setRelayReady(false);
      return publicStunServers;
    }
  }, [sessionId, supabase]);

  const closePeer = useCallback(
    (notifyPeer = false) => {
      if (notifyPeer)
        void sendSignal({ type: "hangup" }).catch(() => undefined);
      pcRef.current?.close();
      pcRef.current = null;
      remoteStreamRef.current?.getTracks().forEach((track) => track.stop());
      remoteStreamRef.current = null;
      if (remoteVideoRef.current) remoteVideoRef.current.srcObject = null;
      if (remoteAudioRef.current) remoteAudioRef.current.srcObject = null;
      stopSpeakerMeter();
      setRemoteActive(false);
      setStatus("ended");
    },
    [sendSignal, stopSpeakerMeter],
  );

  const ensureSignal = useCallback(async () => {
    if (!sessionId || !peerId)
      throw new Error("No active Meet is available for media.");
    if (signalRef.current) return signalRef.current;
    const channel = supabase.channel(`meet-signal:${sessionId}`, {
      config: { private: true },
    });
    channel.on("broadcast", { event: "signal" }, async ({ payload }) => {
      const signal = payload as Signal;
      const pc = pcRef.current;
      if (!pc) return;
      try {
        if (signal.type === "hangup") {
          closePeer(false);
          onNotice(
            "The other person ended the live call. Text remains available.",
          );
          return;
        }
        if (signal.type === "candidate") {
          if (!ignoreOfferRef.current)
            await pc.addIceCandidate(signal.candidate);
          return;
        }
        const description = signal.description;
        const polite = userId.localeCompare(peerId) > 0;
        const offerCollision =
          description.type === "offer" &&
          (makingOfferRef.current || pc.signalingState !== "stable");
        ignoreOfferRef.current = !polite && offerCollision;
        if (ignoreOfferRef.current) return;
        await pc.setRemoteDescription(description);
        if (description.type === "offer") {
          await pc.setLocalDescription();
          await sendSignal({
            type: "description",
            description: pc.localDescription!.toJSON(),
          });
        }
      } catch (error) {
        onError(
          error instanceof Error
            ? error.message
            : "Secure call negotiation failed. Please try again.",
        );
      }
    });
    const subscribed = await new Promise<string>((resolve) =>
      channel.subscribe((next) => resolve(next)),
    );
    if (subscribed !== "SUBSCRIBED") {
      void supabase.removeChannel(channel);
      throw new Error(
        "Secure call authorization is unavailable. Apply the Meet media migration, then try again.",
      );
    }
    signalRef.current = channel;
    return channel;
  }, [
    closePeer,
    onError,
    onNotice,
    peerId,
    sendSignal,
    sessionId,
    supabase,
    userId,
  ]);

  const ensurePeer = useCallback(async () => {
    if (pcRef.current) return pcRef.current;
    await ensureSignal();
    const pc = new RTCPeerConnection({
      iceServers: await getIceServers(),
      bundlePolicy: "max-bundle",
    });
    pcRef.current = pc;
    const local = localStream();
    local.getTracks().forEach((track) => pc.addTrack(track, local));
    pc.onicecandidate = ({ candidate }) => {
      if (candidate)
        void sendSignal({
          type: "candidate",
          candidate: candidate.toJSON(),
        }).catch((error) => onError(error.message));
    };
    pc.ontrack = ({ streams, track }) => {
      const remote = streams[0] ?? remoteStream();
      if (
        !streams[0] &&
        !remote.getTracks().some((item) => item.id === track.id)
      )
        remote.addTrack(track);
      attachStream(remoteVideoRef.current, remote);
      attachStream(remoteAudioRef.current, remote);
      startSpeakerMeter(remote);
      setRemoteActive(true);
    };
    pc.onnegotiationneeded = async () => {
      try {
        makingOfferRef.current = true;
        await pc.setLocalDescription();
        await sendSignal({
          type: "description",
          description: pc.localDescription!.toJSON(),
        });
      } catch (error) {
        onError(
          error instanceof Error
            ? error.message
            : "Could not start the secure call.",
        );
      } finally {
        makingOfferRef.current = false;
      }
    };
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === "connected") setStatus("connected");
      if (pc.connectionState === "connecting") setStatus("connecting");
      if (pc.connectionState === "failed") {
        setStatus("error");
        onError(
          "The call could not connect. Check your network and try again.",
        );
      }
      if (pc.connectionState === "closed") setStatus("ended");
    };
    setStatus("connecting");
    return pc;
  }, [
    ensureSignal,
    getIceServers,
    localStream,
    onError,
    remoteStream,
    sendSignal,
    startSpeakerMeter,
  ]);

  const addTracksToPeer = useCallback(async () => {
    const pc = pcRef.current;
    if (!pc) return;
    const stream = localStream();
    for (const track of stream.getTracks()) {
      if (!pc.getSenders().some((sender) => sender.track?.id === track.id))
        pc.addTrack(track, stream);
    }
  }, [localStream]);

  const prepare = useCallback(
    async (kind: Extract<MeetMediaKind, "AUDIO" | "VIDEO">) => {
      if (!navigator.mediaDevices?.getUserMedia)
        throw new Error(
          "This browser does not support audio or video calling.",
        );
      try {
        const existing = localStream();
        const needsAudio =
          kind === "AUDIO" && !existing.getAudioTracks().length;
        const needsVideo =
          kind === "VIDEO" &&
          !existing
            .getVideoTracks()
            .some((track) => track.id !== screenTrackIdRef.current);
        if (needsAudio || needsVideo) {
          const added = await navigator.mediaDevices.getUserMedia({
            audio: needsAudio,
            video: needsVideo,
          });
          added.getTracks().forEach((track) => existing.addTrack(track));
        }
        attachStream(localVideoRef.current, existing);
        setHasAudio(existing.getAudioTracks().some((track) => track.enabled));
        setHasVideo(
          existing
            .getVideoTracks()
            .some(
              (track) => track.enabled && track.id !== screenTrackIdRef.current,
            ),
        );
        await addTracksToPeer();
        setStatus((current) =>
          current === "idle" || current === "ended" ? "ready" : current,
        );
      } catch (error) {
        throw new Error(
          error instanceof DOMException && error.name === "NotAllowedError"
            ? "Camera or microphone permission was not granted."
            : "Could not access your camera or microphone.",
        );
      }
    },
    [addTracksToPeer, localStream],
  );

  const activate = useCallback(async () => {
    try {
      await ensurePeer();
    } catch (error) {
      setStatus("error");
      onError(
        error instanceof Error
          ? error.message
          : "Could not establish the secure call.",
      );
    }
  }, [ensurePeer, onError]);

  const toggleMute = useCallback(() => {
    const tracks = localStream().getAudioTracks();
    if (!tracks.length) return;
    const enabled = !tracks.every((track) => track.enabled);
    tracks.forEach((track) => {
      track.enabled = enabled;
    });
    setHasAudio(enabled);
  }, [localStream]);

  const toggleCamera = useCallback(() => {
    const tracks = localStream()
      .getVideoTracks()
      .filter((track) => track.id !== screenTrackIdRef.current);
    if (!tracks.length) return;
    const enabled = !tracks.every((track) => track.enabled);
    tracks.forEach((track) => {
      track.enabled = enabled;
    });
    setHasVideo(enabled);
  }, [localStream]);

  const startScreen = useCallback(async () => {
    if (!navigator.mediaDevices?.getDisplayMedia)
      throw new Error("Screen sharing is not supported by this browser.");
    try {
      const shared = await navigator.mediaDevices.getDisplayMedia({
        video: true,
        audio: false,
      });
      const track = shared.getVideoTracks()[0];
      if (!track) return;
      screenTrackIdRef.current = track.id;
      track.onended = () => {
        localStream().removeTrack(track);
        const sender = pcRef.current
          ?.getSenders()
          .find((item) => item.track?.id === track.id);
        if (sender && pcRef.current) void pcRef.current.removeTrack(sender);
        screenTrackIdRef.current = null;
        setHasScreen(false);
      };
      localStream().addTrack(track);
      attachStream(localVideoRef.current, localStream());
      setHasScreen(true);
      await ensurePeer();
      await addTracksToPeer();
    } catch (error) {
      throw new Error(
        error instanceof DOMException && error.name === "NotAllowedError"
          ? "Screen sharing was cancelled."
          : "Could not start screen sharing.",
      );
    }
  }, [addTracksToPeer, ensurePeer, localStream]);

  const stopScreen = useCallback(() => {
    const screenTrack = localStream()
      .getVideoTracks()
      .find((track) => track.id === screenTrackIdRef.current);
    screenTrack?.stop();
  }, [localStream]);

  const stop = useCallback(() => {
    closePeer(true);
    localStreamRef.current?.getTracks().forEach((track) => track.stop());
    localStreamRef.current = null;
    screenTrackIdRef.current = null;
    if (localVideoRef.current) localVideoRef.current.srcObject = null;
    setHasAudio(false);
    setHasVideo(false);
    setHasScreen(false);
    stopSpeakerMeter();
  }, [closePeer, stopSpeakerMeter]);

  useEffect(
    () => () => {
      closePeer(false);
      stopSpeakerMeter();
      localStreamRef.current?.getTracks().forEach((track) => track.stop());
      if (signalRef.current) void supabase.removeChannel(signalRef.current);
      signalRef.current = null;
    },
    [closePeer, stopSpeakerMeter, supabase],
  );

  useEffect(() => {
    if (activeSessionRef.current && activeSessionRef.current !== sessionId) {
      closePeer(false);
      localStreamRef.current?.getTracks().forEach((track) => track.stop());
      localStreamRef.current = null;
      screenTrackIdRef.current = null;
      if (signalRef.current) void supabase.removeChannel(signalRef.current);
      signalRef.current = null;
      iceServersRef.current = null;
      setHasAudio(false);
      setHasVideo(false);
      setHasScreen(false);
      stopSpeakerMeter();
    }
    activeSessionRef.current = sessionId;
  }, [closePeer, sessionId, stopSpeakerMeter, supabase]);

  return useMemo(
    () => ({
      localVideoRef,
      remoteVideoRef,
      remoteAudioRef,
      status,
      hasAudio,
      hasVideo,
      hasScreen,
      remoteActive,
      remoteSpeaking,
      relayReady,
      prepare,
      activate,
      toggleMute,
      toggleCamera,
      startScreen,
      stopScreen,
      stop,
    }),
    [
      activate,
      hasAudio,
      hasScreen,
      hasVideo,
      prepare,
      relayReady,
      remoteActive,
      remoteSpeaking,
      startScreen,
      status,
      stop,
      stopScreen,
      toggleCamera,
      toggleMute,
    ],
  );
}

import type { Metadata } from "next";
import "@fontsource/dm-mono/400.css";
import "@fontsource/bricolage-grotesque/400.css";
import "@fontsource/bricolage-grotesque/500.css";
import "@fontsource/bricolage-grotesque/600.css";
import "@fontsource/bricolage-grotesque/700.css";
import "./tokens.css";
import "./globals.css";
import "./landing.css";
import "./landing-v2.css";
import "./verification.css";
import "./profile-setup.css";
import "./connections.css";
import "./match-queue.css";
import "./meet-session.css";
import "./media-controls.css";
import "./discovery.css";
import "./pro.css";
import "./rooms.css";
import "./notifications.css";
import "./profile-v2.css";
import "./home-v2.css";
import "./safety.css";
import "./command.css";
import "./production.css";

export const metadata: Metadata = {
  title: "CONFLUX — Meet builders, build together",
  description: "Verified developer networking that turns a live introduction into meaningful collaboration.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

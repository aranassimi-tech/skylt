import type { Metadata } from "next";
import { Instrument_Sans } from "next/font/google";
import "./globals.css";

const ui = Instrument_Sans({ variable: "--font-ui", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Skyltstudio",
  description: "Digitala skyltar för butiker",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="sv">
      <body className={`${ui.variable} font-sans antialiased`}>{children}</body>
    </html>
  );
}

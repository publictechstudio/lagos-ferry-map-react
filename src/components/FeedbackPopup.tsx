"use client";

import { useEffect, useState } from "react";
import { REPORT_FORM_URL } from "@/lib/constants";

const DELAY_MS = 1.5 * 60 * 1000; // 1.5 minutes

export default function FeedbackPopup() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const dismissed = sessionStorage.getItem("feedback-dismissed");
    if (dismissed) return;

    const timer = setTimeout(() => setVisible(true), DELAY_MS);
    return () => clearTimeout(timer);
  }, []);

  function dismiss() {
    setVisible(false);
    sessionStorage.setItem("feedback-dismissed", "1");
  }

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/40">
      <div className="bg-surface rounded-2xl shadow-elevation-3 px-6 py-6 mx-4 max-w-sm w-full text-center">
        <p className="text-lg font-semibold text-on-surface mb-2">
          Did you find what you were looking for?
        </p>
        <p className="text-sm text-on-surface-variant mb-5">
          Your feedback helps us improve the Lagos Ferry Map.
        </p>
        <div className="flex flex-col gap-2.5">
          <a
            href={REPORT_FORM_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={dismiss}
            className="inline-flex items-center justify-center gap-2 px-5 py-2.5 text-sm font-semibold text-white bg-[#012c57] hover:bg-[#1976D2] rounded-full transition-colors duration-200"
          >
            Share Feedback
          </a>
          <button
            onClick={dismiss}
            className="text-sm text-on-surface-variant hover:text-on-surface transition-colors"
          >
            No thanks
          </button>
        </div>
      </div>
    </div>
  );
}

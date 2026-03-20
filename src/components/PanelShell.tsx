"use client";

import { REPORT_FORM_URL, FORM_ENTRY_LOCATION } from "@/lib/constants";
import DragHandle from "./DragHandle";

interface PanelShellProps {
  typeIcon: React.ReactNode;
  typeLabel: string;
  reportSlug: string;
  onClose: () => void;
  children: React.ReactNode;
}

export default function PanelShell({
  typeIcon,
  typeLabel,
  reportSlug,
  onClose,
  children,
}: PanelShellProps) {
  return (
    <div className="h-2/3 shrink-0 md:h-full md:w-1/2 flex flex-col bg-surface border-t border-outline-variant md:border-t-0 md:border-l overflow-hidden">
      <DragHandle />

      {/* Type label + actions */}
      <div className="flex items-center justify-between px-4 pt-4 pb-1 shrink-0">
        <div className="flex items-center gap-1.5 text-on-surface-variant">
          {typeIcon}
          <span className="text-sm">{typeLabel}</span>
        </div>
        <div className="inline-flex items-center">
          {/* Report data issue */}
          <div className="inline-flex items-center mb-0 w-42 text-xs font-semibold leading-6 text-white bg-[#012c57] group-hover:bg-[#1976D2] rounded-full px-5 py-2.5 transition-colors duration-200">
            <a
              href={`${REPORT_FORM_URL}?${FORM_ENTRY_LOCATION}=${encodeURIComponent(reportSlug)}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5"
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                <path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" />
              </svg>
              Report a data issue
            </a>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-on-surface/8 text-on-surface-variant transition-colors"
            aria-label="Close"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
        </div>
      </div>

      {children}
    </div>
  );
}

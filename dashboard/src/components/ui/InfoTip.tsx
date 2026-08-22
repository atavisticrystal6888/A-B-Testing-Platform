import { useEffect, useId, useState } from "react";
import { GLOSSARY, type StatsTerm } from "../../lib/statsGlossary";

function seenKey(term: StatsTerm): string {
  return `stat-tip-seen:${term}`;
}

function readSeen(term: StatsTerm): boolean {
  try {
    return window.localStorage.getItem(seenKey(term)) === "true";
  } catch {
    return false;
  }
}

function markSeen(term: StatsTerm): void {
  try {
    window.localStorage.setItem(seenKey(term), "true");
  } catch {
    // localStorage unavailable (e.g. private browsing) — the pulse just won't be remembered.
  }
}

interface InfoTipProps {
  term: StatsTerm;
}

/**
 * ⓘ button that reveals a plain-English glossary definition on hover, focus,
 * or click, and dismisses on Escape/blur. Pulses on first encounter (per
 * session, tracked in localStorage) until opened. Roadmap #12.
 */
export function InfoTip({ term }: InfoTipProps) {
  const entry = GLOSSARY[term];
  const [open, setOpen] = useState(false);
  const [seen, setSeen] = useState(() => readSeen(term));
  const tooltipId = useId();

  const reveal = () => {
    setOpen(true);
    if (!seen) {
      markSeen(term);
      setSeen(true);
    }
  };

  const close = () => setOpen(false);

  useEffect(() => {
    if (!open) return undefined;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        close();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [open]);

  return (
    <span className="relative inline-flex align-middle">
      <button
        type="button"
        aria-label={`What is ${entry.term}?`}
        aria-describedby={open ? tooltipId : undefined}
        onMouseEnter={reveal}
        onMouseLeave={close}
        onFocus={reveal}
        onBlur={close}
        onClick={reveal}
        className={`ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full text-[11px] font-semibold leading-none ${
          seen ? "text-gray-400 hover:text-gray-600" : "animate-pulse text-indigo-500"
        }`}
      >
        <span aria-hidden="true">ⓘ</span>
      </button>
      {open && (
        <span
          id={tooltipId}
          role="tooltip"
          className="absolute left-1/2 top-full z-10 mt-1 w-56 -translate-x-1/2 rounded-lg border border-gray-200 bg-white p-2 text-xs font-normal normal-case text-gray-600 shadow-lg"
        >
          {entry.definition}
        </span>
      )}
    </span>
  );
}

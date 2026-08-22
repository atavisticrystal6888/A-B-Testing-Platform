import {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type FocusEvent,
  type MouseEvent as ReactMouseEvent,
} from "react";
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

type Align = "center" | "left" | "right";

const POPOVER_ALIGN_CLASSES: Record<Align, string> = {
  center: "left-1/2 -translate-x-1/2",
  left: "left-0",
  right: "right-0",
};

interface InfoTipProps {
  term: StatsTerm;
}

/**
 * ⓘ button that reveals a plain-English glossary definition on hover, focus,
 * or click, and dismisses on Escape/blur. Pulses on first encounter (per
 * session, tracked in localStorage) until opened. Roadmap #12.
 *
 * Hover-opened tips close on mouseleave; click "pins" the tip open so
 * moving the mouse away to read it (or into the popover itself) doesn't
 * dismiss it — only Escape or blur closes a pinned tip.
 */
export function InfoTip({ term }: InfoTipProps) {
  const entry = GLOSSARY[term];
  const [open, setOpen] = useState(false);
  const [pinned, setPinned] = useState(false);
  const [seen, setSeen] = useState(() => readSeen(term));
  const [align, setAlign] = useState<Align>("center");
  const tooltipId = useId();
  const popoverRef = useRef<HTMLSpanElement>(null);

  const openTip = () => {
    setOpen(true);
    if (!seen) {
      markSeen(term);
      setSeen(true);
    }
  };

  const closeTip = () => {
    setOpen(false);
    setPinned(false);
  };

  // Closes on blur unless focus is moving somewhere inside our own popover
  // (there's nothing focusable in there today, but this covers it if that
  // ever changes) — determined by containment, not by any state left over
  // from an earlier event, so there's nothing that can go stale between
  // renders.
  const handleBlur = (event: FocusEvent<HTMLButtonElement>) => {
    const next = event.relatedTarget;
    if (next instanceof Node && popoverRef.current?.contains(next)) {
      return;
    }
    closeTip();
  };

  // The popover's definition text isn't focusable, so a mousedown on it
  // wouldn't move focus anywhere — relatedTarget on the resulting blur would
  // just be null, which containment alone can't tell apart from "focus left
  // for good". Preventing the mousedown's default action stops the browser
  // from blurring the trigger button in the first place, so no blur fires
  // for this click at all (the same technique listbox/combobox
  // implementations use to keep focus on their input while clicking a
  // non-focusable option).
  const handlePopoverMouseDown = (event: ReactMouseEvent) => {
    event.preventDefault();
  };

  const handleClick = () => {
    if (pinned) {
      closeTip();
      return;
    }
    setPinned(true);
    openTip();
  };

  const handleMouseLeave = () => {
    if (!pinned) {
      setOpen(false);
    }
  };

  useEffect(() => {
    if (!open) return undefined;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closeTip();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [open]);

  // Keep the popover inside the viewport: measure after it mounts (centered
  // by default) and flip to a left- or right-aligned edge if it would
  // overflow the window.
  useLayoutEffect(() => {
    if (!open) return;
    const el = popoverRef.current;
    if (!el || typeof window === "undefined") return;

    const rect = el.getBoundingClientRect();
    const margin = 8;

    if (rect.left < margin) {
      setAlign("left");
    } else if (rect.right > window.innerWidth - margin) {
      setAlign("right");
    } else {
      setAlign("center");
    }
  }, [open]);

  return (
    <span className="relative inline-flex align-middle">
      <button
        type="button"
        aria-label={`What is ${entry.term}?`}
        aria-describedby={open ? tooltipId : undefined}
        onMouseEnter={openTip}
        onMouseLeave={handleMouseLeave}
        onFocus={openTip}
        onBlur={handleBlur}
        onClick={handleClick}
        className={`ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full text-[11px] font-semibold leading-none ${
          seen ? "text-gray-400 hover:text-gray-600" : "animate-pulse text-indigo-500"
        }`}
      >
        <span aria-hidden="true">ⓘ</span>
      </button>
      {open && (
        <span
          ref={popoverRef}
          id={tooltipId}
          role="tooltip"
          onMouseEnter={openTip}
          onMouseLeave={handleMouseLeave}
          onMouseDown={handlePopoverMouseDown}
          className={`absolute top-full z-10 mt-1 w-56 max-w-[calc(100vw-2rem)] rounded-lg border border-gray-200 bg-white p-2 text-xs font-normal normal-case text-gray-600 shadow-lg ${POPOVER_ALIGN_CLASSES[align]}`}
        >
          {entry.definition}
        </span>
      )}
    </span>
  );
}

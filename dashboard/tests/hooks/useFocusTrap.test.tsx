import { describe, it, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { useState } from "react";
import { useFocusTrap } from "../../src/hooks/useFocusTrap";

function Panel({ onClose }: { onClose: () => void }) {
  const panelRef = useFocusTrap<HTMLDivElement>();

  return (
    <div ref={panelRef} role="dialog" data-testid="panel">
      <button>First</button>
      <button>Middle</button>
      <button onClick={onClose}>Last</button>
    </div>
  );
}

function Harness() {
  const [open, setOpen] = useState(false);

  return (
    <div>
      <button
        onClick={(e) => {
          (e.currentTarget as HTMLButtonElement).focus();
          setOpen(true);
        }}
      >
        Trigger
      </button>
      {open && <Panel onClose={() => setOpen(false)} />}
    </div>
  );
}

describe("useFocusTrap", () => {
  it("wraps Tab from the last focusable element to the first", () => {
    render(<Harness />);

    const trigger = screen.getByRole("button", { name: "Trigger" });
    trigger.focus();
    fireEvent.click(trigger);

    const last = screen.getByRole("button", { name: "Last" });
    last.focus();
    expect(document.activeElement).toBe(last);

    fireEvent.keyDown(document, { key: "Tab" });

    expect(document.activeElement).toBe(screen.getByRole("button", { name: "First" }));
  });

  it("wraps Shift+Tab from the first focusable element to the last", () => {
    render(<Harness />);

    fireEvent.click(screen.getByRole("button", { name: "Trigger" }));

    const first = screen.getByRole("button", { name: "First" });
    first.focus();

    fireEvent.keyDown(document, { key: "Tab", shiftKey: true });

    expect(document.activeElement).toBe(screen.getByRole("button", { name: "Last" }));
  });

  it("restores focus to the trigger once the panel closes", () => {
    render(<Harness />);

    const trigger = screen.getByRole("button", { name: "Trigger" });
    trigger.focus();
    fireEvent.click(trigger);

    expect(screen.getByTestId("panel")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Last" }));

    expect(screen.queryByTestId("panel")).not.toBeInTheDocument();
    expect(document.activeElement).toBe(trigger);
  });
});

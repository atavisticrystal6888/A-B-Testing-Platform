import { describe, it, expect, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { InfoTip } from "../../src/components/ui/InfoTip";
import { GLOSSARY } from "../../src/lib/statsGlossary";

describe("InfoTip", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("opens on click and shows the glossary definition", () => {
    render(<InfoTip term="p_value" />);

    const button = screen.getByRole("button", { name: "What is p-value?" });
    fireEvent.click(button);

    expect(screen.getByRole("tooltip")).toHaveTextContent(GLOSSARY.p_value.definition);
  });

  it("wires the popover to the button via aria-describedby", () => {
    render(<InfoTip term="power" />);

    const button = screen.getByRole("button", { name: "What is power?" });
    fireEvent.click(button);

    const tooltip = screen.getByRole("tooltip");
    expect(button).toHaveAttribute("aria-describedby", tooltip.id);
    expect(tooltip.id).toBeTruthy();
  });

  it("closes on Escape", () => {
    render(<InfoTip term="guardrail" />);

    const button = screen.getByRole("button", { name: "What is guardrail?" });
    fireEvent.click(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.keyDown(button, { key: "Escape" });
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("closes on blur", () => {
    render(
      <div>
        <InfoTip term="credible_interval" />
        <button>elsewhere</button>
      </div>,
    );

    const button = screen.getByRole("button", { name: "What is credible interval?" });
    fireEvent.click(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.blur(button);
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("writes the seen flag to localStorage once opened", () => {
    expect(window.localStorage.getItem("stat-tip-seen:p_value")).toBeNull();

    render(<InfoTip term="p_value" />);
    const button = screen.getByRole("button", { name: "What is p-value?" });

    expect(button.className).toContain("animate-pulse");

    fireEvent.click(button);

    expect(window.localStorage.getItem("stat-tip-seen:p_value")).toBe("true");
  });

  it("does not pulse once the term has already been seen", () => {
    window.localStorage.setItem("stat-tip-seen:power", "true");

    render(<InfoTip term="power" />);
    const button = screen.getByRole("button", { name: "What is power?" });

    expect(button.className).not.toContain("animate-pulse");
  });

  it("stays open on mouseleave once pinned by a click", () => {
    render(<InfoTip term="p_value" />);
    const button = screen.getByRole("button", { name: "What is p-value?" });

    fireEvent.click(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.mouseLeave(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();
  });

  it("prevents the popover's mousedown default, so clicking its text can never blur the trigger", () => {
    // This is what actually keeps a pinned tip open when its own
    // (non-focusable) text is clicked: browsers blur the currently focused
    // element on a mousedown that lands on a non-focusable target, so
    // preventing that default is what stops the blur from firing at all —
    // there's no relatedTarget to inspect otherwise, since nothing would
    // gain focus.
    render(<InfoTip term="p_value" />);
    const button = screen.getByRole("button", { name: "What is p-value?" });
    fireEvent.click(button);
    const tooltip = screen.getByRole("tooltip");
    expect(tooltip).toBeInTheDocument();

    const mousedownEvent = new MouseEvent("mousedown", { bubbles: true, cancelable: true });
    tooltip.dispatchEvent(mousedownEvent);

    expect(mousedownEvent.defaultPrevented).toBe(true);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();
  });

  it("still closes a pinned tip when blur genuinely moves focus elsewhere", () => {
    render(
      <div>
        <InfoTip term="p_value" />
        <button>elsewhere</button>
      </div>,
    );

    const button = screen.getByRole("button", { name: "What is p-value?" });
    fireEvent.click(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.blur(button);
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("regression: a hover-close after clicking the popover text must not leave stale state that swallows a later, real blur", () => {
    // Reported QA bug against the mousedown-flag version of this fix: the
    // flag was set by the popover mousedown and only ever consumed inside
    // handleBlur, but a hover-opened (never pinned) tip closes via
    // handleMouseLeave, which never touched the flag — so it survived past
    // the close and silently swallowed the next, unrelated blur. The fixed
    // implementation carries no state across events, so there's nothing
    // left to go stale here.
    render(
      <div>
        <InfoTip term="p_value" />
        <button>elsewhere</button>
      </div>,
    );

    const button = screen.getByRole("button", { name: "What is p-value?" });

    // Opened by hover — the trigger never takes focus.
    fireEvent.mouseEnter(button);
    const tooltip = screen.getByRole("tooltip");
    expect(tooltip).toBeInTheDocument();

    // Click the popover's own (non-focusable) text.
    fireEvent.mouseDown(tooltip);

    // Mouse leaves the popover — never pinned, so this closes it.
    fireEvent.mouseLeave(tooltip);
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();

    // The user tabs onto the icon...
    fireEvent.focus(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    // ...then tabs away to a genuinely different element. This must close
    // it — the old flag-based version failed this exact step.
    fireEvent.blur(button);
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("closes on mouseleave when only opened by hover", () => {
    render(<InfoTip term="p_value" />);
    const button = screen.getByRole("button", { name: "What is p-value?" });

    fireEvent.mouseEnter(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.mouseLeave(button);
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });
});

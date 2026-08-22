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

  it("stays open when the popover's own text is clicked, but still closes when blur goes elsewhere", () => {
    render(
      <div>
        <InfoTip term="p_value" />
        <button>elsewhere</button>
      </div>,
    );

    const button = screen.getByRole("button", { name: "What is p-value?" });
    fireEvent.click(button);
    const tooltip = screen.getByRole("tooltip");
    expect(tooltip).toBeInTheDocument();

    // Clicking the popover's own (non-focusable) text fires a mousedown on
    // it followed by a native blur on the button — the pinned tip must
    // survive that.
    fireEvent.mouseDown(tooltip);
    fireEvent.blur(button);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    // A later, unrelated blur (focus genuinely moving elsewhere) still
    // closes it.
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

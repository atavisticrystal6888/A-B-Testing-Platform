import { describe, it, expect, vi, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { RouteErrorBoundary } from "../../src/components/ui/RouteErrorBoundary";

let shouldThrow = true;

function Bomb() {
  if (shouldThrow) {
    throw new Error("Boom: rendering failed");
  }

  return <div>Safe content</div>;
}

function renderBoundary() {
  return render(
    <MemoryRouter>
      <RouteErrorBoundary>
        <Bomb />
      </RouteErrorBoundary>
    </MemoryRouter>,
  );
}

describe("RouteErrorBoundary", () => {
  afterEach(() => {
    shouldThrow = true;
    vi.restoreAllMocks();
  });

  it("renders the fallback when a child throws", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderBoundary();

    expect(screen.getByText("Something went wrong on this page")).toBeInTheDocument();
    expect(screen.getByText("Boom: rendering failed")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Try again" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Go to dashboard" })).toHaveAttribute("href", "/dashboard");
  });

  it("recovers via Try again once the underlying condition is fixed", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderBoundary();
    expect(screen.getByText("Something went wrong on this page")).toBeInTheDocument();

    shouldThrow = false;
    fireEvent.click(screen.getByRole("button", { name: "Try again" }));

    expect(screen.getByText("Safe content")).toBeInTheDocument();
    expect(screen.queryByText("Something went wrong on this page")).not.toBeInTheDocument();
  });
});

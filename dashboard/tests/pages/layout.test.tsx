import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import Layout from "../../src/pages/Layout";

vi.mock("../../src/contexts/AuthContext", () => ({
  useAuth: () => ({
    user: { id: "u1", email: "member@example.com", role: "member" },
    logout: vi.fn(),
  }),
}));

function renderLayout(initialEntry = "/dashboard") {
  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/dashboard" element={<div>Page content</div>} />
        </Route>
      </Routes>
    </MemoryRouter>,
  );
}

describe("Layout — collapsible sidebar", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("collapses the sidebar, hides nav labels, and persists the choice to localStorage", () => {
    renderLayout();

    const dashboardLabel = screen.getByText("Dashboard", { selector: "span" });
    expect(dashboardLabel).not.toHaveClass("md:hidden");
    expect(window.localStorage.getItem("sidebar-collapsed")).toBe("false");

    fireEvent.click(screen.getByRole("button", { name: "Collapse sidebar" }));

    expect(window.localStorage.getItem("sidebar-collapsed")).toBe("true");
    expect(dashboardLabel).toHaveClass("md:hidden");
    expect(screen.getByRole("button", { name: "Expand sidebar" })).toBeInTheDocument();
    // Icon-only nav items stay reachable via their title attribute.
    expect(screen.getByRole("link", { name: "Dashboard" })).toHaveAttribute("title", "Dashboard");
  });

  it("restores the collapsed state from localStorage on mount", () => {
    window.localStorage.setItem("sidebar-collapsed", "true");

    renderLayout();

    expect(screen.getByRole("button", { name: "Expand sidebar" })).toBeInTheDocument();
    expect(screen.getByText("Dashboard", { selector: "span" })).toHaveClass("md:hidden");
  });
});

describe("Layout — mobile drawer", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("opens on hamburger click and closes when Escape is pressed", () => {
    renderLayout();

    fireEvent.click(screen.getByRole("button", { name: "Open navigation menu" }));

    const sidebar = screen.getByRole("complementary");
    expect(sidebar).toHaveClass("translate-x-0");
    expect(document.querySelector(".bg-black\\/50")).toBeInTheDocument();

    fireEvent.keyDown(document, { key: "Escape" });

    expect(sidebar).toHaveClass("-translate-x-full");
    expect(document.querySelector(".bg-black\\/50")).not.toBeInTheDocument();
  });
});

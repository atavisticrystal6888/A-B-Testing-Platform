import { useCallback, useEffect, useState, type SVGProps } from "react";
import { Outlet, Link, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

const SIDEBAR_COLLAPSED_KEY = "sidebar-collapsed";

type IconProps = SVGProps<SVGSVGElement>;

function Icon({ children, ...props }: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      aria-hidden="true"
      {...props}
    >
      {children}
    </svg>
  );
}

function DashboardIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
      />
    </Icon>
  );
}

function ExperimentsIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5.106 14.4C3.128 16.377 4.53 19.5 7.323 19.5h9.354c2.794 0 4.195-3.123 2.217-5.1l-3.986-3.99a2.25 2.25 0 01-.659-1.591V3.104M14.25 3.104a3.001 3.001 0 00-4.5 0m4.5 0a24.301 24.301 0 00-4.5 0"
      />
    </Icon>
  );
}

function FlagsIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3 3v18M3 4.5c1-.667 2.333-1 4-1 2.5 0 3.5 1.5 6 1.5s3.5-1.5 6-1.5c1.667 0 3 .333 4 1v9c-1-.667-2.333-1-4-1-2.5 0-3.5 1.5-6 1.5s-3.5-1.5-6-1.5c-1.667 0-3 .333-4 1V4.5z"
      />
    </Icon>
  );
}

function MetricsIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3 21v-6.75M3 14.25a2.25 2.25 0 012.25-2.25h1.5a2.25 2.25 0 012.25 2.25V21M3 14.25V9.75A2.25 2.25 0 015.25 7.5h1.5A2.25 2.25 0 019 9.75V21m0 0v-9.75A2.25 2.25 0 0111.25 9h1.5A2.25 2.25 0 0115 11.25V21m0 0v-13.5A2.25 2.25 0 0117.25 6h1.5A2.25 2.25 0 0121 8.25V21"
      />
    </Icon>
  );
}

function AuditIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9zM12 17.25h3M9 12.75h6"
      />
    </Icon>
  );
}

function SettingsIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M10.343 3.94c.09-.542.56-.94 1.11-.94h1.093c.55 0 1.02.398 1.11.94l.149.894c.07.424.384.764.78.93.398.164.855.142 1.201-.108l.723-.523a1.125 1.125 0 011.45.12l.774.774c.399.4.436.998.12 1.45l-.523.723c-.25.346-.272.803-.108 1.2.166.397.506.71.93.78l.894.15c.542.09.94.56.94 1.109v1.094c0 .55-.398 1.02-.94 1.11l-.894.149c-.424.07-.764.383-.93.78-.164.397-.142.855.108 1.2l.523.723c.316.452.279 1.05-.12 1.45l-.774.775c-.4.399-.998.436-1.45.12l-.723-.523c-.346-.25-.803-.272-1.2-.108-.397.166-.71.506-.78.93l-.15.894c-.09.542-.56.94-1.109.94h-1.094c-.55 0-1.019-.398-1.11-.94l-.149-.894c-.07-.424-.383-.764-.78-.93-.397-.164-.854-.142-1.2.108l-.723.523c-.453.316-1.051.279-1.45-.12l-.775-.774a1.125 1.125 0 01-.12-1.45l.523-.723c.25-.346.272-.804.108-1.2-.166-.397-.506-.71-.93-.78l-.894-.15c-.542-.09-.94-.56-.94-1.109v-1.094c0-.55.398-1.02.94-1.11l.894-.149c.424-.07.764-.383.93-.78.164-.397.142-.854-.108-1.2l-.523-.723a1.125 1.125 0 01.12-1.45l.774-.775c.4-.399.998-.436 1.45-.12l.723.523c.346.25.804.272 1.2.108.397-.166.71-.506.78-.93l.15-.894z"
      />
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </Icon>
  );
}

function MenuIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
    </Icon>
  );
}

function ChevronIcon({ collapsed, ...props }: IconProps & { collapsed: boolean }) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d={collapsed ? "M8.25 4.5l7.5 7.5-7.5 7.5" : "M15.75 19.5L8.25 12l7.5-7.5"}
      />
    </Icon>
  );
}

function LogoutIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M8.25 9V5.25A2.25 2.25 0 0110.5 3h6a2.25 2.25 0 012.25 2.25v13.5A2.25 2.25 0 0116.5 21h-6a2.25 2.25 0 01-2.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75"
      />
    </Icon>
  );
}

const navItems = [
  { path: "/dashboard", label: "Dashboard", icon: DashboardIcon },
  { path: "/experiments", label: "Experiments", icon: ExperimentsIcon },
  { path: "/flags", label: "Feature Flags", icon: FlagsIcon },
  { path: "/metrics", label: "Metrics", icon: MetricsIcon },
  { path: "/audit-logs", label: "Audit Log", icon: AuditIcon },
];

const adminNavItems = [{ path: "/settings", label: "Settings", icon: SettingsIcon }];

function readStoredCollapsed(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === "true";
  } catch {
    return false;
  }
}

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();

  const [collapsed, setCollapsed] = useState<boolean>(readStoredCollapsed);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    try {
      window.localStorage.setItem(SIDEBAR_COLLAPSED_KEY, String(collapsed));
    } catch {
      // localStorage unavailable (e.g. private browsing) — collapse state just won't persist.
    }
  }, [collapsed]);

  useEffect(() => {
    if (!mobileOpen) return;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setMobileOpen(false);
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [mobileOpen]);

  const closeMobile = useCallback(() => setMobileOpen(false), []);
  const items = [...navItems, ...(user?.role === "admin" ? adminNavItems : [])];

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Mobile backdrop */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/50 md:hidden"
          onClick={closeMobile}
          aria-hidden="true"
        />
      )}

      {/* Sidebar */}
      <aside
        id="app-sidebar"
        className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r border-gray-200 bg-white transition-transform duration-200 ease-in-out md:relative md:z-auto md:translate-x-0 md:transition-[width] ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        } ${collapsed ? "md:w-16" : "md:w-64"}`}
      >
        <div
          className={`flex items-center border-b border-gray-100 p-6 ${
            collapsed ? "md:justify-center md:px-3" : ""
          }`}
        >
          <div className={collapsed ? "md:hidden" : ""}>
            <h1 className="text-xl font-bold text-gray-900">ExperimentHub</h1>
            <p className="text-sm text-gray-500 mt-1">A/B Testing Platform</p>
          </div>
          <span className={`hidden text-xl font-bold text-gray-900 ${collapsed ? "md:block" : ""}`}>
            EH
          </span>
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {items.map((item) => {
            const isActive = location.pathname.startsWith(item.path);
            const ItemIcon = item.icon;
            return (
              <Link
                key={item.path}
                to={item.path}
                title={item.label}
                onClick={closeMobile}
                className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all duration-150 ${
                  collapsed ? "md:justify-center md:gap-0 md:px-2" : ""
                } ${
                  isActive
                    ? "bg-indigo-50 text-indigo-700"
                    : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                }`}
              >
                <ItemIcon className="h-5 w-5 flex-shrink-0" />
                <span className={collapsed ? "md:hidden" : ""}>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Desktop-only collapse toggle */}
        <div className="hidden border-t border-gray-100 p-2 md:block">
          <button
            type="button"
            onClick={() => setCollapsed((current) => !current)}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            className={`flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm text-gray-500 transition-colors hover:bg-gray-50 hover:text-gray-900 ${
              collapsed ? "justify-center" : ""
            }`}
          >
            <ChevronIcon collapsed={collapsed} className="h-5 w-5 flex-shrink-0" />
            <span className={collapsed ? "hidden" : ""}>Collapse</span>
          </button>
        </div>

        {user && (
          <div className={`border-t border-gray-100 p-4 ${collapsed ? "md:px-2" : ""}`}>
            <div className={`truncate text-sm text-gray-600 ${collapsed ? "md:hidden" : ""}`}>
              {user.email}
            </div>
            <button
              onClick={logout}
              title="Sign out"
              className={`mt-2 flex items-center gap-2 text-sm text-red-600 transition-colors hover:text-red-700 ${
                collapsed ? "md:mt-0 md:justify-center md:gap-0" : ""
              }`}
            >
              <LogoutIcon className="h-4 w-4 flex-shrink-0" />
              <span className={collapsed ? "md:hidden" : ""}>Sign out</span>
            </button>
          </div>
        )}
      </aside>

      {/* Content column */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <header className="flex items-center gap-3 border-b border-gray-200 bg-white px-4 py-3 md:hidden">
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            aria-label="Open navigation menu"
            aria-expanded={mobileOpen}
            aria-controls="app-sidebar"
            className="rounded-lg p-2 text-gray-600 hover:bg-gray-100"
          >
            <MenuIcon className="h-6 w-6" />
          </button>
          <span className="text-lg font-bold text-gray-900">ExperimentHub</span>
        </header>

        <main className="min-w-0 flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

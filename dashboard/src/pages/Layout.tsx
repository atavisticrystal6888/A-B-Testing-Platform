import { Outlet, Link, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

const navItems = [
  { path: "/dashboard", label: "Dashboard", icon: "▣" },
  { path: "/experiments", label: "Experiments", icon: "🧪" },
  { path: "/flags", label: "Feature Flags", icon: "🚩" },
  { path: "/metrics", label: "Metrics", icon: "📊" },
  { path: "/audit-logs", label: "Audit Log", icon: "🧾" },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-gray-200 flex flex-col">
        <div className="p-6 border-b border-gray-100">
          <h1 className="text-xl font-bold text-gray-900">ExperimentHub</h1>
          <p className="text-sm text-gray-500 mt-1">A/B Testing Platform</p>
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => {
            const isActive = location.pathname.startsWith(item.path);
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150 ${
                  isActive
                    ? "bg-indigo-50 text-indigo-700"
                    : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                }`}
              >
                <span>{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>

        {user && (
          <div className="p-4 border-t border-gray-100">
            <div className="text-sm text-gray-600">{user.email}</div>
            <button
              onClick={logout}
              className="mt-2 text-sm text-red-600 hover:text-red-700 transition-colors"
            >
              Sign out
            </button>
          </div>
        )}
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}

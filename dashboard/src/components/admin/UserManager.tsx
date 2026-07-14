import { useState } from "react";
import type { User } from "../../lib/types";

interface UserManagerProps {
  users: User[];
  isLoading?: boolean;
  errorMessage?: string;
  onInvite: (email: string, role: User["role"], password: string) => void | Promise<void>;
  onUpdateRole: (userId: string, role: User["role"]) => void | Promise<void>;
  onRemove: (userId: string) => void | Promise<void>;
}

export function UserManager({ users, isLoading = false, errorMessage, onInvite, onUpdateRole, onRemove }: UserManagerProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<User["role"]>("viewer");

  const handleInvite = () => {
    if (!email || !password) return;
    onInvite(email, role, password);
    setEmail("");
    setPassword("");
  };

  return (
    <div className="space-y-6">
      <div className="flex items-end gap-3">
        <div className="flex-1">
          <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="user@example.com"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
        </div>
        <div className="flex-1">
          <label className="block text-sm font-medium text-gray-700 mb-1">Initial Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Minimum 8 characters"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value as User["role"])}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
          >
            <option value="viewer">Viewer</option>
            <option value="editor">Editor</option>
            <option value="admin">Admin</option>
          </select>
        </div>
        <button onClick={handleInvite} disabled={!email || password.length < 8} className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50">
          Invite
        </button>
      </div>

      {errorMessage && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {errorMessage}
        </div>
      )}

      <div className="rounded-xl border border-gray-200 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Email</th>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Role</th>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Joined</th>
              <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {isLoading ? (
              <tr>
                <td colSpan={4} className="px-6 py-8 text-center text-sm text-gray-500">
                  Loading users...
                </td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-6 py-8 text-center text-sm text-gray-500">
                  No users have been invited yet.
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id}>
                  <td className="px-6 py-3 text-sm text-gray-900">{user.email}</td>
                  <td className="px-6 py-3">
                    <select
                      value={user.role}
                      onChange={(e) => onUpdateRole(user.id, e.target.value as User["role"])}
                      className="text-sm border border-gray-300 rounded px-2 py-1"
                    >
                      <option value="viewer">Viewer</option>
                      <option value="editor">Editor</option>
                      <option value="admin">Admin</option>
                    </select>
                  </td>
                  <td className="px-6 py-3 text-sm text-gray-500">
                    {user.inserted_at ? new Date(user.inserted_at).toLocaleDateString() : "-"}
                  </td>
                  <td className="px-6 py-3 text-right">
                    <button onClick={() => onRemove(user.id)} className="text-sm text-red-600 hover:text-red-700">Remove</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

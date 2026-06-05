import { useState } from 'react';

interface User {
  id: string;
  email: string;
  role: string;
  inserted_at: string;
}

interface UserManagerProps {
  users: User[];
  onInvite: (email: string, role: string) => void;
  onUpdateRole: (userId: string, role: string) => void;
  onRemove: (userId: string) => void;
}

export function UserManager({ users, onInvite, onUpdateRole, onRemove }: UserManagerProps) {
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('viewer');

  const handleInvite = () => {
    if (!email) return;
    onInvite(email, role);
    setEmail('');
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
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
          <select value={role} onChange={(e) => setRole(e.target.value)} className="px-3 py-2 border border-gray-300 rounded-lg text-sm">
            <option value="viewer">Viewer</option>
            <option value="editor">Editor</option>
            <option value="admin">Admin</option>
          </select>
        </div>
        <button onClick={handleInvite} disabled={!email} className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50">
          Invite
        </button>
      </div>

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
            {users.map((user) => (
              <tr key={user.id}>
                <td className="px-6 py-3 text-sm text-gray-900">{user.email}</td>
                <td className="px-6 py-3">
                  <select
                    value={user.role}
                    onChange={(e) => onUpdateRole(user.id, e.target.value)}
                    className="text-sm border border-gray-300 rounded px-2 py-1"
                  >
                    <option value="viewer">Viewer</option>
                    <option value="editor">Editor</option>
                    <option value="admin">Admin</option>
                  </select>
                </td>
                <td className="px-6 py-3 text-sm text-gray-500">{new Date(user.inserted_at).toLocaleDateString()}</td>
                <td className="px-6 py-3 text-right">
                  <button onClick={() => onRemove(user.id)} className="text-sm text-red-600 hover:text-red-700">Remove</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

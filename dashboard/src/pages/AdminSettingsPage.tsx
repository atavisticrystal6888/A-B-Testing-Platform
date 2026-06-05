import { useState } from 'react';
import { ApiKeyManager } from '../components/admin/ApiKeyManager';
import { UserManager } from '../components/admin/UserManager';

export function AdminSettingsPage() {
  const [tab, setTab] = useState<'tenant' | 'api-keys' | 'users'>('tenant');

  const tabs = [
    { key: 'tenant', label: 'Tenant Info' },
    { key: 'api-keys', label: 'API Keys' },
    { key: 'users', label: 'Users' },
  ] as const;

  return (
    <div className="max-w-5xl mx-auto py-8 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Settings</h1>

      <div className="flex gap-1 mb-6 border-b border-gray-200">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === t.key
                ? 'text-indigo-600 border-indigo-600'
                : 'text-gray-500 border-transparent hover:text-gray-700'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'tenant' && (
        <div className="rounded-xl border border-gray-200 bg-white p-6 space-y-4">
          <h2 className="text-lg font-semibold text-gray-900">Tenant Information</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Tenant Name</label>
              <input type="text" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" placeholder="My Organization" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Plan</label>
              <input type="text" disabled className="w-full px-3 py-2 border border-gray-200 bg-gray-50 rounded-lg text-sm" value="Enterprise" />
            </div>
          </div>
          <button className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700">
            Save Changes
          </button>
        </div>
      )}

      {tab === 'api-keys' && (
        <ApiKeyManager
          apiKeys={[]}
          onGenerate={async (name) => ({ key: `eh_live_${name}_placeholder` })}
          onRevoke={() => {}}
        />
      )}

      {tab === 'users' && (
        <UserManager
          users={[]}
          onInvite={() => {}}
          onUpdateRole={() => {}}
          onRemove={() => {}}
        />
      )}
    </div>
  );
}

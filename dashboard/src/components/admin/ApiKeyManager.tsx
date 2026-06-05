import { useState } from 'react';

interface ApiKey {
  id: string;
  prefix: string;
  name: string;
  last_used_at?: string;
  inserted_at: string;
}

interface ApiKeyManagerProps {
  apiKeys: ApiKey[];
  onGenerate: (name: string) => Promise<{ key: string }>;
  onRevoke: (id: string) => void;
}

export function ApiKeyManager({ apiKeys, onGenerate, onRevoke }: ApiKeyManagerProps) {
  const [newKeyName, setNewKeyName] = useState('');
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);

  const handleGenerate = async () => {
    if (!newKeyName) return;
    setGenerating(true);
    try {
      const result = await onGenerate(newKeyName);
      setGeneratedKey(result.key);
      setNewKeyName('');
    } finally {
      setGenerating(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-end gap-3">
        <div className="flex-1">
          <label className="block text-sm font-medium text-gray-700 mb-1">Key Name</label>
          <input
            type="text"
            value={newKeyName}
            onChange={(e) => setNewKeyName(e.target.value)}
            placeholder="Production API Key"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
        </div>
        <button
          onClick={handleGenerate}
          disabled={!newKeyName || generating}
          className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
        >
          Generate
        </button>
      </div>

      {generatedKey && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-lg">
          <p className="text-sm font-medium text-emerald-800 mb-2">New API Key Generated</p>
          <div className="flex items-center gap-2">
            <code className="flex-1 text-sm font-mono bg-white px-3 py-2 rounded border">{generatedKey}</code>
            <button
              onClick={() => copyToClipboard(generatedKey)}
              className="px-3 py-2 text-sm text-emerald-700 bg-emerald-100 rounded-lg hover:bg-emerald-200"
            >
              Copy
            </button>
          </div>
          <p className="text-xs text-emerald-600 mt-2">Store this key securely. It will not be shown again.</p>
        </div>
      )}

      <div className="rounded-xl border border-gray-200 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Name</th>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Prefix</th>
              <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Created</th>
              <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {apiKeys.map((key) => (
              <tr key={key.id}>
                <td className="px-6 py-3 text-sm text-gray-900">{key.name}</td>
                <td className="px-6 py-3 text-sm text-gray-500 font-mono">{key.prefix}...</td>
                <td className="px-6 py-3 text-sm text-gray-500">{new Date(key.inserted_at).toLocaleDateString()}</td>
                <td className="px-6 py-3 text-right">
                  <button onClick={() => onRevoke(key.id)} className="text-sm text-red-600 hover:text-red-700">Revoke</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

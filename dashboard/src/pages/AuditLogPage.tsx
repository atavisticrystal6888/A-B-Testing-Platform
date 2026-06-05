import { useState } from 'react';
import { useAuditLogs } from '../hooks/useAuditLogs';
import type { AuditLog } from '../hooks/useAuditLogs';
import { AuditLogEntryComponent } from '../components/admin/AuditLogEntry';

export function AuditLogPage() {
  const [actionFilter, setActionFilter] = useState('');
  const [resourceType, setResourceType] = useState('');
  const { data: auditLogs, isLoading } = useAuditLogs({ action: actionFilter, resource_type: resourceType });

  return (
    <div className="max-w-5xl mx-auto py-8 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Audit Trail</h1>

      <div className="flex gap-3 mb-6">
        <select
          value={resourceType}
          onChange={(e) => setResourceType(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
        >
          <option value="">All Resources</option>
          <option value="experiment">Experiments</option>
          <option value="feature_flag">Feature Flags</option>
          <option value="user">Users</option>
          <option value="api_key">API Keys</option>
        </select>
        <select
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
        >
          <option value="">All Actions</option>
          <option value="create">Create</option>
          <option value="update">Update</option>
          <option value="state_change">State Change</option>
          <option value="conclude">Conclude</option>
          <option value="delete">Delete</option>
        </select>
      </div>

      <div className="rounded-xl border border-gray-200 bg-white overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-gray-500">Loading audit logs...</div>
        ) : auditLogs?.length === 0 ? (
          <div className="p-12 text-center text-gray-500">No audit log entries found.</div>
        ) : (
          auditLogs?.map((entry: AuditLog) => (
            <AuditLogEntryComponent key={entry.id} entry={entry} />
          ))
        )}
      </div>
    </div>
  );
}

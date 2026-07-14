import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ApiKeyManager } from "../components/admin/ApiKeyManager";
import { UserManager } from "../components/admin/UserManager";
import { api } from "../lib/api";
import type { ApiKey, User } from "../lib/types";

type AdminTab = "tenant" | "api-keys" | "users";

interface ApiKeyListResponse {
  data: ApiKey[];
}

interface ApiKeyCreateResponse {
  data: ApiKey;
  message: string;
}

interface UserListResponse {
  data: User[];
}

interface UserResponse {
  data: User;
}

export function AdminSettingsPage() {
  const [tab, setTab] = useState<AdminTab>("tenant");
  const queryClient = useQueryClient();

  const apiKeysQuery = useQuery({
    queryKey: ["api-keys"],
    queryFn: () => api.get<ApiKeyListResponse>("/api/v1/api-keys").then((response) => response.data ?? []),
  });

  const usersQuery = useQuery({
    queryKey: ["users"],
    queryFn: () => api.get<UserListResponse>("/api/v1/users").then((response) => response.data ?? []),
  });

  const generateApiKey = useMutation({
    mutationFn: (name: string) => api.post<ApiKeyCreateResponse>("/api/v1/api-keys", { name }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["api-keys"] }),
  });

  const revokeApiKey = useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/api-keys/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["api-keys"] }),
  });

  const createUser = useMutation({
    mutationFn: ({ email, role, password }: { email: string; role: User["role"]; password: string }) =>
      api.post<UserResponse>("/api/v1/users", { email, role, password }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });

  const updateUserRole = useMutation({
    mutationFn: ({ id, role }: { id: string; role: User["role"] }) =>
      api.put<UserResponse>(`/api/v1/users/${id}`, { role }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });

  const removeUser = useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/users/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });

  const tabs = [
    { key: "tenant", label: "Tenant Info" },
    { key: "api-keys", label: "API Keys" },
    { key: "users", label: "Users" },
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

      {tab === "tenant" && (
        <div className="rounded-xl border border-gray-200 bg-white p-6 space-y-4">
          <h2 className="text-lg font-semibold text-gray-900">Tenant Information</h2>
          <p className="text-sm text-gray-500">
            Tenant profile editing is handled through the tenant settings API. API key and user administration are available in the tabs above.
          </p>
        </div>
      )}

      {tab === "api-keys" && (
        <ApiKeyManager
          apiKeys={apiKeysQuery.data ?? []}
          isLoading={apiKeysQuery.isLoading}
          errorMessage={apiKeysQuery.isError || generateApiKey.isError || revokeApiKey.isError ? "Unable to update API keys right now." : undefined}
          onGenerate={async (name) => {
            const response = await generateApiKey.mutateAsync(name);
            const key = response.data.key;

            if (!key) {
              throw new Error("API did not return the generated key.");
            }

            return { key };
          }}
          onRevoke={(id) => revokeApiKey.mutate(id)}
        />
      )}

      {tab === "users" && (
        <UserManager
          users={usersQuery.data ?? []}
          isLoading={usersQuery.isLoading}
          errorMessage={usersQuery.isError || createUser.isError || updateUserRole.isError || removeUser.isError ? "Unable to update users right now." : undefined}
          onInvite={(email, role, password) => createUser.mutate({ email, role, password })}
          onUpdateRole={(id, role) => updateUserRole.mutate({ id, role })}
          onRemove={(id) => removeUser.mutate(id)}
        />
      )}
    </div>
  );
}

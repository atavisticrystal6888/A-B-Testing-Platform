defmodule ExperimentHub.GDPRTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.GDPR

  describe "export_user_data/2" do
    test "exports data structure with correct fields" do
      tenant_id = Ecto.UUID.generate()
      user_id = "user_123"

      data = GDPR.export_user_data(tenant_id, user_id)

      assert data.user_id == user_id
      assert data.tenant_id == tenant_id
      assert is_list(data.assignments)
      assert is_binary(data.exported_at)
    end
  end
end

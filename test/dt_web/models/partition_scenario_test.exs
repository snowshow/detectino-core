defmodule DtWeb.PartitionScenarioTest do
  use DtWeb.ModelCase

  alias DtWeb.PartitionScenario, as: Mut

  @valid_attrs %{enabled: true, name: "some content"}
  @valid_modes ["ARM", "ARMSTAY", "ARMSTAYIMMEDIATE", "DISARM", "NONE"]
  @some_invalid_modes ["42", "STAY", "WHATEVER", 1, "EOF"]

  test "allow valid insert mode" do
    @valid_modes
    |> Enum.each(fn(mode) ->
      attrs = %{mode: mode, partition_id: 1, scenario_id: 1}
      changeset = Mut.create_changeset(%Mut{}, attrs)
      assert changeset.valid?
      end)
  end

  test "block valid insert mode" do
    @some_invalid_modes
    |> Enum.each(fn(mode) ->
      attrs = %{mode: mode, partition_id: 1, scenario_id: 1}
      changeset = Mut.create_changeset(%Mut{}, attrs)
      refute changeset.valid?
      end)
  end

end

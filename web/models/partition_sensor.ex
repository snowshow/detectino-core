defmodule DtWeb.PartitionSensor do
  use DtWeb.Web, :model

  schema "partitions_sensors" do
    belongs_to :partition, Partition
    belongs_to :sensor, Sensor

    timestamps()
  end

  @required_fields ~w(partition_id sensor_id)
  @validate_required Enum.map(@required_fields, fn(x) -> String.to_atom(x) end)

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields)
    |> validate_required(@validate_required)
  end
end

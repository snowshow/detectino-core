defmodule DtWeb.PartitionSensorController do
  use DtWeb.Web, :controller
  use DtWeb.CrudMacros, [repo: DtWeb.Repo, model: DtWeb.Partition]

  alias DtWeb.SessionController
  alias DtWeb.Plugs.CoreReloader
  alias Guardian.Plug.EnsureAuthenticated

  plug EnsureAuthenticated, [handler: SessionController]
  plug CoreReloader, nil when not action in [:index, :show]

end

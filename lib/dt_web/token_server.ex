defmodule DtWeb.TokenServer do
  @moduledoc """
  Simple memory storage for tokens
  """
  use GenServer

  require Logger

  # Client APIs
  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, {}, name: name)
  end

  def put(token) do
    GenServer.call(__MODULE__, {:put, token})
  end

  def get(token) do
    GenServer.call(__MODULE__, {:get, token})
  end

  def delete(token) do
    GenServer.call(__MODULE__, {:delete, token})
  end

  def all() do
    GenServer.call(__MODULE__, {:all})
  end

  # GenServer callbacks
  def init(_) do
    state = %{}
    {:ok, state}
  end

  def handle_call({:all}, _from, state) do
    {:reply, Map.keys(state), state}
  end

  def handle_call({:put, token}, _from, state) do
    now = DateTime.utc_now()
    state = Map.put(state, token, now)
    {:reply, {:ok, token}, state}
  end

  def handle_call({:get, token}, _from, state) do
    res = case Map.get(state, token) do
      nil -> {:error, :not_found}
      _ -> {:ok, token}
    end
    {:reply, res, state}
  end

  def handle_call({:delete, token}, _from, state) do
    {:reply, :ok, Map.delete(state, token)}
  end
end

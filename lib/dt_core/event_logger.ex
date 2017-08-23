defmodule DtCore.EventLogger do
  @moduledoc """
  Module responsible of receiving events and logging to database and files
  """
  use GenServer

  alias DtCore.EventBridge
  alias DtCore.ArmEv
  alias DtCore.DetectorEv
  alias DtCore.DetectorExitEv
  alias DtCore.DetectorEntryEv
  alias DtCore.PartitionEv
  alias DtCore.ExitTimerEv
  alias DtCtx.Outputs.EventLog
  alias DtCtx.Repo

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info "Starting Event Logger"
    EventBridge.start_listening(fn ev -> filter(ev) end)
    {:ok, nil}
  end

  def handle_info({:bridge_ev, _, {op, ev = %ArmEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "arm", operation: operation, details: ev}
    |> save_eventlog()

    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {op, ev = %ExitTimerEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "exit_timer", operation: operation, details: ev}
    |> save_eventlog()

    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {_, %DetectorEv{type: :reading}}}, state) do
    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {op, ev = %DetectorEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "alarm", operation: operation, details: ev}
    |> save_eventlog()

    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {op, ev = %DetectorExitEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "detector_exit", operation: operation, details: ev}
    |> save_eventlog()

    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {op, ev = %DetectorEntryEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "detector_entry", operation: operation, details: ev}
    |> save_eventlog()

    {:noreply, state}
  end

  def handle_info({:bridge_ev, _, {op, ev = %PartitionEv{}}}, state) do
    operation = Atom.to_string(op)
    %{type: "alarm", operation: operation, details: ev} |> save_eventlog()
    {:noreply, state}
  end

  def filter({_, {_, %ArmEv{}}}) do
    true
  end

  def filter({_, {_, %DetectorEv{}}}) do
    true
  end

  def filter({_, {_, %DetectorExitEv{}}}) do
    true
  end

  def filter({_, {_, %DetectorEntryEv{}}}) do
    true
  end

  def filter({_, {_, %PartitionEv{}}}) do
    true
  end

  def filter({_, {_, %ExitTimerEv{}}}) do
    true
  end

  defp save_eventlog(params) do
    %EventLog{}
    |> EventLog.create_changeset(params)
    |> Repo.insert!
  end

end

defmodule DtCore.Test.Output.Worker do
  use DtCore.EctoCase

  alias DtCore.Sup
  alias DtWeb.Output, as: OutputModel
  alias DtWeb.Event, as: EventModel
  alias DtWeb.EmailSettings, as: EmailSettingsModel
  alias DtWeb.BusSettings, as: BusSettingsModel
  alias DtCore.OutputsRegistry
  alias DtCore.Output.Worker
  alias DtCore.Test.TimerHelper
  alias DtCore.SensorEv
  alias DtCore.PartitionEv
  alias Swoosh.Email
  alias DtCore.Output.Actions.Email, as: EmailConfig

  setup_all do
    :meck.new(Etimer, [:passthrough])
    :meck.expect(Etimer, :start_timer,
      fn(_ ,_ ,_ ,_ ) ->
        0
      end)
  end

  setup do
    {:ok, _pid} = Sup.start_link

    on_exit fn ->
      TimerHelper.wait_until fn ->
        assert Process.whereis(:output_server) == nil
        assert Process.whereis(Sup) == nil
      end
    end

    :ok
  end

  test "disabled worker does not listens to associated events" do
    events = [
      %EventModel{
        source: "partition",
        source_config: Poison.encode!(%{
          name: "area one", type: "alarm"
        })
      },
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{name: "another output", events: events, enabled: false}

    {:ok, pid} = Worker.start_link({output})

    listeners = Registry.keys(OutputsRegistry.registry, pid)
    assert Enum.count(listeners) == 0
  end

  test "worker listens to associated events" do
    events = [
      %EventModel{
        source: "partition",
        source_config: Poison.encode!(%{
          name: "area one", type: "alarm"
        })
      },
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{name: "an output", events: events, enabled: true}

    {:ok, pid} = Worker.start_link({output})

    listeners = Registry.keys(OutputsRegistry.registry, pid)
    assert Enum.count(listeners) == 2

    key = %{source: :partition, name: "area one", type: :alarm}
    listeners = Registry.lookup(OutputsRegistry.registry, key)
    assert Enum.count(listeners) == 1

    key = %{source: :sensor, address: "10", port: 5, type: :alarm}
    listeners = Registry.lookup(OutputsRegistry.registry, key)
    assert Enum.count(listeners) == 1
  end

  test "emails are sent after an alarm event" do
    events = [
      %EventModel{
        source: "partition",
        source_config: Poison.encode!(%{
          name: "area one", type: "alarm"
        })
      },
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{
      name: "email test output",
      events: events,
      type: "email",
      enabled: true,
      email_settings: %EmailSettingsModel{
        to: "test@example.com",
        from: "bob@example.com"
      }
    }

    # testing the server callbacks here
    # since the swoosh test adapter sends
    # emails to the current process
    {:ok, state} = Worker.init({output})

    s_ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    p_ev = {:start, %PartitionEv{type: :alarm, name: "area one"}}
    s_ev_end = {:stop, %SensorEv{type: :alarm, address: "10", port: 5}}
    p_ev_end = {:stop, %PartitionEv{type: :alarm, name: "area one"}}

    s_ev_delayed = {:start,
      %SensorEv{type: :alarm, address: "10", port: 5, delayed: true}}

    Worker.handle_info(s_ev, state)
    get_subject(:sensor_start) |> assert_email

    Worker.handle_info(p_ev, state)
    get_subject(:partition_start) |> assert_email

    Worker.handle_info(s_ev_end, state)
    get_subject(:sensor_end) |> assert_email

    Worker.handle_info(p_ev_end, state)
    get_subject(:partition_end) |> assert_email

    Worker.handle_info(s_ev_delayed, state)
    get_delayed_subject(:sensor_start) |> assert_email(true)
  end

  test "monostable output on time" do
    events = [
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{
      name: "an output",
      events: events,
      enabled: true,
      type: "bus",
      bus_settings: %BusSettingsModel{
        type: "monostable",
        mono_ontime: 30,
        address: "addr", port: 42
      }
    }
    {:ok, pid} = Worker.start_link({output})
    assert :meck.called(Etimer, :start_link, :_)

    DtBus.ActionRegistry.registry
    |> Registry.register(:bus_commands, [])

    ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])

    %DtBus.OutputAction{
      command: :on,
      address: "addr", port: 42
    }
    |> assert_receive(5000)

    TimerHelper.wait_until fn ->
      assert :meck.called(
        Etimer, :start_timer,
        [:_, :_, 30000, {Worker, :timer_expiry, [:mono_expiry, output]}])
    end

    # a stop event should do nothing
    ev = {:stop, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])
    _msg |> refute_receive(1000)

    Worker.timer_expiry({:mono_expiry, output})

    %DtBus.OutputAction{
      command: :off,
      address: "addr", port: 42
    }
    |> assert_receive(5000)

  end

  test "monostable output off time" do
    events = [
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{
      name: "an output",
      events: events,
      enabled: true,
      type: "bus",
      bus_settings: %BusSettingsModel{
        type: "monostable",
        mono_ontime: 30,
        mono_offtime: 120,
        address: "addr", port: 42
      }
    }
    {:ok, pid} = Worker.start_link({output})
    assert :meck.called(Etimer, :start_link, :_)

    DtBus.ActionRegistry.registry
    |> Registry.register(:bus_commands, [])

    ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])

    %DtBus.OutputAction{
      command: :on,
      address: "addr", port: 42
    }
    |> assert_receive(5000)

    TimerHelper.wait_until fn ->
      assert :meck.called(
        Etimer, :start_timer,
        [:_, :_, 30000, {Worker, :timer_expiry, [:mono_expiry, output]}])
    end

    Worker.timer_expiry({:mono_expiry, output})

    %DtBus.OutputAction{
      command: :off,
      address: "addr", port: 42
    }
    |> assert_receive(5000)

    TimerHelper.wait_until fn ->
      assert :meck.called(
        Etimer, :start_timer,
        [:_, :_, 120000, {Worker, :timer_expiry, [:mono_off_expiry, output]}])
    end

    # now another event should not run because we're in offtime
    ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])
    %DtBus.OutputAction{}
    |> refute_receive(1000)

    Worker.timer_expiry({:mono_off_expiry, output})

    ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])
    %DtBus.OutputAction{}
    |> assert_receive(1000)
  end

  test "bistable output" do
    events = [
      %EventModel{
        source: "sensor",
        source_config: Poison.encode!(%{
          address: "10", port: 5, type: "alarm"
        })
      }
    ]
    output = %OutputModel{
      name: "an output",
      events: events,
      enabled: true,
      type: "bus",
      bus_settings: %BusSettingsModel{
        type: "bistable",
        mono_ontime: 1,
        mono_offtime: 120,
        address: "addr", port: 42
      }
    }
    {:ok, pid} = Worker.start_link({output})
    assert :meck.called(Etimer, :start_link, :_)

    DtBus.ActionRegistry.registry
    |> Registry.register(:bus_commands, [])

    ev = {:start, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])

    %DtBus.OutputAction{
      command: :on,
      address: "addr", port: 42
    }
    |> assert_receive(5000)

    TimerHelper.wait_until fn ->
      refute :meck.called(
        Etimer, :start_timer,
        [:_, :_, 1000, {Worker, :timer_expiry, [:mono_expiry, output]}])
    end

    %DtBus.OutputAction{
      command: :off,
      address: "addr", port: 42
    }
    |> refute_receive(1000)

    TimerHelper.wait_until fn ->
      refute :meck.called(
        Etimer, :start_timer,
        [:_, :_, 120000, {Worker, :timer_expiry, [:mono_off_expiry, output]}])
    end

    ev = {:stop, %SensorEv{type: :alarm, address: "10", port: 5}}
    Process.send(pid, ev, [])

    %DtBus.OutputAction{
      command: :off,
      address: "addr", port: 42
    }
    |> assert_receive(5000)
  end

  defp assert_email(subject, delayed \\ false) do
    assert_received {
      :email,
      %Email{
        subject: ^subject,
        private: %{
          delayed_event: ^delayed
        }
      }
    }
  end

  defp get_subject(which) when is_atom(which) do
    :detectino
    |> Application.get_env(EmailConfig)
    |> Keyword.get(:alarm_subjects)
    |> Map.get(which)
  end

  defp get_delayed_subject(which) when is_atom(which) do
    :detectino
    |> Application.get_env(EmailConfig)
    |> Keyword.get(:delayed_alarm_subjects)
    |> Map.get(which)
  end

end

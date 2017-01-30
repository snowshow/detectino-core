defmodule DtCore.Test.EventBridgeTest do
  use ExUnit.Case, async: false

  alias DtCore.EventBridge

  setup_all do
    {:ok, _} = Registry.start_link(:duplicate, DtCore.OutputsRegistry.registry)
    :ok
  end

  test "subscribe and receives a message" do
    {:ok, _pid} = EventBridge.start_link()

    EventBridge.start_listening()

    key = %{"some" => "key"}
    EventBridge.dispatch(key, 42)

    assert_receive {:bridge_ev, ^key, 42}
  end

  test "subscribe and receives a message, with filter" do
    {:ok, _pid} = EventBridge.start_link()

    EventBridge.start_listening(fn({key, _payload}) ->
      case key do
        %{"passes" => true} ->
          true
        _ ->
          false
      end
    end)

    key = %{"some" => "key"}
    EventBridge.dispatch(key, 42)
    refute_receive _, 100

    key = %{"passes" => true}
    EventBridge.dispatch(key, 42)
    assert_receive {:bridge_ev, ^key, 42}
  end

  test "unsubscribe a not subscribed" do
    {:ok, _pid} = EventBridge.start_link()
    {:ok, pid} = EventBridge.stop_listening()
    assert pid == self()
  end

end

defmodule Koikoi.Shokai.ExpirationWorker do
  @moduledoc "Periodically expires stale shokai cards."
  use GenServer

  @check_interval :timer.minutes(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_check()
    {:ok, state}
  end

  @impl true
  def handle_info(:check_expirations, state) do
    Koikoi.Shokai.expire_stale()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_expirations, @check_interval)
  end
end

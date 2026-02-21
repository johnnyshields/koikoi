defmodule Koikoi.Matching.MatchExpirationWorker do
  @moduledoc "Periodically expires pending matches that have passed their deadline."

  use GenServer

  alias Koikoi.Repo

  @matches_collection "matches"
  @check_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_expired, state) do
    expire_matches()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_expired, @check_interval)
  end

  defp expire_matches do
    now = DateTime.utc_now()

    Repo.update_many(
      @matches_collection,
      %{
        "status" => "pending_intro",
        "expires_at" => %{"$lte" => now},
        "$or" => [
          %{"person_a_response" => nil},
          %{"person_b_response" => nil}
        ]
      },
      %{"$set" => %{"status" => "expired", "updated_at" => now}}
    )
  end
end

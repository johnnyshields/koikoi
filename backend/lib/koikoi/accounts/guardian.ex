defmodule Koikoi.Accounts.Guardian do
  use Guardian, otp_app: :koikoi

  alias Koikoi.Accounts

  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(%{"_id" => id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :unhandled_resource}

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_), do: {:error, :unhandled_claims}
end

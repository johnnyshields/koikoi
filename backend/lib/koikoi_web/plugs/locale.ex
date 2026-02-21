defmodule KoikoiWeb.Plugs.Locale do
  import Plug.Conn

  @supported_locales ["ja", "en"]
  @default_locale "ja"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn
      |> get_req_header("accept-language")
      |> parse_locale()

    Gettext.put_locale(KoikoiWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  defp parse_locale([header | _]) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&extract_lang/1)
    |> Enum.find(@default_locale, &(&1 in @supported_locales))
  end

  defp parse_locale(_), do: @default_locale

  defp extract_lang(lang_str) do
    lang_str
    |> String.split(";")
    |> List.first()
    |> String.split("-")
    |> List.first()
    |> String.downcase()
  end
end

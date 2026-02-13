defmodule TdLmWeb.SearchView do
  use TdLmWeb, :view

  alias TdCache.I18nCache

  def render("show.json", %{results: results, scroll_id: scroll_id} = assigns) do
    {:ok, default_lang} = I18nCache.get_default_locale()
    locale = assigns[:locale]
    locale = if is_nil(locale) or locale == default_lang, do: nil, else: locale

    %{
      data: render_many(results, __MODULE__, "result.json", as: :result, locale: locale),
      scroll_id: scroll_id
    }
  end

  def render("show.json", %{results: results} = assigns) do
    {:ok, default_lang} = I18nCache.get_default_locale()
    locale = assigns[:locale] || default_lang

    %{data: render_many(results, __MODULE__, "result.json", as: :result, locale: locale)}
  end

  def render("show.json", %{filters: filters, scroll_id: scroll_id}) do
    %{data: filters, scroll_id: scroll_id}
  end

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end

  def render("result.json", %{result: result} = assigns) do
    i18n_data(result, assigns[:locale])
  end

  defp i18n_data(%{"source_type" => "business_concept"} = result, locale) do
    result
    |> Map.delete("source_type")
    |> i18n_data(locale)
    |> i18n_property("source_name", locale)
    |> Map.update("source_data", %{}, fn data -> add_content_for_locale(data, locale) end)
    |> Map.put("source_type", "business_concept")
  end

  defp i18n_data(%{"target_type" => "business_concept"} = result, locale) do
    result
    |> Map.delete("target_type")
    |> i18n_data(locale)
    |> i18n_property("target_name", locale)
    |> Map.update("target_data", %{}, fn data -> add_content_for_locale(data, locale) end)
    |> Map.put("target_type", "business_concept")
  end

  defp i18n_data(result, _locale), do: result

  defp i18n_property(result, property, locale) do
    default_value = Map.get(result, property)
    value = Map.get(result, "#{property}_#{locale}", default_value)

    Map.put(result, property, value)
  end

  defp add_content_for_locale(%{"content" => content} = data, locale) when is_map(content) do
    default_content =
      Map.reject(content, fn {key, _value} -> String.match?(key, ~r/_[a-z]{2}$/) end)

    if is_nil(locale) do
      Map.put(data, "content", default_content)
    else
      suffix = "_#{locale}"

      i18n_content =
        content
        |> Map.filter(fn {key, _value} -> String.ends_with?(key, suffix) end)
        |> Map.new(fn {key, value} -> {String.replace_suffix(key, suffix, ""), value} end)

      Map.put(data, "content", Map.merge(default_content, i18n_content))
    end
  end

  defp add_content_for_locale(data, _locale), do: data
end

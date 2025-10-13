defmodule TdLmWeb.BulkUpdateStatusView do
  use TdLmWeb, :view

  def render("update_status.json", %{
        update_results: %{relations_updated: relations_updated, errors: errors}
      }) do
    %{
      data: %{
        relations: render_many(relations_updated, __MODULE__, "relation.json", as: :relation),
        errors: render_one(errors, __MODULE__, "errors.json", as: :errors)
      }
    }
  end

  def render("relation.json", %{relation: relation}) do
    Map.take(relation, [
      :id,
      :status,
      :source_id,
      :source_type,
      :target_id,
      :target_type
    ])
    |> maybe_put_tag_type(relation)
    |> Map.put(:source_name, relation.source_data.name)
    |> Map.put(:target_name, relation.target_data.name)
  end

  def render("errors.json", %{errors: errors}) do
    errors
    |> render_many(__MODULE__, "error.json", as: :error)
    |> group_errors()
    |> Map.new()
  end

  def render("error.json", %{error: {relation, errors}}) do
    {reason, {message, _}} =
      errors |> List.first()

    relation
    |> Map.take([
      :id,
      :source_id,
      :source_type,
      :target_id,
      :target_type
    ])
    |> maybe_put_tag_type(relation)
    |> Map.put(:source_name, relation.source_data.name)
    |> Map.put(:target_name, relation.target_data.name)
    |> Map.put(:error, %{reason: reason, message: message})
  end

  defp maybe_put_tag_type(map, %{tag: %{value: %{"type" => type}}}),
    do: Map.put(map, :tag_type, type)

  defp maybe_put_tag_type(map, _), do: map

  defp group_errors(errors) do
    errors
    |> Enum.group_by(fn %{error: %{reason: reason}} -> reason end)
    |> Enum.map(&format_error_group/1)
  end

  defp format_error_group({groupKey, relations}) do
    reason = relations |> List.first() |> Map.get(:error) |> Map.get(:reason)
    message = relations |> List.first() |> Map.get(:error) |> Map.get(:message)

    relations =
      Enum.map(relations, fn relation ->
        Map.drop(relation, [:error])
      end)

    {groupKey,
     %{
       reason: reason,
       message: message,
       relations: relations
     }}
  end
end

defmodule TdLm.Xlsx.Reader do
  @moduledoc """
  Module for reading and processing XLSX files containing link metadata.

  This module provides functionality to:
  - Read XLSX files containing link information between different entities
  - Process the file contents into a structured format
  - Map column headers to appropriate parameters
  - Handle different entity types (business concepts, data structures, tags)
  """

  require Logger

  @required_headers ["concept_name", "structure_external_id", "domain_external_id", "link_type"]

  @excel_columns_by_type %{
    "business_concept" => "concept_name",
    "data_structure" => "structure_external_id"
  }

  def process_file(%{"path" => path, "source" => source, "target" => target}, _opts) do
    with {:ok, pid} <- XlsxReader.open(path),
         {:ok, sheets} <- XlsxReader.sheets(pid),
         [headers | data_rows] <-
           Enum.flat_map(sheets, fn {_sheet_name, sheet_data} -> sheet_data end) do
      if Enum.all?(@required_headers, &Enum.member?(headers, &1)) do
        data_rows
        |> Enum.with_index(2)
        |> Enum.map(fn {row, row_number} ->
          prepare_data(row_number, row, headers, source, target)
        end)
        |> Enum.reject(&(&1 == %{}))
        |> then(&{:ok, &1})
      else
        {:error, :invalid_headers}
      end
    else
      error ->
        error
    end
  end

  defp prepare_data(_row_number, [], _header, _source, _target), do: %{}
  defp prepare_data(_row_number, _row, [], _source, _target), do: %{}

  defp prepare_data(row_number, row, header, source, target) do
    header
    |> Enum.zip(row)
    |> Enum.into(%{})
    |> Map.take(@required_headers)
    |> Map.put("row_number", row_number)
    |> Map.put("source_type", source)
    |> get_search_param(source, "source_param")
    |> Map.put("source_status", nil)
    |> Map.put("target_type", target)
    |> add_tag_target_type(target)
    |> get_search_param(target, "target_param")
    |> Map.put("target_status", nil)
    |> Map.put("error", nil)
  end

  defp get_search_param(params, type, relation_param_side) do
    value =
      params
      |> Map.get(@excel_columns_by_type[type], "")
      |> clean_string()

    Map.put(params, relation_param_side, value)
  end

  defp clean_string(text) do
    text
    |> String.trim()
    |> String.replace(~r/\\\"/, "\"")
  end

  defp add_tag_target_type(params, "business_concept"),
    do: Map.put(params, "tag_target_type", "business_concept")

  defp add_tag_target_type(params, "data_structure"),
    do: Map.put(params, "tag_target_type", "data_field")

  defp add_tag_target_type(params, _), do: Map.put(params, "tag_target_type", nil)
end

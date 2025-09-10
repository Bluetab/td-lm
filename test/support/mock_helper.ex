defmodule TdLm.MockHelper do
  @moduledoc """
  Helper module for mocking external service calls in tests.

  Provides functions to:
  - Mock business concept lookups
  - Mock data structure lookups
  - Mock event creation
  - Handle test file loading
  """

  use TdLm.DataCase

  alias TdCluster.TestHelpers.TdBgMock
  alias TdCluster.TestHelpers.TdDdMock

  def business_concept_mock(name, domain_id, result) do
    TdBgMock.get_concept_by_name_in_domain(&Mox.expect/4, name, domain_id, result)
  end

  def data_structure_mock(external_id, result) do
    TdDdMock.get_data_structure_by_external_id(
      &Mox.expect/4,
      external_id,
      :latest_version,
      result
    )
  end

  def event_mock(params) do
    result =
      {:ok,
       %{
         status: params.status,
         user_id: params.user_id,
         file_hash: params.file_hash,
         task_reference: Map.get(params, :task_reference)
       }}

    TdBgMock.create_bulk_upload_event(&Mox.expect/4, params, {:ok, result})
  end

  def load_excel(path, test_pid) do
    subfolder =
      test_pid
      |> :erlang.pid_to_list()
      |> List.delete_at(0)
      |> List.delete_at(-1)
      |> to_string()

    parent_dir = Path.join(["test", subfolder])

    File.mkdir_p!(parent_dir)

    file_name = Path.basename(path)
    tmp_path = Path.join([parent_dir, file_name])
    File.cp_r!(path, tmp_path)

    on_exit(fn ->
      File.rm_rf!(parent_dir)
    end)

    [
      tmp_path: tmp_path,
      file_name: file_name,
      parent_dir: parent_dir
    ]
  end

  def create_mock_data(opts \\ []) do
    opts_map = Enum.into(opts, %{})

    %{
      opts: opts_map
    }
    |> maybe_create_claims()
    |> maybe_create_domain()
    |> maybe_create_tag()
    |> maybe_create_concept()
    |> maybe_create_data_structure()
  end

  defp maybe_create_claims(%{opts: %{claims: claims_params}} = acc) when is_list(claims_params) do
    claims = build(:claims, claims_params)
    Map.put(acc, :claims, claims)
  end

  defp maybe_create_claims(acc), do: acc

  defp maybe_create_domain(%{opts: %{domain: domain_params}} = acc) when is_list(domain_params) do
    domain = CacheHelpers.put_domain(domain_params)

    Map.put(acc, :domain, domain)
  end

  defp maybe_create_domain(acc), do: acc

  defp maybe_create_tag(%{opts: %{tag: tag_params}} = acc) when is_list(tag_params) do
    tag = insert(:tag, tag_params)

    Map.put(acc, :tag, tag)
  end

  defp maybe_create_tag(acc), do: acc

  defp maybe_create_concept(
         %{opts: %{concept: concept_params}, domain: %{id: domain_id} = domain} = acc
       )
       when is_list(concept_params) do
    params = concept_params ++ [domain_id: domain_id, domain: domain]

    concept = CacheHelpers.put_concept(params)

    Map.put(acc, :concept, concept)
  end

  defp maybe_create_concept(acc), do: acc

  defp maybe_create_data_structure(
         %{opts: %{structure: structure_params}, domain: %{id: domain_id} = domain} = acc
       )
       when is_list(structure_params) do
    params = structure_params ++ [domain_id: domain_id, domain: domain, domain_ids: [domain_id]]

    ds = build(:data_structure, params)

    Map.put(acc, :data_structure, ds)
  end

  defp maybe_create_data_structure(acc), do: acc
end

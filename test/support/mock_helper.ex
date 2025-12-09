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

  def business_concept_mock(name, domain_id, concept_type, result) do
    TdBgMock.get_unique_concept(&Mox.expect/4, name, domain_id, concept_type, result)
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

  def setup_cluster_stub(opts) do
    concept_name = Keyword.get(opts, :concept_name)
    domain_id = Keyword.get(opts, :domain_id)
    concept_type = Keyword.get(opts, :concept_type)
    concept = Keyword.get(opts, :concept)
    data_structure_external_id = Keyword.get(opts, :data_structure_external_id)
    data_structure = Keyword.get(opts, :data_structure)

    Mox.stub(MockClusterHandler, :call, fn service, module, function, args ->
      handle_cluster_call(
        {service, module, function, args},
        concept_name,
        domain_id,
        concept_type,
        concept,
        data_structure_external_id,
        data_structure
      )
    end)
  end

  defp handle_cluster_call(
         {:bg, TdBg.BusinessConcepts.BulkUploadEvents, :create_bulk_upload_event, [arg_event]},
         _concept_name,
         _domain_id,
         _concept_type,
         _concept,
         _data_structure_external_id,
         _data_structure
       ) do
    {:ok,
     %{
       status: arg_event.status,
       user_id: arg_event.user_id,
       file_hash: arg_event.file_hash,
       task_reference: Map.get(arg_event, :task_reference)
     }}
  end

  defp handle_cluster_call(
         {:bg, TdBg.BusinessConcepts, :get_unique_concept, [arg_name, arg_domain_id, arg_concept_type]},
         concept_name,
         domain_id,
         concept_type,
         concept,
         _data_structure_external_id,
         _data_structure
       )
       when not is_nil(concept_name) do
    handle_get_unique_concept(arg_name, arg_domain_id, arg_concept_type, concept_name, domain_id, concept_type, concept)
  end

  defp handle_cluster_call(
         {:dd, TdDd.DataStructures, :get_data_structure_by_external_id, [arg_external_id, arg_preload]},
         _concept_name,
         _domain_id,
         _concept_type,
         _concept,
         data_structure_external_id,
         data_structure
       )
       when not is_nil(data_structure_external_id) do
    handle_get_data_structure(arg_external_id, arg_preload, data_structure_external_id, data_structure)
  end

  defp handle_cluster_call(other, _concept_name, _domain_id, _concept_type, _concept, _data_structure_external_id, _data_structure) do
    raise "Unexpected call: #{inspect(other)}"
  end

  defp handle_get_unique_concept(arg_name, arg_domain_id, arg_concept_type, concept_name, domain_id, concept_type, concept) do
    if arg_name == concept_name and arg_domain_id == domain_id and arg_concept_type == concept_type do
      {:ok, concept}
    else
      raise "Unexpected get_unique_concept call: name=#{arg_name}, domain_id=#{arg_domain_id}, concept_type=#{inspect(arg_concept_type)}"
    end
  end

  defp handle_get_data_structure(arg_external_id, arg_preload, data_structure_external_id, data_structure) do
    if arg_external_id == data_structure_external_id and arg_preload == :latest_version do
      {:ok, data_structure}
    else
      raise "Unexpected get_data_structure_by_external_id call: external_id=#{arg_external_id}, preload=#{inspect(arg_preload)}"
    end
  end

  def setup_cluster_stub_with_multiple_concept_types(opts) do
    concept_name = Keyword.get(opts, :concept_name)
    domain_id = Keyword.get(opts, :domain_id)
    concept_type_fn = Keyword.get(opts, :concept_type_fn)
    data_structure_external_id = Keyword.get(opts, :data_structure_external_id)
    data_structure = Keyword.get(opts, :data_structure)

    Mox.stub(MockClusterHandler, :call, fn service, module, function, args ->
      case {service, module, function, args} do
        {:bg, TdBg.BusinessConcepts, :get_unique_concept,
         [arg_name, arg_domain_id, arg_concept_type]}
        when arg_name == concept_name and arg_domain_id == domain_id ->
          concept_type_fn.(arg_concept_type)

        {:dd, TdDd.DataStructures, :get_data_structure_by_external_id,
         [arg_external_id, arg_preload]}
        when not is_nil(data_structure_external_id) and
               arg_external_id == data_structure_external_id and arg_preload == :latest_version ->
          {:ok, data_structure}

        other ->
          raise "Unexpected call: #{inspect(other)}"
      end
    end)
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

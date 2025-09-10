defmodule TdLmWeb.XlsxControllerTest do
  use Oban.Testing, repo: TdLm.Repo, prefix: Application.get_env(:td_lm, Oban)[:prefix]
  use TdLmWeb.ConnCase

  alias TdCore.Utils.FileHash
  alias TdLm.MockHelper
  alias TdLm.Resources
  alias TdLm.XLSX.Jobs.UploadWorker

  @moduletag sandbox: :shared
  @file_upload_dir "tmp"
  setup_all do
    start_supervised!(TdLm.Cache.LinkLoader)
    start_supervised({Task.Supervisor, name: TdLm.TaskSupervisor})
    on_exit(fn -> File.rm_rf(@file_upload_dir) end)
    :ok
  end

  setup %{conn: conn} do
    [
      conn: put_req_header(conn, "accept", "application/json")
    ]
  end

  @tag authentication: [role: "admin"]
  test "created relations wiht valid data", %{
    conn: conn,
    claims: claims
  } do
    file = "test/fixtures/bulk_relations_test.xlsx"

    hash = FileHash.hash(file, :md5)

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "PENDING",
      file_hash: hash,
      filename: "bulk_relations_test.xlsx",
      task_reference: "oban:1"
    })

    %{
      domain: %{id: domain_id},
      concept: %{id: concept_id, name: concept_name} = concept,
      data_structure:
        %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
      tag: %{id: tag_id}
    } =
      MockHelper.create_mock_data(
        claims: claims,
        domain: [external_id: "foo_domain"],
        concept: [
          name: "foo",
          versions: [%{status: "published", version: 1}]
        ],
        structure: [
          external_id: "bar",
          latest_version: %{deleted_at: nil}
        ],
        tag: [value: %{"type" => "foo_bar_link", "target_type" => "data_field"}]
      )

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "STARTED",
      file_hash: hash,
      filename: file
    })

    MockHelper.business_concept_mock(concept_name, domain_id, {:ok, concept})
    MockHelper.data_structure_mock(data_structure_external_id, {:ok, data_structure})

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "COMPLETED",
      file_hash: hash,
      filename: file
    })

    assert %{"file_hash" => ^hash, "status" => "PENDING", "task_reference" => _} =
             conn
             |> post(
               Routes.xlsx_path(conn, :upload),
               %{
                 "source" => "business_concept",
                 "target" => "data_structure",
                 "relations" => upload(file)
               }
             )
             |> json_response(:accepted)

    opts = %{
      "claims" => %{
        "user_id" => claims.user_id,
        "user_name" => claims.user_name,
        "jti" => claims.jti,
        "role" => claims.role
      },
      "user_id" => claims.user_id
    }

    relation_params =
      %{
        "filename" => "bulk_relations_test.xlsx",
        "hash" => hash,
        "path" => "tmp/xlsx_uploads/#{hash}.xlsx",
        "source" => "business_concept",
        "target" => "data_structure"
      }

    assert_enqueued(
      worker: UploadWorker,
      args: %{"opts" => opts, "relation_params" => relation_params},
      queue: :xlsx_upload_queue
    )

    assert {:ok, _} =
             perform_job(UploadWorker, %{"opts" => opts, "relation_params" => relation_params})

    assert [
             %{
               source_id: ^concept_id,
               source_type: "business_concept",
               target_id: ^data_structure_id,
               target_type: "data_structure",
               tag_id: ^tag_id
             }
           ] =
             Resources.list_relations()
  end

  @tag authentication: [role: "user"]
  test "user with permissions can create relations wiht valid data", %{
    conn: conn,
    claims: claims
  } do
    file = "test/fixtures/bulk_relations_test.xlsx"

    hash = FileHash.hash(file, :md5)

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "PENDING",
      file_hash: hash,
      filename: "bulk_relations_test.xlsx",
      task_reference: "oban:1"
    })

    %{
      domain: %{id: domain_id},
      concept: %{id: concept_id, name: concept_name} = concept,
      data_structure:
        %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
      tag: %{id: tag_id}
    } =
      MockHelper.create_mock_data(
        claims: claims,
        domain: [external_id: "foo_domain"],
        concept: [
          name: "foo",
          versions: [%{status: "published", version: 1}]
        ],
        structure: [
          external_id: "bar",
          latest_version: %{deleted_at: nil}
        ],
        tag: [value: %{"type" => "foo_bar_link", "target_type" => "data_field"}]
      )

    CacheHelpers.put_session_permissions(claims, domain_id, [
      :manage_business_concept_links,
      :link_data_structure,
      :view_data_structure
    ])

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "STARTED",
      file_hash: hash,
      filename: file
    })

    MockHelper.business_concept_mock(concept_name, domain_id, {:ok, concept})
    MockHelper.data_structure_mock(data_structure_external_id, {:ok, data_structure})

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "COMPLETED",
      file_hash: hash,
      filename: file
    })

    assert %{"file_hash" => ^hash, "status" => "PENDING", "task_reference" => _} =
             conn
             |> post(
               Routes.xlsx_path(conn, :upload),
               %{
                 "source" => "business_concept",
                 "target" => "data_structure",
                 "relations" => upload(file)
               }
             )
             |> json_response(:accepted)

    opts = %{
      "claims" => %{
        "user_id" => claims.user_id,
        "user_name" => claims.user_name,
        "jti" => claims.jti,
        "role" => claims.role
      },
      "user_id" => claims.user_id
    }

    relation_params =
      %{
        "filename" => "bulk_relations_test.xlsx",
        "hash" => hash,
        "path" => "tmp/xlsx_uploads/#{hash}.xlsx",
        "source" => "business_concept",
        "target" => "data_structure"
      }

    assert_enqueued(
      worker: UploadWorker,
      args: %{"opts" => opts, "relation_params" => relation_params},
      queue: :xlsx_upload_queue
    )

    assert {:ok, _} =
             perform_job(UploadWorker, %{"opts" => opts, "relation_params" => relation_params})

    assert [
             %{
               source_id: ^concept_id,
               source_type: "business_concept",
               target_id: ^data_structure_id,
               target_type: "data_structure",
               tag_id: ^tag_id
             }
           ] =
             Resources.list_relations()
  end

  @tag authentication: [role: "non-admin"]
  test "non-admin with out permissions return forbidden", %{
    conn: conn
  } do
    excel_name = "test/fixtures/bulk_relations_test.xlsx"

    assert conn
           |> post(
             Routes.xlsx_path(conn, :upload),
             %{
               "source" => "business_concept",
               "target" => "data_structure",
               "relations" => upload(excel_name)
             }
           )
           |> json_response(:forbidden)
  end

  @tag authentication: [role: "admin"]
  test "return error if header is invalid", %{
    conn: conn,
    claims: claims
  } do
    file = "test/fixtures/bulk_relations_error_header_test.xlsx"

    hash = FileHash.hash(file, :md5)

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "PENDING",
      file_hash: hash,
      filename: "bulk_relations_error_header_test.xlsx",
      task_reference: "oban:1"
    })

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "STARTED",
      file_hash: hash,
      filename: file
    })

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "COMPLETED",
      file_hash: hash,
      filename: file
    })

    assert %{"file_hash" => ^hash, "status" => "PENDING", "task_reference" => _} =
             conn
             |> post(
               Routes.xlsx_path(conn, :upload),
               %{
                 "source" => "business_concept",
                 "target" => "data_structure",
                 "relations" => upload(file)
               }
             )
             |> json_response(:accepted)

    opts = %{
      "claims" => %{
        "user_id" => claims.user_id,
        "user_name" => claims.user_name,
        "jti" => claims.jti,
        "role" => claims.role
      },
      "user_id" => claims.user_id
    }

    relation_params =
      %{
        "filename" => "bulk_relations_error_header_test.xlsx",
        "hash" => hash,
        "path" => "tmp/xlsx_uploads/#{hash}.xlsx",
        "source" => "business_concept",
        "target" => "data_structure"
      }

    assert_enqueued(
      worker: UploadWorker,
      args: %{"opts" => opts, "relation_params" => relation_params},
      queue: :xlsx_upload_queue
    )

    assert {:ok, _} =
             perform_job(UploadWorker, %{"opts" => opts, "relation_params" => relation_params})

    assert [] == Resources.list_relations()
  end

  @tag authentication: [role: "admin"]
  test "not create relations if missing params", %{
    conn: conn,
    claims: claims
  } do
    file = "test/fixtures/bulk_relations_empty_test.xlsx"

    hash = FileHash.hash(file, :md5)

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "PENDING",
      file_hash: hash,
      filename: "bulk_relations_empty_test.xlsx",
      task_reference: "oban:1"
    })

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "STARTED",
      file_hash: hash,
      filename: file
    })

    MockHelper.event_mock(%{
      user_id: claims.user_id,
      status: "COMPLETED",
      file_hash: hash,
      filename: file
    })

    assert %{"file_hash" => ^hash, "status" => "PENDING", "task_reference" => _} =
             conn
             |> post(
               Routes.xlsx_path(conn, :upload),
               %{
                 "source" => "business_concept",
                 "target" => "data_structure",
                 "relations" => upload(file)
               }
             )
             |> json_response(:accepted)

    opts = %{
      "claims" => %{
        "user_id" => claims.user_id,
        "user_name" => claims.user_name,
        "jti" => claims.jti,
        "role" => claims.role
      },
      "user_id" => claims.user_id
    }

    relation_params =
      %{
        "filename" => "bulk_relations_empty_test.xlsx",
        "hash" => hash,
        "path" => "tmp/xlsx_uploads/#{hash}.xlsx",
        "source" => "business_concept",
        "target" => "data_structure"
      }

    assert_enqueued(
      worker: UploadWorker,
      args: %{"opts" => opts, "relation_params" => relation_params},
      queue: :xlsx_upload_queue
    )

    assert {:ok, _} =
             perform_job(UploadWorker, %{"opts" => opts, "relation_params" => relation_params})

    assert [] == Resources.list_relations()
  end
end

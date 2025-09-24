defmodule TdLm.Xlsx.UploadWorkerTest do
  use TdLm.DataCase

  import ExUnit.CaptureLog

  alias TdLm.MockHelper
  alias TdLm.Resources
  alias TdLm.XLSX.Jobs.UploadWorker

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdLm.Cache.LinkLoader)
    start_supervised({Task.Supervisor, name: TdLm.TaskSupervisor})
    :ok
  end

  describe "TdLm.XLSX.Jobs.UploadWorker.perform/1" do
    setup %{test_pid: test_pid} do
      MockHelper.load_excel("test/fixtures/bulk_relations_test.xlsx", test_pid)
    end

    test "upload file user admin with valid data", %{tmp_path: tmp_path, file_name: file_name} do
      %{
        claims: claims,
        domain: %{id: domain_id},
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
        tag: %{id: tag_id}
      } =
        MockHelper.create_mock_data(
          claims: [role: "admin"],
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

      hash = Base.encode16(tmp_path)

      MockHelper.event_mock(%{
        user_id: claims.user_id,
        status: "STARTED",
        file_hash: hash,
        filename: tmp_path
      })

      MockHelper.business_concept_mock(concept_name, domain_id, {:ok, concept})
      MockHelper.data_structure_mock(data_structure_external_id, {:ok, data_structure})

      MockHelper.event_mock(%{
        user_id: claims.user_id,
        status: "COMPLETED",
        file_hash: hash,
        filename: tmp_path
      })

      opts =
        %{
          user_id: claims.user_id,
          claims: %{
            user_id: claims.user_id,
            user_name: claims.user_name,
            jti: claims.jti,
            role: claims.role
          }
        }

      assert {:ok, _} =
               perform_job(
                 UploadWorker,
                 %{
                   "relation_params" => %{
                     "source" => "business_concept",
                     "target" => "data_structure",
                     "path" => tmp_path,
                     "filename" => file_name,
                     "hash" => hash
                   },
                   "opts" => opts
                 }
               )

      refute File.exists?(tmp_path)

      assert [%{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: ^tag_id}] =
               Resources.list_relations()
    end
  end

  describe "File errors" do
    setup %{test_pid: test_pid} do
      MockHelper.load_excel("test/fixtures/invalid_file.txt", test_pid)
    end

    test "upload invalid file", %{tmp_path: tmp_path, file_name: file_name} do
      claims = build(:claims)
      hash = Base.encode16(tmp_path)

      MockHelper.event_mock(%{
        user_id: claims.user_id,
        status: "STARTED",
        file_hash: hash,
        filename: tmp_path
      })

      MockHelper.event_mock(%{
        user_id: claims.user_id,
        status: "FAILED",
        file_hash: hash,
        message: "Please contact Truedat's team: \"invalid zip file\"",
        filename: tmp_path
      })

      opts =
        %{
          user_id: claims.user_id,
          claims: %{
            user_id: claims.user_id,
            user_name: claims.user_name,
            jti: claims.jti,
            role: claims.role
          }
        }

      assert capture_log(fn ->
               assert {:error, "invalid zip file"} =
                        perform_job(
                          UploadWorker,
                          %{
                            "relation_params" => %{
                              "source" => "business_concept",
                              "target" => "data_structure",
                              "path" => tmp_path,
                              "filename" => file_name,
                              "hash" => hash
                            },
                            "opts" => opts
                          }
                        )
             end) =~ "invalid zip file"
    end
  end
end

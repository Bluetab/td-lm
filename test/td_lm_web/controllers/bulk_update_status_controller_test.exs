defmodule TdLmWeb.BulkUpdateStatusControllerTest do
  use TdLmWeb.ConnCase

  setup do
    start_supervised!(TdLm.Cache.LinkLoader)
    :ok
  end

  describe "bulk update status" do
    @tag authentication: [role: "admin"]
    test "admin can update status of relations", %{conn: conn} do
      %{id: domain_id} = CacheHelpers.put_domain()

      %{id: source_id, name: source_name} =
        CacheHelpers.put_concept(domain_id: domain_id, name: "concept_source_name")

      %{id: target_id, name: target_name} = CacheHelpers.put_structure(domain_id: domain_id)

      %{id: id} =
        insert(:relation,
          status: "pending",
          source_type: "business_concept",
          source_id: source_id,
          target_type: "data_structure",
          target_id: target_id
        )

      params = %{"relation_ids" => [id], "status" => "approved"}

      assert %{
               "data" => %{
                 "errors" => %{},
                 "relations" => [
                   %{
                     "id" => ^id,
                     "status" => "approved",
                     "source_id" => ^source_id,
                     "source_type" => "business_concept",
                     "source_name" => ^source_name,
                     "target_id" => ^target_id,
                     "target_type" => "data_structure",
                     "target_name" => ^target_name
                   }
                 ]
               }
             } =
               conn
               |> post(Routes.bulk_update_status_path(conn, :update), params)
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin get errors for non valid relation updates", %{conn: conn} do
      %{id: domain_id} = CacheHelpers.put_domain()

      %{id: source_id, name: source_name} =
        CacheHelpers.put_concept(
          domain_id: domain_id,
          type: "business_concept",
          name: "concept_source_name"
        )

      %{id: target_id, name: target_name} =
        CacheHelpers.put_structure(domain_id: domain_id, type: "data_structure")

      %{id: nil_status_id} =
        insert(:relation,
          status: "nil",
          source_id: source_id,
          source_type: "business_concept",
          target_id: target_id,
          target_type: "data_structure"
        )

      %{id: approved_status_id} =
        insert(:relation,
          status: "approved",
          source_id: source_id,
          source_type: "business_concept",
          target_id: target_id,
          target_type: "data_structure"
        )

      %{id: rejected_status_id} =
        insert(:relation,
          status: "rejected",
          source_id: source_id,
          source_type: "business_concept",
          target_id: target_id,
          target_type: "data_structure"
        )

      params = %{
        "relation_ids" => [nil_status_id, approved_status_id, rejected_status_id],
        "status" => "approved"
      }

      assert %{
               "data" => %{
                 "errors" => errors,
                 "relations" => relations
               }
             } =
               conn
               |> post(Routes.bulk_update_status_path(conn, :update), params)
               |> json_response(:ok)

      assert [] == relations

      assert %{
               "status_approved" => %{
                 "message" => "is not allowed to change approved status",
                 "reason" => "status_approved",
                 "relations" => [
                   %{
                     "id" => ^approved_status_id,
                     "source_id" => ^source_id,
                     "source_name" => ^source_name,
                     "source_type" => "business_concept",
                     "target_id" => ^target_id,
                     "target_name" => ^target_name,
                     "target_type" => "data_structure"
                   }
                 ]
               },
               "status_nil" => %{
                 "message" => "is not allowed to change nil status",
                 "reason" => "status_nil",
                 "relations" => [
                   %{
                     "id" => ^nil_status_id,
                     "source_id" => ^source_id,
                     "source_name" => ^source_name,
                     "source_type" => "business_concept",
                     "target_id" => ^target_id,
                     "target_name" => ^target_name,
                     "target_type" => "data_structure"
                   }
                 ]
               },
               "status_rejected" => %{
                 "message" => "is not allowed to change rejected status",
                 "reason" => "status_rejected",
                 "relations" => [
                   %{
                     "id" => ^rejected_status_id,
                     "source_id" => ^source_id,
                     "source_name" => ^source_name,
                     "source_type" => "business_concept",
                     "target_id" => ^target_id,
                     "target_name" => ^target_name,
                     "target_type" => "data_structure"
                   }
                 ]
               }
             } = errors
    end

    @tag authentication: [role: "user"]
    test "non admin cannot update status of relations", %{conn: conn} do
      %{id: id} = insert(:relation, status: "pending")

      params = %{"relation_ids" => [id], "status" => "approved"}

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> post(Routes.bulk_update_status_path(conn, :update), params)
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: [:manage_business_concept_links]]
    test "user with permission can update on allowed domains",
         %{conn: conn, domain: %{id: allowed_domain_id}} do
      %{id: not_allowed_domain_id} = CacheHelpers.put_domain()

      %{id: allowed_concept_id, name: allowed_concept_name} =
        CacheHelpers.put_concept(
          domain_id: allowed_domain_id,
          type: "business_concept",
          name: "allowed_concept_name"
        )

      %{id: non_permission_concept_id, name: non_permission_concept_name} =
        CacheHelpers.put_concept(
          domain_id: not_allowed_domain_id,
          type: "business_concept",
          name: "non_permission_concept_name"
        )

      %{id: structure_id, name: structure_name} = CacheHelpers.put_structure()

      %{id: allowed_relation_id, tag: %{value: %{"type" => tag_type}}} =
        insert(:relation,
          source_type: "business_concept",
          source_id: allowed_concept_id,
          target_type: "data_structure",
          target_id: structure_id,
          status: "pending",
          context: %{"permission" => "allowed"}
        )

      %{id: not_allowed_relation_id, tag: %{value: %{"type" => error_tag_type}}} =
        insert(:relation,
          source_type: "business_concept",
          source_id: non_permission_concept_id,
          target_type: "data_structure",
          target_id: structure_id,
          status: "pending",
          context: %{"permission" => "not_allowed"}
        )

      params = %{
        "relation_ids" => [allowed_relation_id, not_allowed_relation_id],
        "status" => "approved"
      }

      assert %{
               "data" => %{
                 "relations" => updated_relations,
                 "errors" => errors
               }
             } =
               conn
               |> post(Routes.bulk_update_status_path(conn, :update), params)
               |> json_response(:ok)

      assert [
               %{
                 "id" => ^allowed_relation_id,
                 "source_id" => ^allowed_concept_id,
                 "source_name" => ^allowed_concept_name,
                 "source_type" => "business_concept",
                 "target_id" => ^structure_id,
                 "target_name" => ^structure_name,
                 "target_type" => "data_structure",
                 "status" => "approved",
                 "tag_type" => ^tag_type
               }
             ] = updated_relations

      assert %{
               "permissions" => %{
                 "message" => "forbidden",
                 "reason" => "permissions",
                 "relations" => [
                   %{
                     "id" => ^not_allowed_relation_id,
                     "source_id" => ^non_permission_concept_id,
                     "source_name" => ^non_permission_concept_name,
                     "source_type" => "business_concept",
                     "target_id" => ^structure_id,
                     "target_name" => ^structure_name,
                     "target_type" => "data_structure",
                     "tag_type" => ^error_tag_type
                   }
                 ]
               }
             } = errors
    end
  end
end

defmodule TdLm.SearchTest do
  use TdLmWeb.ConnCase

  import Mox

  alias TdLM.Search

  @permissions [
    "view_draft_business_concepts",
    "manage_business_concept_links",
    "link_data_structure"
  ]

  @concept_permissions [
    "manage_business_concept_links",
    "manage_confidential_business_concepts",
    "view_approval_pending_business_concepts",
    "view_deprecated_business_concepts",
    "view_draft_business_concepts",
    "view_published_business_concepts",
    "view_rejected_business_concepts",
    "view_versioned_business_concepts"
  ]

  @aggs %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  describe "get_filter_values/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches and returns filters for #{role} account", %{claims: claims} do
        Mox.expect(MockClusterHandler, :call, 6, fn
          :bg, TdBg.Permissions, :get_default_permissions, [] ->
            {:ok, @concept_permissions}

          :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
            assert permissions == %{
                     "manage_business_concept_links" => :all,
                     "manage_confidential_business_concepts" => :all,
                     "view_approval_pending_business_concepts" => :all,
                     "view_deprecated_business_concepts" => :all,
                     "view_draft_business_concepts" => :all,
                     "view_published_business_concepts" => :all,
                     "view_rejected_business_concepts" => :all,
                     "view_versioned_business_concepts" => :all
                   }

            assert opts[:field_prefix] in ["source_data.", "target_data."]

            {:ok, [%{match_all: %{}}]}

          :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
            assert permissions == %{
                     "view_data_structure" => :all,
                     "manage_confidential_structures" => :all
                   }

            assert opts[:field_prefix] in ["source_data.", "target_data."]

            {:ok, %{match_all: %{}}}
        end)

        expect(ElasticsearchMock, :request, fn
          _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
            assert %{
                     bool: %{
                       filter: [
                         %{
                           bool: %{
                             should: [
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "business_concept"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "data_structure"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "quality_control"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               }
                             ]
                           }
                         },
                         %{
                           bool: %{
                             should: [
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "business_concept"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "data_structure"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "quality_control"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               }
                             ]
                           }
                         }
                       ],
                       must_not: %{exists: %{field: "deleted_at"}}
                     }
                   } == query

            SearchHelpers.aggs_response(@aggs)
        end)

        assert {:ok, %{"foo" => %{values: ["bar", "baz"]}}} =
                 Search.get_filter_values(claims, %{})
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "searches and returns filters for non admin user account", %{
      claims: claims,
      domain: %{id: domain_id}
    } do
      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => [domain_id],
                   "manage_confidential_business_concepts" => :none,
                   "view_approval_pending_business_concepts" => :none,
                   "view_deprecated_business_concepts" => :none,
                   "view_draft_business_concepts" => [domain_id],
                   "view_published_business_concepts" => :none,
                   "view_rejected_business_concepts" => :none,
                   "view_versioned_business_concepts" => :none
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{
               bool: %{
                 filter: [%{term: %{"status" => "draft"}}, %{term: %{"domain_ids" => domain_id}}]
               }
             },
             %{bool: %{must_not: [%{term: %{"#{opts[:field_prefix]}confidential.raw" => true}}]}},
             %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}}
           ]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_confidential_structures" => :none,
                   "link_data_structure" => [domain_id]
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}},
             %{term: %{"#{opts[:field_prefix]}confidential" => false}}
           ]}
      end)

      expect(ElasticsearchMock, :request, fn
        _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"target_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"target_data.domain_ids" => domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{term: %{"target_data.domain_ids" => domain_id}},
                                   %{term: %{"target_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"source_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"source_data.domain_ids" => domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{term: %{"source_data.domain_ids" => domain_id}},
                                   %{term: %{"source_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok,
              %{
                "foo" => %{
                  values: ["bar", "baz"]
                }
              }} = Search.get_filter_values(claims, %{"linkable" => true})
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "include filters from request parameters", %{claims: claims, domain: %{id: domain_id}} do
      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => [domain_id],
                   "manage_confidential_business_concepts" => :none,
                   "view_approval_pending_business_concepts" => :none,
                   "view_deprecated_business_concepts" => :none,
                   "view_draft_business_concepts" => [domain_id],
                   "view_published_business_concepts" => :none,
                   "view_rejected_business_concepts" => :none,
                   "view_versioned_business_concepts" => :none
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{
               bool: %{
                 filter: [%{term: %{"status" => "draft"}}, %{term: %{"domain_ids" => domain_id}}]
               }
             },
             %{bool: %{must_not: [%{term: %{"#{opts[:field_prefix]}confidential.raw" => true}}]}},
             %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}}
           ]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_confidential_structures" => :none,
                   "link_data_structure" => [domain_id]
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}},
             %{term: %{"#{opts[:field_prefix]}confidential" => false}}
           ]}
      end)

      expect(ElasticsearchMock, :request, fn
        _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{term: %{"foo" => "bar"}},
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"target_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"target_data.domain_ids" => domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{term: %{"target_data.domain_ids" => domain_id}},
                                   %{term: %{"target_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"source_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"source_data.domain_ids" => domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{term: %{"source_data.domain_ids" => domain_id}},
                                   %{term: %{"source_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.aggs_response(@aggs)
      end)

      params = %{"filters" => %{"foo" => ["bar"]}, "linkable" => true}

      assert {:ok,
              %{
                "foo" => %{
                  values: ["bar", "baz"],
                  buckets: [%{"key" => "bar"}, %{"key" => "baz"}]
                }
              }} =
               Search.get_filter_values(claims, params)
    end
  end

  describe "search/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches relations for #{role} account", %{claims: claims} do
        %{"relations" => relations} = create_relations()

        Mox.expect(MockClusterHandler, :call, 6, fn
          :bg, TdBg.Permissions, :get_default_permissions, [] ->
            {:ok, @concept_permissions}

          :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
            assert permissions == %{
                     "manage_business_concept_links" => :all,
                     "manage_confidential_business_concepts" => :all,
                     "view_approval_pending_business_concepts" => :all,
                     "view_deprecated_business_concepts" => :all,
                     "view_draft_business_concepts" => :all,
                     "view_published_business_concepts" => :all,
                     "view_rejected_business_concepts" => :all,
                     "view_versioned_business_concepts" => :all
                   }

            assert opts[:field_prefix] in ["source_data.", "target_data."]

            {:ok, [%{match_all: %{}}]}

          :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
            assert permissions == %{
                     "view_data_structure" => :all,
                     "manage_confidential_structures" => :all
                   }

            assert opts[:field_prefix] in ["source_data.", "target_data."]

            {:ok, %{match_all: %{}}}
        end)

        expect(ElasticsearchMock, :request, fn
          _,
          :post,
          "/relations/_search",
          %{
            size: 20,
            sort: ["_score", "updated_at"],
            from: 0,
            query: query
          },
          _ ->
            assert query == %{
                     bool: %{
                       filter: [
                         %{
                           bool: %{
                             should: [
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "business_concept"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "data_structure"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"target_type" => "quality_control"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               }
                             ]
                           }
                         },
                         %{
                           bool: %{
                             should: [
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "business_concept"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "data_structure"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               },
                               %{
                                 bool: %{
                                   filter: [
                                     %{term: %{"source_type" => "quality_control"}},
                                     %{match_all: %{}}
                                   ]
                                 }
                               }
                             ]
                           }
                         }
                       ],
                       must_not: %{exists: %{field: "deleted_at"}}
                     }
                   }

            SearchHelpers.hits_response(relations)
        end)

        assert %{total: 2, results: [_, _]} = Search.search(%{}, claims)
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "search relations for non admin user account", %{
      claims: claims,
      domain: %{id: user_domain_id} = domain
    } do
      domains = [
        domain,
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain()
      ]

      %{"relations" => relations} = create_relations(domains)

      %{
        id: relation_id,
        origin: relation_origin,
        status: relation_status,
        source_id: relation_source_id,
        source_type: relation_source_type,
        source_data: %{name: relation_source_name, domain_ids: relation_source_domain_ids},
        target_id: relation_target_id,
        target_type: relation_target_type,
        target_data: %{name: relation_target_name, domain_ids: relation_target_domain_ids}
      } = relation = List.first(relations)

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => [user_domain_id],
                   "manage_confidential_business_concepts" => :none,
                   "view_approval_pending_business_concepts" => :none,
                   "view_deprecated_business_concepts" => :none,
                   "view_draft_business_concepts" => [user_domain_id],
                   "view_published_business_concepts" => :none,
                   "view_rejected_business_concepts" => :none,
                   "view_versioned_business_concepts" => :none
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{
               bool: %{
                 filter: [
                   %{term: %{"status" => "draft"}},
                   %{term: %{"domain_ids" => user_domain_id}}
                 ]
               }
             },
             %{bool: %{must_not: [%{term: %{"#{opts[:field_prefix]}confidential.raw" => true}}]}},
             %{term: %{"#{opts[:field_prefix]}domain_ids" => user_domain_id}}
           ]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_confidential_structures" => :none,
                   "link_data_structure" => [user_domain_id]
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{term: %{"#{opts[:field_prefix]}domain_ids" => user_domain_id}},
             %{term: %{"#{opts[:field_prefix]}confidential" => false}}
           ]}
      end)

      expect(ElasticsearchMock, :request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => user_domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"target_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"target_data.domain_ids" => user_domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{term: %{"target_data.domain_ids" => user_domain_id}},
                                   %{term: %{"target_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{
                                     bool: %{
                                       filter: [
                                         %{term: %{"status" => "draft"}},
                                         %{term: %{"domain_ids" => user_domain_id}}
                                       ]
                                     }
                                   },
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"source_data.confidential.raw" => true}}
                                       ]
                                     }
                                   },
                                   %{term: %{"source_data.domain_ids" => user_domain_id}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{term: %{"source_data.domain_ids" => user_domain_id}},
                                   %{term: %{"source_data.confidential" => false}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response([relation])
      end)

      domains_ids = Enum.uniq(relation_source_domain_ids ++ relation_target_domain_ids)

      assert %{
               total: 1,
               results: [
                 %{
                   "domain_ids" => ^domains_ids,
                   "id" => ^relation_id,
                   "origin" => ^relation_origin,
                   "status" => ^relation_status,
                   "source_domain_ids" => ^relation_source_domain_ids,
                   "source_id" => ^relation_source_id,
                   "source_name" => ^relation_source_name,
                   "source_type" => ^relation_source_type,
                   "target_domain_ids" => ^relation_target_domain_ids,
                   "target_id" => ^relation_target_id,
                   "target_name" => ^relation_target_name,
                   "target_type" => ^relation_target_type
                 }
               ]
             } = Search.search(%{"linkable" => true}, claims)
    end

    @tag authentication: [role: "user"]
    test "returns empty for non admin user account", %{claims: claims} do
      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :none,
                   "manage_confidential_business_concepts" => :none,
                   "view_approval_pending_business_concepts" => :none,
                   "view_deprecated_business_concepts" => :none,
                   "view_draft_business_concepts" => :none,
                   "view_published_business_concepts" => :none,
                   "view_rejected_business_concepts" => :none,
                   "view_versioned_business_concepts" => :none
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok,
           [
             %{match_none: %{}},
             %{bool: %{must_not: [%{term: %{"#{opts[:field_prefix]}confidential.raw" => true}}]}}
           ]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => :none,
                   "manage_confidential_structures" => :none
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, %{match_none: %{}}}
      end)

      expect(ElasticsearchMock, :request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{match_none: %{}},
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"target_data.confidential.raw" => true}}
                                       ]
                                     }
                                   }
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{match_none: %{}},
                                   %{
                                     bool: %{
                                       must_not: [
                                         %{term: %{"source_data.confidential.raw" => true}}
                                       ]
                                     }
                                   }
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_none: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response([])
      end)

      assert %{total: 0, results: []} = Search.search(%{}, claims)
    end

    @tag authentication: [role: "admin"]
    test "includes scroll_id in response", %{claims: claims} do
      %{"relations" => relations} = create_relations()

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :all,
                   "manage_confidential_business_concepts" => :all,
                   "view_approval_pending_business_concepts" => :all,
                   "view_deprecated_business_concepts" => :all,
                   "view_draft_business_concepts" => :all,
                   "view_published_business_concepts" => :all,
                   "view_rejected_business_concepts" => :all,
                   "view_versioned_business_concepts" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, [%{match_all: %{}}]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => :all,
                   "manage_confidential_structures" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, %{match_all: %{}}}
      end)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/relations/_search", _, [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response(relations, 7)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "some_scroll_id"}, _ ->
        SearchHelpers.scroll_response([], 7)
      end)

      %{total: 7, results: [_, _], scroll_id: scroll_id} =
        Search.search(%{"scroll" => "1m"}, claims)

      %{total: 7, results: [], scroll_id: ^scroll_id} =
        Search.search(%{"scroll_id" => scroll_id}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with status filter", %{claims: claims} do
      %{"relations" => relations} = create_relations()
      insert(:relation, status: "approved")

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :all,
                   "manage_confidential_business_concepts" => :all,
                   "view_approval_pending_business_concepts" => :all,
                   "view_deprecated_business_concepts" => :all,
                   "view_draft_business_concepts" => :all,
                   "view_published_business_concepts" => :all,
                   "view_rejected_business_concepts" => :all,
                   "view_versioned_business_concepts" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, [%{match_all: %{}}]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => :all,
                   "manage_confidential_structures" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, %{match_all: %{}}}
      end)

      expect(ElasticsearchMock, :request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{term: %{"status" => "pending"}},
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response(relations)
      end)

      assert %{
               total: 2,
               results: [_, _]
             } = Search.search(%{"filters" => %{"status" => ["pending"]}}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with taxonomy filter", %{claims: claims} do
      %{"relations" => [relation | _], "domains" => [%{id: domain_id} | _]} = create_relations()

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :all,
                   "manage_confidential_business_concepts" => :all,
                   "view_approval_pending_business_concepts" => :all,
                   "view_deprecated_business_concepts" => :all,
                   "view_draft_business_concepts" => :all,
                   "view_published_business_concepts" => :all,
                   "view_rejected_business_concepts" => :all,
                   "view_versioned_business_concepts" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, [%{match_all: %{}}]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => :all,
                   "manage_confidential_structures" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, %{match_all: %{}}}
      end)

      expect(ElasticsearchMock, :request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{term: %{"domain_ids" => domain_id}},
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response([relation])
      end)

      assert %{
               total: 1,
               results: [_]
             } = Search.search(%{"filters" => %{"taxonomy" => [domain_id]}}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations for origin filter", %{claims: claims} do
      %{"domains" => [source_domain, target_domain | _]} = create_relations()

      relation =
        insert(:relation, origin: "suggested")
        |> Map.merge(%{
          source_data: %{domain_ids: [source_domain.id], name: "Source"},
          target_data: %{domain_ids: [target_domain.id], name: "Target"}
        })

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :all,
                   "manage_confidential_business_concepts" => :all,
                   "view_approval_pending_business_concepts" => :all,
                   "view_deprecated_business_concepts" => :all,
                   "view_draft_business_concepts" => :all,
                   "view_published_business_concepts" => :all,
                   "view_rejected_business_concepts" => :all,
                   "view_versioned_business_concepts" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, [%{match_all: %{}}]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => :all,
                   "manage_confidential_structures" => :all
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          {:ok, %{match_all: %{}}}
      end)

      expect(ElasticsearchMock, :request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{term: %{"origin" => "suggested"}},
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"target_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       },
                       %{
                         bool: %{
                           should: [
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "business_concept"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "data_structure"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             },
                             %{
                               bool: %{
                                 filter: [
                                   %{term: %{"source_type" => "quality_control"}},
                                   %{match_all: %{}}
                                 ]
                               }
                             }
                           ]
                         }
                       }
                     ],
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response([relation])
      end)

      assert %{
               total: 1,
               results: [_]
             } = Search.search(%{"filters" => %{"origin" => ["suggested"]}}, claims)
    end

    def create_relations do
      create_relations([
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain()
      ])
    end

    def create_relations(domains) do
      relations =
        Enum.map(1..2, fn i ->
          # domain_1, domain_3
          source_domain = Enum.at(domains, (i - 1) * 2)
          # domain_2, domain_4
          target_domain = Enum.at(domains, (i - 1) * 2 + 1)

          :relation
          |> insert(status: "pending")
          |> Map.merge(%{
            source_data: %{domain_ids: [source_domain.id], name: "Source"},
            target_data: %{domain_ids: [target_domain.id], name: "Target"}
          })
        end)

      %{"relations" => relations, "domains" => domains}
    end
  end
end

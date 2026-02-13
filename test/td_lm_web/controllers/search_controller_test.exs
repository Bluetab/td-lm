defmodule TdLmWeb.SearchControllerTest do
  use TdLmWeb.ConnCase

  import Mox

  alias TdCache.I18nCache
  alias TdCache.Redix

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

  @locales ["en", "es"]

  setup do
    %{id: concept_id} = concept = CacheHelpers.put_concept()
    %{id: structure_id} = structure = CacheHelpers.put_structure()

    relation =
      generate_relation(%{
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: structure_id,
        origin: "suggested",
        status: "pending"
      })

    [relation: relation, concept: concept, structure: structure]
  end

  setup {Mox, :verify_on_exit!}

  describe "POST /api/relations/index_search" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} can search relations", %{conn: conn, relation: relation} do
        %{
          id: relation_id,
          source_id: relation_source_id,
          source_type: relation_source_type,
          source_data: %{name: relation_source_name, domain_ids: relation_source_domain_ids},
          target_id: relation_target_id,
          target_type: relation_target_type,
          target_data: %{name: relation_target_name, domain_ids: relation_target_domain_ids},
          origin: relation_origin,
          status: relation_status
        } = relation

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
        |> expect(:request, fn
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

            SearchHelpers.hits_response([relation])
        end)

        assert %{"data" => data} =
                 conn
                 |> post(Routes.search_path(conn, :create, %{}))
                 |> json_response(:ok)

        domain_ids = relation_source_domain_ids ++ relation_target_domain_ids

        assert [
                 %{
                   "id" => ^relation_id,
                   "domain_ids" => ^domain_ids,
                   "source_domain_ids" => ^relation_source_domain_ids,
                   "source_id" => ^relation_source_id,
                   "source_name" => ^relation_source_name,
                   "source_type" => ^relation_source_type,
                   "target_domain_ids" => ^relation_target_domain_ids,
                   "target_id" => ^relation_target_id,
                   "target_name" => ^relation_target_name,
                   "target_type" => ^relation_target_type,
                   "origin" => ^relation_origin,
                   "status" => ^relation_status
                 }
               ] = data
      end
    end

    @tag authentication: [role: "admin"]
    test "can search relations with query string search", %{conn: conn, relation: relation} do
      on_exit(fn -> Redix.del!("i18n:*") end)

      I18nCache.put_default_locale("en")

      Enum.each(@locales, fn locale ->
        I18nCache.put(locale, %{message_id: "#{locale}_id", definition: "#{locale}"})
      end)

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

      expect(ElasticsearchMock, :request, fn _,
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
                   must_not: %{exists: %{field: "deleted_at"}},
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
                   should: [
                     %{
                       multi_match: %{
                         type: "phrase_prefix",
                         fields: [
                           "source_name",
                           "target_name",
                           "source_name_es",
                           "target_name_es"
                         ],
                         query: "foo",
                         lenient: true,
                         boost: 4.0
                       }
                     },
                     %{
                       simple_query_string: %{
                         fields: [
                           "source_name",
                           "target_name",
                           "source_name_es",
                           "target_name_es"
                         ],
                         query: "\"foo\"",
                         quote_field_suffix: ".exact",
                         boost: 4.0
                       }
                     }
                   ],
                   must: %{
                     multi_match: %{
                       type: "bool_prefix",
                       fields: ["ngram_source_name*", "ngram_target_name*"],
                       query: "foo",
                       lenient: true
                     }
                   }
                 }
               }

        SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.search_path(conn, :create, %{"query" => "foo"}))
               |> json_response(:ok)

      assert [_] = data
    end

    @tag authentication: [role: "admin"]
    test "can search relations with query string search in strict mode", %{
      conn: conn,
      relation: relation
    } do
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

      expect(ElasticsearchMock, :request, fn _,
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
                   must_not: %{exists: %{field: "deleted_at"}},
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
                   must: %{
                     simple_query_string: %{
                       fields: ["source_name", "target_name"],
                       query: "\"foo\"",
                       quote_field_suffix: ".exact"
                     }
                   }
                 }
               }

        SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.search_path(conn, :create, %{"query" => "\"foo\""}))
               |> json_response(:ok)

      assert [_] = data
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "user with permissions can search relations", %{
      conn: conn,
      domain: %{id: domain_id} = domain_1,
      concept: concept,
      structure: structure
    } do
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

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

      ElasticsearchMock
      |> expect(:request, fn
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
                     must_not: %{exists: %{field: "deleted_at"}},
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
                     ]
                   }
                 }

          SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.search_path(conn, :create, %{"linkable" => true}))
               |> json_response(:ok)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_draft_business_concepts",
             "view_data_structure",
             "manage_confidential_structures"
           ]
         ]
    test "user with permissions can search relations - with resource filters", %{
      conn: conn,
      domain: %{id: domain_id} = domain_1,
      concept: concept,
      structure: structure
    } do
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

      Mox.expect(MockClusterHandler, :call, 6, fn
        :bg, TdBg.Permissions, :get_default_permissions, [] ->
          {:ok, @concept_permissions}

        :bg, TdBg.BusinessConcepts.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "manage_business_concept_links" => :none,
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
                 filter: [
                   %{term: %{"#{opts[:field_prefix]}status" => "draft"}},
                   %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}}
                 ]
               }
             },
             %{bool: %{must_not: [%{term: %{"#{opts[:field_prefix]}confidential.raw" => true}}]}}
           ]}

        :dd, TdDd.DataStructures.Search.Query, :build_filters, [permissions, opts] ->
          assert permissions == %{
                   "view_data_structure" => [domain_id],
                   "manage_confidential_structures" => [domain_id]
                 }

          assert opts[:field_prefix] in ["source_data.", "target_data."]

          response = %{
            bool: %{
              should: [
                %{
                  bool: %{
                    filter: [
                      %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}},
                      %{term: %{"#{opts[:field_prefix]}confidential" => false}}
                    ]
                  }
                },
                %{bool: %{filter: %{term: %{"#{opts[:field_prefix]}domain_ids" => domain_id}}}}
              ]
            }
          }

          {:ok, response}
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
                       %{term: %{"target_type" => "data_structure"}},
                       %{term: %{"source_type" => "business_concept"}},
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
                                         %{term: %{"target_data.status" => "draft"}},
                                         %{term: %{"target_data.domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
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
                                   %{
                                     bool: %{
                                       should: [
                                         %{
                                           bool: %{
                                             filter: [
                                               %{term: %{"target_data.domain_ids" => domain_id}},
                                               %{term: %{"target_data.confidential" => false}}
                                             ]
                                           }
                                         },
                                         %{
                                           bool: %{
                                             filter: %{
                                               term: %{"target_data.domain_ids" => domain_id}
                                             }
                                           }
                                         }
                                       ]
                                     }
                                   }
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
                                         %{term: %{"source_data.status" => "draft"}},
                                         %{term: %{"source_data.domain_ids" => domain_id}}
                                       ]
                                     }
                                   },
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
                                   %{
                                     bool: %{
                                       should: [
                                         %{
                                           bool: %{
                                             filter: [
                                               %{term: %{"source_data.domain_ids" => domain_id}},
                                               %{term: %{"source_data.confidential" => false}}
                                             ]
                                           }
                                         },
                                         %{
                                           bool: %{
                                             filter: %{
                                               term: %{"source_data.domain_ids" => domain_id}
                                             }
                                           }
                                         }
                                       ]
                                     }
                                   }
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

      assert %{"data" => _} =
               conn
               |> post(
                 Routes.search_path(conn, :create, %{
                   "must" => %{
                     "source_type" => "business_concept",
                     "target_type" => "data_structure"
                   }
                 })
               )
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions return empty", %{
      conn: conn
    } do
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

      ElasticsearchMock
      |> expect(:request, fn
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

      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :create, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search relations with scroll", %{
      conn: conn,
      concept: concept,
      structure: structure
    } do
      relation =
        generate_relation(%{
          source_type: "business_concept",
          source_id: concept.id,
          target_type: "data_structure",
          target_id: structure.id,
          origin: "suggested",
          status: "pending"
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

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/relations/_search", _, [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response([relation], 7)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "some_scroll_id"}, _ ->
        SearchHelpers.scroll_response([], 7)
      end)

      assert %{"data" => _, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.search_path(conn, :create, %{"scroll" => "1m"}))
               |> json_response(:ok)

      assert %{"data" => [], "scroll_id" => ^scroll_id} =
               conn
               |> post(Routes.search_path(conn, :create, %{"scroll_id" => scroll_id}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with status filter", %{
      conn: conn,
      concept: concept,
      structure: structure
    } do
      domain_1 = CacheHelpers.put_domain()
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

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

      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert %{
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
                 } == query

          SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => _} =
               conn
               |> post(
                 Routes.search_path(conn, :create, %{"filters" => %{"status" => ["pending"]}})
               )
               |> json_response(:ok)
    end
  end

  describe "POST /api/relations/filters" do
    @tag authentication: [role: "admin"]
    test "lists all filters", %{conn: conn} do
      aggs = %{
        "foo" => %{
          "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
        }
      }

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
      |> expect(:request, fn _, :post, "/relations/_search", %{query: query}, _ ->
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

        SearchHelpers.aggs_response(aggs)
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.search_path(conn, :filters, %{}))
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end
  end

  describe "POST /api/relations/reindex" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} can reindex", %{conn: conn} do
        assert conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> response(:accepted)
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "user whith permissions is unauthorized", %{
      conn: conn
    } do
      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "user without permissions is unauthorized", %{
      conn: conn
    } do
      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> json_response(:forbidden)
    end
  end

  defp generate_relation(attrs) do
    generate_relation(attrs, [CacheHelpers.put_domain(), CacheHelpers.put_domain()])
  end

  defp generate_relation(attrs, [domain_1, domain_2]) do
    relation_attrs =
      %{
        source_type: "business_concept",
        target_type: "data_structure",
        deleted_at: nil
      }
      |> Map.merge(attrs)
      |> Keyword.new()

    :relation
    |> insert(relation_attrs)
    |> Map.put(:source_data, %{name: "Source", domain_ids: [domain_1.id]})
    |> Map.put(:target_data, %{name: "Target", domain_ids: [domain_2.id]})
  end
end

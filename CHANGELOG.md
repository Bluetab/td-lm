# Changelog

## [Unreleased]

### Changed

- [TD-3083] Enrich cached ingest attributes

## [4.11.0] 2021-01-11

### Added

- [TD-2301] Activate/Deprecate relations on deleted structures

### Changed

- [TD-3170] Build docker image which runs with non-root user

## [4.4.0] 2020-09-22

### Added

- [TD-638] Relations graph for a given resource

## [4.3.0] 2020-09-07

### Fixed

- [TD-2509] Retrieve concept name from cache when returning concept relations

## [4.0.0] 2020-07-01

### Added

- [TD-2637] New audit events `tag_created` and `tag_deleted`

### Changed

- [TD-2637] Publish audit events to Redis stream. Renamed event type
  `add_relation` to `relation_created` and `delete_relation` to
  `relation_deleted`.

### Removed

- Unused routes `PATCH /api/tags/:id` and `PATCH /api/relations/:id` (and
  related code)

## [3.20.0] 2020-04-20

### Changed

- [TD-2508] Update to Elixir 1.10

## [3.9.0] 2019-10-29

### Changed

- [TD-1964] Remove label from tags and use type instead. Update link in cache
  after deleting tag

## [3.6.0] 2019-09-16

### Changed

- Use td-hypermedia 3.6.1

## [3.5.0] 2019-09-03

### Fixed

- [TD-2081] Event stream consumer did not respect redis_host and port config
  options

## [3.3.0] 2019-08-06

### Changed

- [TD-2037] Update td-cache due to lack of performance

## [3.2.0] 2019-07-24

### Added

- [TD-1532] Delete links on receiving a `delete_link` command
- Clean deprecated entries from cache

### Changed

- [TD-2002] Update td-cache and delete permissions list from config

## [3.1.0] 2019-07-08

### Changed

- [TD-1618] Cache improvements (use td-cache instead of td-perms)
- [TD-1782] Migration of field links to corresponding structure
- [TD-1924] Use Jason instead of Poison for JSON encoding/decoding

## [2.21.0] 2019-06-10

### Changed

- [TD-1824] Bump td-perms version to fix relations key
- [TD-1789] New search tags endpoint, return ingest version id in relations
- [TD-1811] Bump td-perms version to fix warnings
- [TD-1850] Cache related modules

### Fixed

- [TD-1749] Added business concept current version id to search response for
  relations with business_concept as source/target

## [2.20.0] 2019-05-27

### Added

- [TD-1535] Check ingest permissions

## [2.19.0] 2019-05-14

### Fixed

- [TD-1660] Fix link_count to filter by business_concept-data_field relations
- [TD-1774] Newline is missing in logger format

### Changed

- [TD-1519] Initial loader will check for missing business_concept parents
  relations and create them

## [2.17.0] 2019-04-17

### Changed

- [TD-71] Bump td-perms to 2.16.1 to fix bug on deletion of default tag

## [2.16.0] 2019-04-01

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to
  override format
- [TD-1606] Remove default tag and update relations with default tag to have no
  tags

## [2.15.0] 2019-03-18

### Changed

- [TD-1541] Fix relation_remover to remove the relations between bc and df
  properly

## [2.14.0] 2019-03-04

### Changed

- [TD-754] Changes for creating relation between business concepts

### Added

- [TD-1422] Included a worker that checks if a BC has been deleted and updates
  the DF relations

## [2.11.2] 2019-02-01

### Changed

- [TD-967] Include the contextual information of the resources on relation load
  into cache

## [2.11.1] 2019-01-23

### Fixed

- Fixed migration relations

## [2.11.0] 2019-01-22

### Changed

- Update version to catch up with our existing release

## [2.9.1] 2018-01-17

### Changed

- Add default type in tag in case it does not exist

## [2.9.0] 2018-01-17

### Changed

- [TD-933] New relations and tags model to consume links having a relationship
  on both directions

## [2.8.0] 2018-11-22

### Changed

- Update to td_perms 2.8.1
- Use environment variable REDIS_HOST instead of REDIS_URI
- Configure Ecto to use UTC datetime for timestamps

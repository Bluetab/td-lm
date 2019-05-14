# Changelog

## [2.19.0] 2019-05-14

### Changed

- [TD-1660] Fix link_count to filter by business_concept-data_field relations
- [TD-1519] Initial loader will check for missing business_concept parents relations and create them

## [2.17.0] 2019-04-17

### Changed

- [TD-71] Bump td-perms to 2.16.1 to fix bug on deletion of default tag

## [2.16.0] 2019-04-01

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to override format
- [TD-1606] Remove default tag and update relations with default tag to have no tags

## [2.15.0] 2019-03-18

### Changed

- [TD-1541] Fix relation_remover to remove the relations between bc and df properly

## [2.14.0] 2019-03-04

### Changed
 
- [TD-754] Changes for creating relation between business concepts

### Added

- [TD-1422] Included a worker that checks if a BC has been deleted and updates the DF relations

## [2.11.2] 2019-02-01

### Changed

- [TD-967] Include the contextual information of the resources on relation load into cache

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

- [TD-933] New relations and tags model to consume links having a relationship on both directions

## [2.8.0] 2018-11-22

### Changed

- Update to td_perms 2.8.1
- Use environment variable REDIS_HOST instead of REDIS_URI
- Configure Ecto to use UTC datetime for timestamps

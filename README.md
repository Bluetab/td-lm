# Truedat Link Manager

TdLM is a back-end service developed as part of truedat project that supports the management of objects linkage between services

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

Install dependencies with `mix deps.get`

To start your Phoenix server:

### Installing

- Create and migrate your database with `mix ecto.create && mix ecto.migrate`
- Start Phoenix endpoint with `mix phx.server`

- Now you can visit [`localhost:4012`](http://localhost:4012) from your browser.

## Running the tests

Run all aplication tests with `mix test`

## Environment variables

### SSL conection

- DB_SSL: boolean value, to enable TSL config, by default is false.
- DB_SSL_CACERTFILE: path of the certification authority cert file "/path/to/ca.crt".
- DB_SSL_VERSION: available versions are tlsv1.2, tlsv1.3 by default is tlsv1.2.
- DB_SSL_CLIENT_CERT: Path to the client SSL certificate file.
- DB_SSL_CLIENT_KEY: Path to the client SSL private key file.
- DB_SSL_VERIFY: This option specifies whether certificates are to be verified.

### Oban configuration

- OBAN_DB_SCHEMA:
  Purpose: Defines the database schema where Oban will create its tables
  Default value: "private"
  Usage: Configures the schema prefix for Oban tables (jobs, peers, etc.)
  Example: If set to "oban_schema", tables will be created in the schema oban_schema.jobs, oban_schema.peers, etc.

- OBAN_CREATE_SCHEMA:
  Purpose: Controls whether Oban should automatically create the database schema
  Default value: "true"
  Usage: Determines if the Oban migration should create the schema specified in OBAN_DB_SCHEMA
  Valid values:
  "true": Automatically creates the schema
  "false": Does not create the schema (must exist beforehand)

- OBAN_FILE_ATTEMPTS
  Purpose: Define how many attempts Oban may try to process the file
  Default value: 5
  Valid values: positive integers

## Deployment

Ready to run in production? Please [check deployment guides](http://www.phoenixframework.org/docs/deployment).

## Built With

- [Phoenix](http://www.phoenixframework.org/) - Web framework
- [Ecto](http://www.phoenixframework.org/) - Phoenix and Ecto integration
- [Postgrex](http://hexdocs.pm/postgrex/) - PostgreSQL driver for Elixir
- [Cowboy](https://ninenines.eu) - HTTP server for Erlang/OTP
- [httpoison](https://hex.pm/packages/httpoison) - HTTP client for Elixir
- [credo](http://credo-ci.org/) - Static code analysis tool for the Elixir language
- [guardian](https://github.com/ueberauth/guardian) - Authentication library
- [canada](https://github.com/jarednorman/canada) - Permission definitions in Elixir apps
- [ex_machina](https://hex.pm/packages/ex_machina) - Create test data for Elixir applications
- [ex_json_schema](https://github.com/jonasschmidt/ex_json_schema) - Elixir JSON Schema validator
- [json_diff](https://github.com/jonasschmidt/ex_json_schema) - Elixir JSON Schema validator
- [corsica](http://hexdocs.pm/corsica) - Elixir library for dealing with CORS requests.

## Authors

- **Bluetab Solutions Group, SL** - _Initial work_ - [Bluetab](http://www.bluetab.net)

See also the list of [contributors](https://github.com/bluetab/td-lm) who participated in this project.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.

In order to use this software, it is necessary that, depending on the type of functionality that you want to obtain, it is assembled with other software whose license may be governed by other terms different than the GNU General Public License version 3 or later. In that case, it will be absolutely necessary that, in order to make a correct use of the software to be assembled, you give compliance with the rules of the concrete license (of Free Software or Open Source Software) of use in each case, as well as, where appropriate, obtaining of the permits that are necessary for these appropriate purposes.

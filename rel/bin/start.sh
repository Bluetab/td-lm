#!/bin/sh

set -o errexit
set -o xtrace

bin/td_lm eval 'Elixir.TdLm.Release.migrate()'
bin/td_lm start

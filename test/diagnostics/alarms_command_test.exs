## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at https://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2019 Pivotal Software, Inc.  All rights reserved.

defmodule AlarmsCommandTest do
  use ExUnit.Case
  import TestHelper

  @command RabbitMQ.CLI.Diagnostics.Commands.AlarmsCommand

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()

    start_rabbitmq_app()

    on_exit([], fn ->
      start_rabbitmq_app()
    end)

    :ok
  end

  setup context do
    {:ok, opts: %{
        node: get_rabbit_hostname(),
        timeout: context[:test_timeout] || 30000
      }}
  end

  test "merge_defaults: nothing to do" do
    assert @command.merge_defaults([], %{}) == {[], %{}}
  end

  test "validate: treats positional arguments as a failure" do
    assert @command.validate(["extra-arg"], %{}) == {:validation_failure, :too_many_args}
  end

  test "validate: treats empty positional arguments and default switches as a success" do
    assert @command.validate([], %{}) == :ok
  end

  @tag test_timeout: 3000
  test "run: targeting an unreachable node throws a badrpc", context do
    assert @command.run([], Map.merge(context[:opts], %{node: :jake@thedog})) == {:badrpc, :nodedown}
  end

  test "run: when target node has no alarms in effect, returns an empty list", context do
    assert [] == status()[:alarms]

    assert @command.run([], context[:opts]) == []
  end

  test "run: when target node has an alarm in effect, returns it", context do
    old_watermark = status()[:vm_memory_high_watermark]
    on_exit(fn() ->
      set_vm_memory_high_watermark(old_watermark)
    end)
    # 2000 bytes will trigger an alarm
    set_vm_memory_high_watermark({:absolute, 2000})

    assert [:memory] == status()[:alarms]
    assert length(@command.run([], context[:opts])) == 1

    set_vm_memory_high_watermark(old_watermark)
  end
end

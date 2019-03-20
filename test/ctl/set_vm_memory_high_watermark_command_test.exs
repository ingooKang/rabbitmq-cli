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

defmodule SetVmMemoryHighWatermarkCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  alias RabbitMQ.CLI.Core.Helpers

  @command RabbitMQ.CLI.Ctl.Commands.SetVmMemoryHighWatermarkCommand

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()

    reset_vm_memory_high_watermark()

    on_exit([], fn ->
      reset_vm_memory_high_watermark()
    end)

    {:ok, opts: %{node: get_rabbit_hostname()}}
  end

  test "validate: a string returns an error", context do
    assert @command.validate(["sandwich"], context[:opts]) == {:validation_failure, :bad_argument}
    assert @command.validate(["0.4sandwich"], context[:opts]) == {:validation_failure, :bad_argument}
  end

  test "validate: valid numerical value returns valid", context do
    assert @command.validate(["0.7"], context[:opts]) == :ok
    assert @command.validate(["1"], context[:opts]) == :ok
  end

  test "run: valid numerical value returns valid", context do
    assert @command.run([0.7], context[:opts]) == :ok
    assert status()[:vm_memory_high_watermark] == 0.7

    assert @command.run([1], context[:opts]) == :ok
    assert status()[:vm_memory_high_watermark] == 1
  end

  test "validate: validate a valid numerical string value returns valid", context do
    assert @command.validate(["0.7"], context[:opts]) == :ok
    assert @command.validate(["1"], context[:opts]) == :ok
  end

  test "validate: the wrong number of arguments returns an arg count error" do
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["too", "many"], %{}) == {:validation_failure, :too_many_args}
  end

  test "validate: a negative number returns a bad argument", context do
    assert @command.validate(["-0.1"], context[:opts]) == {:validation_failure, {:bad_argument, "The threshold should be a fraction between 0.0 and 1.0"}}
  end

  test "validate: a percentage returns a bad argument", context do
    assert @command.validate(["40"], context[:opts]) == {:validation_failure, {:bad_argument, "The threshold should be a fraction between 0.0 and 1.0"}}
  end

  test "validate: a value greater than 1.0 returns a bad argument", context do
    assert @command.validate(["1.1"], context[:opts]) == {:validation_failure, {:bad_argument, "The threshold should be a fraction between 0.0 and 1.0"}}
  end

  test "run: on an invalid node, return a bad rpc" do
    node_name = :jake@thedog
    args = [0.7]
    opts = %{node: node_name}

    assert @command.run(args, opts) == {:badrpc, :nodedown}
  end

## ---------------------------- Absolute tests --------------------------------

  test "validate: an absolute call without an argument returns not enough args" do
    assert @command.validate(["absolute"], %{}) == {:validation_failure, :not_enough_args}
  end

  test "validate: an absolute call with too many arguments returns too many args" do
    assert @command.validate(["absolute", "too", "many"], %{}) ==
      {:validation_failure, :too_many_args}
  end

  test "validate: a single absolute integer return valid", context do
    assert @command.validate(["absolute","10"], context[:opts]) == :ok
  end
  test "run: a single absolute integer return ok", context do
    assert @command.run(["absolute","10"], context[:opts]) == :ok
    assert status()[:vm_memory_high_watermark] == {:absolute, Helpers.memory_unit_absolute(10, "")}
  end

  test "validate: a single absolute integer with an invalid memory unit fails ", context do
    assert @command.validate(["absolute","10bytes"], context[:opts]) == {:validation_failure, {:bad_argument, "Invalid units."}}
  end

  test "validate: a single absolute float with a valid memory unit fails ", context do
    assert @command.validate(["absolute","10.0MB"], context[:opts]) == {:validation_failure, {:bad_argument, "The threshold should be an integer."}}
  end

  test "validate: a single absolute float with an invalid memory unit fails ", context do
    assert @command.validate(["absolute","10.0bytes"], context[:opts]) == {:validation_failure, {:bad_argument, "The threshold should be an integer."}}
  end

  test "validate: a single absolute string fails ", context do
    assert @command.validate(["absolute","large"], context[:opts]) == {:validation_failure, :bad_argument}
  end

  test "validate: a single absolute string with a valid unit  fails ", context do
    assert @command.validate(["absolute","manyGB"], context[:opts]) == {:validation_failure, :bad_argument}
  end

  test "run: a single absolute integer with memory units return ok", context do
    Helpers.memory_units
    |> Enum.each(fn mu ->
      arg = "10#{mu}"
      assert @command.run(["absolute",arg], context[:opts]) == :ok
      assert status()[:vm_memory_high_watermark] == {:absolute, Helpers.memory_unit_absolute(10, mu)}
    end)
  end

  test "run: low watermark sets alarm", context do
    old_watermark = status()[:vm_memory_high_watermark]
    on_exit(fn() ->
      args = case old_watermark do
        {:absolute, val} -> ["absolute", to_string(val)];
        other            -> [to_string(other)]
      end
      @command.run(args, context[:opts])
    end)
    ## this will trigger an alarm
    @command.run(["absolute", "2000"], context[:opts])

    assert [:memory] == status()[:alarms]
  end

  test "banner: absolute memory request prints info message", context do
    assert @command.banner(["absolute", "10"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to 10 bytes .../

    assert @command.banner(["absolute", "-10"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to -10 bytes .../

    assert @command.banner(["absolute", "sandwich"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to sandwich bytes .../
  end

  test "banner, relative memory", context do
    assert @command.banner(["0.7"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to 0.7 .../

    assert @command.banner(["-0.7"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to -0.7 .../

    assert @command.banner(["sandwich"], context[:opts])
      =~ ~r/Setting memory threshold on #{get_rabbit_hostname()} to sandwich .../
  end
end

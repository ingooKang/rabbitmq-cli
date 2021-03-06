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


defmodule ListTopicPermissionsCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command RabbitMQ.CLI.Ctl.Commands.ListTopicPermissionsCommand

  @vhost "test1"
  @user "user1"
  @password "password"
  @root   "/"
  @default_timeout :infinity
  @default_options %{vhost: "/", table_headers: true}

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()

    add_vhost(@vhost)
    add_user(@user, @password)
    set_topic_permissions(@user, @vhost, "amq.topic", "^a", "^b")
    set_topic_permissions(@user, @vhost, "topic1", "^a", "^b")

    on_exit([], fn ->
      clear_topic_permissions(@user, @vhost)
      delete_user(@user)
      delete_vhost @vhost
    end)

    :ok
  end

  setup context do
    {
      :ok,
      opts: %{
        node: get_rabbit_hostname(),
        timeout: context[:test_timeout],
        vhost: "/"
      }
    }
  end

  test "merge_defaults adds default vhost" do
    assert @command.merge_defaults([], %{}) == {[], @default_options}
  end

  test "merge_defaults: defaults can be overridden" do
    assert @command.merge_defaults([], %{}) == {[], @default_options}
    assert @command.merge_defaults([], %{vhost: "non_default"}) == {[], %{vhost: "non_default",
                                                                          table_headers: true}}
  end

  test "validate: does not expect any parameter" do
    assert @command.validate(["extra"], %{}) == {:validation_failure, :too_many_args}
  end

  test "run: throws a badrpc when instructed to contact an unreachable RabbitMQ node" do
    target = :jake@thedog
    opts = %{node: target, timeout: :infinity, vhost: "/"}

    assert @command.run([], opts) == {:badrpc, :nodedown}
  end

  @tag test_timeout: @default_timeout, vhost: @vhost
  test "run: specifying a vhost returns the topic permissions for the targeted vhost", context do
    permissions = @command.run([], Map.merge(context[:opts], %{vhost: @vhost}))
    assert Enum.count(permissions) == 2
    assert Enum.sort(permissions) == [
        [user: @user, exchange: "amq.topic", write: "^a", read: "^b"],
        [user: @user, exchange: "topic1", write: "^a", read: "^b"]
    ]
  end

  @tag vhost: @root
  test "banner", context do
    ctx = Map.merge(context[:opts], %{vhost: @vhost})
    assert @command.banner([], ctx )
      =~ ~r/Listing topic permissions for vhost \"#{Regex.escape(ctx[:vhost])}\" \.\.\./
  end
end

# -*- coding: utf-8 -*-
#
# 一番シンプルな使い方
#
require "bundler/setup"
Bundler.require(:default)

FileUtils.rm_f(Dir["*.sqlite3"])

database_config = {
  "blue"  => {"adapter" => "sqlite3", "database" => "blue.sqlite3"},
  "green" => {"adapter" => "sqlite3", "database" => "green.sqlite3"},
}.with_indifferent_access

begin
  ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT)
  ActiveSupport::LogSubscriber.colorize_logging = false
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.configurations = database_config # migration を実行するため kamome 用の shard_names を環境と見なして設定

  database_config.keys.each do |key|
    ActiveRecord::Base.establish_connection(key)
    silence_stream(STDOUT) do
      ActiveRecord::Schema.define do
        create_table :users, force: true do |t|
        end
      end
    end
  end
end

# Kamome の初期設定
Kamome.config.database_config = database_config
ActiveRecord::Base.include(Kamome::Model)

# 対応させるモデルには kamome を記述
class User < ActiveRecord::Base
  kamome
end

# 使い方
Kamome.anchor(:blue) do
  User.create!
  User.count                    # => 1

  Kamome.anchor(:green) do
    User.count                  # => 0
  end
end
# >>    (0.1ms)  begin transaction
# >>   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >>    (0.7ms)  commit transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >>    (0.2ms)  SELECT COUNT(*) FROM "users"

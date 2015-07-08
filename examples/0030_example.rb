# -*- coding: utf-8 -*-
#
# User.destroy_all で user.articles を巻き込んで消す方法の検証
#

require "bundler/setup"
Bundler.require(:default)

FileUtils.rm_f(Dir["*.sqlite3"])

database_config = {
  "blue"    => {"adapter" => "sqlite3", "database" => "blue.sqlite3"},
  "green"   => {"adapter" => "sqlite3", "database" => "green.sqlite3"},
}.with_indifferent_access

database_config_all = database_config.merge({
    "master"  => {"adapter" => "sqlite3", "database" => "master.sqlite3"},
  }.with_indifferent_access)

begin
  ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
  ActiveSupport::LogSubscriber.colorize_logging = false
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.configurations = database_config_all # migration を実行するため kamome 用の shard_names を環境と見なして設定

  database_config_all.keys.each do |key|
    ActiveRecord::Base.establish_connection(key.to_sym)
    silence_stream(STDOUT) do
      ActiveRecord::Schema.define do
        create_table :users, force: true do |t|
          t.string :name
        end
        create_table :articles, force: true do |t|
          t.belongs_to :user
        end
      end
    end
  end
  ActiveRecord::Base.establish_connection(:master)
end

# Kamome の初期設定
Kamome.config.database_config = database_config
ActiveRecord::Base.include(Kamome::Model)

class User < ActiveRecord::Base
  has_many :articles, :dependent => :destroy

  # これで切り替える
  around_destroy(prepend: true) do |user, block|
    Kamome.anchor({1 => :blue, 2 => :green}[user.id]) do
      logger.tagged("around_destroy for user:#{user.id}", &block)
    end
  end
end

class Article < ActiveRecord::Base
  kamome
  belongs_to :user
end

Kamome.target = :blue
Kamome.anchor(:blue)  { User.create!.articles.create! }
Kamome.anchor(:green) { User.create!.articles.create! }
[User.count, Kamome.anchor(:blue){Article.count}, Kamome.anchor(:green){Article.count}] # => [2, 1, 1]
User.destroy_all
[User.count, Kamome.anchor(:blue){Article.count}, Kamome.anchor(:green){Article.count}] # => [0, 0, 0]
# >> Kamome: nil => :blue
# >> Kamome: :blue => :blue
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue]    (0.8ms)  commit transaction
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.3ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 1]]
# >> [blue]    (1.1ms)  commit transaction
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green]    (0.9ms)  commit transaction
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 2]]
# >> [green]    (1.0ms)  commit transaction
# >> Kamome: :green => :blue
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >>   User Load (0.1ms)  SELECT "users".* FROM "users"
# >>    (0.1ms)  begin transaction
# >> Kamome: :blue => :blue
# >> [blue] [around_destroy for user:1]   Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."user_id" = ?  [["user_id", 1]]
# >> [blue] [around_destroy for user:1]    (0.0ms)  begin transaction
# >> [blue] [around_destroy for user:1]   SQL (0.2ms)  DELETE FROM "articles" WHERE "articles"."id" = ?  [["id", 1]]
# >> [blue] [around_destroy for user:1]    (0.9ms)  commit transaction
# >> [blue] [around_destroy for user:1]   SQL (0.1ms)  DELETE FROM "users" WHERE "users"."id" = ?  [["id", 1]]
# >> Kamome: :blue => :blue
# >>    (0.7ms)  commit transaction
# >>    (0.0ms)  begin transaction
# >> Kamome: :blue => :green
# >> [green] [around_destroy for user:2]   Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."user_id" = ?  [["user_id", 2]]
# >> [green] [around_destroy for user:2]    (0.0ms)  begin transaction
# >> [green] [around_destroy for user:2]   SQL (0.4ms)  DELETE FROM "articles" WHERE "articles"."id" = ?  [["id", 1]]
# >> [green] [around_destroy for user:2]    (0.9ms)  commit transaction
# >> [green] [around_destroy for user:2]   SQL (0.1ms)  DELETE FROM "users" WHERE "users"."id" = ?  [["id", 2]]
# >> Kamome: :green => :blue
# >>    (0.7ms)  commit transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue

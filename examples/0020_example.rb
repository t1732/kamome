# -*- coding: utf-8 -*-
#
# トランザクションについての検証
#
# 検証手順
# ・User はマスター。Article は水平分割対象。
# ・各トランザクション内で行う
# ・blue と green でそれぞれ User.create!.articles.create! を実行し、最後に例外を発生。
# ・[User, blueのArticle, greenのArticle] のレコード数を取得した結果をまとめ。
# ・Kamome.target の初期値は blue とする。
#
# |-----------------------------------+------------+-----------------------------------------------------------------------------------------------|
# | 種類                              | レコード数 | 備考                                                                                          |
# |-----------------------------------+------------+-----------------------------------------------------------------------------------------------|
# |                                   | [2, 1, 1]  | transaction が無いため何もロールバックされていない                                            |
# | ActiveRecord::Base.transaction    | [0, 1, 1]  | master のみロールバックされている                                                             |
# | User.transaction                  | [0, 1, 1]  | User は水平分割対象ではないため master のみロールバックされている                             |
# | Article.transaction               | [2, 0, 1]  | Kamome.target が blue だったため Article.transaction が blue のみを対象としてロールバックした |
# | Kamome.transaction                | [2, 0, 1]  | Kamome.target が blue だったため Kamome.transaction が blue のみを対象としてロールバックした  |
# | Kamome.transaction(:blue)         | [2, 0, 1]  | 明示的に blue のみをロールバックさせた                                                        |
# | Kamome.transaction(:green)        | [2, 1, 0]  | 明示的に green のみをロールバックさせた                                                       |
# | Kamome.transaction(:blue, :green) | [2, 0, 0]  | 明示的に blue green の両方をロールバックさせた                                                |
# | Kamome.all_transaction            | [2, 0, 0]  | 水平分割用のDBすべて (blue と green) をロールバックさせた                                     |
# | Kamome.full_transaction           | [0, 0, 0]  | master を含め、水平分割用DBをロールバックさせた                                               |
# |-----------------------------------+------------+-----------------------------------------------------------------------------------------------|

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

# 綺麗にする
db_clean = -> {
  database_config_all.keys.each do |key|
    ActiveRecord::Base.establish_connection(key.to_sym)
    ActiveRecord::Base.connection.tables.each do |table|
      silence_stream(STDOUT) do
        ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
      end
    end
  end
  ActiveRecord::Base.establish_connection(:master)
}

# Kamome の初期設定
Kamome.config.database_config = database_config
ActiveRecord::Base.include(Kamome::Model)

class User < ActiveRecord::Base
  has_many :articles, :dependent => :destroy
end

class Article < ActiveRecord::Base
  kamome
  belongs_to :user
end

Kamome.target = :blue

ActiveRecord::Base.connection_config # => {:adapter=>"sqlite3", :database=>"master.sqlite3"}

code = -> {
  Kamome.anchor(:blue)  { User.create!.articles.create! }
  Kamome.anchor(:green) { User.create!.articles.create! }
  raise
}

counts = -> {
  [
    User.count,
    Kamome.anchor(:blue)  { Article.count },
    Kamome.anchor(:green) { Article.count },
  ].tap { db_clean.call }
}

                                    code.call   rescue $!; counts.call # => [2, 1, 1]
ActiveRecord::Base.transaction    { code.call } rescue $!; counts.call # => [0, 1, 1]
User.transaction                  { code.call } rescue $!; counts.call # => [0, 1, 1]
Article.transaction               { code.call } rescue $!; counts.call # => [2, 0, 1]
Kamome.transaction                { code.call } rescue $!; counts.call # => [2, 0, 1]
Kamome.transaction(:blue)         { code.call } rescue $!; counts.call # => [2, 0, 1]
Kamome.transaction(:green)        { code.call } rescue $!; counts.call # => [2, 1, 0]
Kamome.transaction(:blue, :green) { code.call } rescue $!; counts.call # => [2, 0, 0]
Kamome.all_transaction            { code.call } rescue $!; counts.call # => [2, 0, 0]
Kamome.full_transaction           { code.call } rescue $!; counts.call # => [0, 0, 0]

# >> Kamome: nil => :blue
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  begin transaction
# >> [blue]   SQL (0.3ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue]    (1.2ms)  commit transaction
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.3ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 1]]
# >> [blue]    (1.0ms)  commit transaction
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green]    (0.9ms)  commit transaction
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.3ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 2]]
# >> [green]    (1.1ms)  commit transaction
# >> Kamome: :green => :blue
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >>    (0.2ms)  begin transaction
# >> Kamome: :blue => :blue
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.3ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 3]]
# >> [blue]    (1.0ms)  commit transaction
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]   SQL (0.1ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 4]]
# >> [green]    (1.0ms)  commit transaction
# >> Kamome: :green => :blue
# >>    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >>    (0.2ms)  begin transaction
# >> Kamome: :blue => :blue
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 3]]
# >> [blue]    (1.1ms)  commit transaction
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]   SQL (0.1ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 4]]
# >> [green]    (1.1ms)  commit transaction
# >> Kamome: :green => :blue
# >>    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >>    (0.1ms)  begin transaction
# >> Kamome: :blue => :blue
# >> [blue]    (0.2ms)  begin transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue]    (1.0ms)  commit transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 3]]
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green]    (0.5ms)  commit transaction
# >> [green]    (0.0ms)  begin transaction
# >> [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 4]]
# >> [green]    (1.1ms)  commit transaction
# >> Kamome: :green => :blue
# >>    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [blue transaction]    (0.0ms)  begin transaction
# >> [blue transaction] Kamome: :blue => :blue
# >> [blue transaction] [blue]    (0.1ms)  begin transaction
# >> [blue transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [blue]    (0.9ms)  commit transaction
# >> [blue transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 5]]
# >> [blue transaction] Kamome: :blue => :blue
# >> [blue transaction] Kamome: :blue => :green
# >> [blue transaction] [green]    (0.0ms)  begin transaction
# >> [blue transaction] [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green]    (1.0ms)  commit transaction
# >> [blue transaction] [green]    (0.0ms)  begin transaction
# >> [blue transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 6]]
# >> [blue transaction] [green]    (1.1ms)  commit transaction
# >> [blue transaction] Kamome: :green => :blue
# >> [blue transaction]    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [blue transaction]    (0.0ms)  begin transaction
# >> [blue transaction] Kamome: :blue => :blue
# >> [blue transaction] [blue]    (0.1ms)  begin transaction
# >> [blue transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [blue]    (1.0ms)  commit transaction
# >> [blue transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 7]]
# >> [blue transaction] Kamome: :blue => :blue
# >> [blue transaction] Kamome: :blue => :green
# >> [blue transaction] [green]    (0.0ms)  begin transaction
# >> [blue transaction] [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green]    (0.8ms)  commit transaction
# >> [blue transaction] [green]    (0.1ms)  begin transaction
# >> [blue transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 8]]
# >> [blue transaction] [green]    (1.0ms)  commit transaction
# >> [blue transaction] Kamome: :green => :blue
# >> [blue transaction]    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [green transaction]    (0.0ms)  begin transaction
# >> [green transaction] Kamome: :blue => :blue
# >> [green transaction] [blue]    (0.1ms)  begin transaction
# >> [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green transaction] [blue]    (1.0ms)  commit transaction
# >> [green transaction] [blue]    (0.0ms)  begin transaction
# >> [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 9]]
# >> [green transaction] [blue]    (1.0ms)  commit transaction
# >> [green transaction] Kamome: :blue => :blue
# >> [green transaction] Kamome: :blue => :green
# >> [green transaction] [green]    (0.0ms)  begin transaction
# >> [green transaction] [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [green transaction] [green]    (0.5ms)  commit transaction
# >> [green transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 10]]
# >> [green transaction] Kamome: :green => :blue
# >> [green transaction]    (0.3ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [blue transaction]    (0.0ms)  begin transaction
# >> [blue transaction] [green transaction]    (0.0ms)  begin transaction
# >> [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [blue transaction] [green transaction] [blue]    (0.2ms)  begin transaction
# >> [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green transaction] [blue]    (0.5ms)  commit transaction
# >> [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 11]]
# >> [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [blue transaction] [green transaction] Kamome: :blue => :green
# >> [blue transaction] [green transaction] [green]    (0.0ms)  begin transaction
# >> [blue transaction] [green transaction] [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green transaction] [green]    (1.0ms)  commit transaction
# >> [blue transaction] [green transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 12]]
# >> [blue transaction] [green transaction] Kamome: :green => :blue
# >> [blue transaction] [green transaction]    (0.4ms)  rollback transaction
# >> [blue transaction]    (0.4ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [blue transaction]    (0.0ms)  begin transaction
# >> [blue transaction] [green transaction]    (0.0ms)  begin transaction
# >> [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [blue transaction] [green transaction] [blue]    (0.2ms)  begin transaction
# >> [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green transaction] [blue]    (0.9ms)  commit transaction
# >> [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 13]]
# >> [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [blue transaction] [green transaction] Kamome: :blue => :green
# >> [blue transaction] [green transaction] [green]    (0.1ms)  begin transaction
# >> [blue transaction] [green transaction] [green]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [blue transaction] [green transaction] [green]    (0.9ms)  commit transaction
# >> [blue transaction] [green transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 14]]
# >> [blue transaction] [green transaction] Kamome: :green => :blue
# >> [blue transaction] [green transaction]    (0.4ms)  rollback transaction
# >> [blue transaction]    (0.4ms)  rollback transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue
# >> [master transaction]    (0.1ms)  begin transaction
# >> [master transaction] [blue transaction]    (0.0ms)  begin transaction
# >> [master transaction] [blue transaction] [green transaction]    (0.0ms)  begin transaction
# >> [master transaction] [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [master transaction] [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "users" DEFAULT VALUES
# >> [master transaction] [blue transaction] [green transaction] [blue]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 15]]
# >> [master transaction] [blue transaction] [green transaction] Kamome: :blue => :blue
# >> [master transaction] [blue transaction] [green transaction] Kamome: :blue => :green
# >> [master transaction] [blue transaction] [green transaction] [green]   SQL (0.0ms)  INSERT INTO "users" DEFAULT VALUES
# >> [master transaction] [blue transaction] [green transaction] [green]   SQL (0.2ms)  INSERT INTO "articles" ("user_id") VALUES (?)  [["user_id", 16]]
# >> [master transaction] [blue transaction] [green transaction] Kamome: :green => :blue
# >> [master transaction] [blue transaction] [green transaction]    (0.5ms)  rollback transaction
# >> [master transaction] [blue transaction]    (0.5ms)  rollback transaction
# >> [master transaction]    (0.5ms)  rollback transaction
# >>    (0.2ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :blue => :blue
# >> Kamome: :blue => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "articles"
# >> Kamome: :green => :blue

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'kamome'

# 水平分割の設定情報
config_path = File.join(File.dirname(__FILE__), "./config/kamome.yml")
Kamome.configure do |config|
  config.config_path = config_path
end

# master を含めてすべての設定
database_config_all = YAML.load_file(config_path)["test"]
database_config_all.update({"master" => {"adapter" => "sqlite3", "database" => ".db/master_test.sqlite3"}})

ActiveRecord::Base.configurations = database_config_all
ActiveRecord::Migration.verbose = false
# ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))

database_config_all.keys.each do |db_key|
  ActiveRecord::Base.establish_connection(db_key.to_sym)
  ActiveRecord::Schema.define do
    create_table :users, force: true do |t|
    end
    create_table :articles, force: true do |t|
      t.belongs_to :user
      t.string :name, null: false
    end
  end
end

ActiveRecord::Base.establish_connection(:master) # User を master に向けるため

ActiveRecord::Base.include(Kamome::Model)

# 水平分割しないモデル
class User < ActiveRecord::Base
  has_many :articles, :dependent => :destroy
end

# 水平分割するモデル
class Article < ActiveRecord::Base
  kamome
  validates :name, presence: true
end

RSpec.configure do |config|
  config.before(:each) do
    database_config_all.keys.each do |name|
      ActiveRecord::Base.establish_connection(name.to_sym)
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
      end
    end
    ActiveRecord::Base.establish_connection(:master) # User を master に向けるため
  end

  config.after(:suite) do
    FileUtils.rm_r("#{__dir__}/../.db", secure: true, force: true)
  end
end

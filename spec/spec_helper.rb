$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'kamome'

config_path = File.join(File.dirname(__FILE__), "./config/kamome.yml")
ActiveRecord::Base.configurations = YAML.load_file(config_path)["test"]
ActiveRecord::Migration.verbose = false

Kamome.configure do |config|
  config.config_path = config_path
end

ActiveRecord::Base.establish_connection(:blue)
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
end
ActiveRecord::Base.establish_connection(:green)
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
end

ActiveRecord::Base.send(:include, Kamome::Model)
class User < ActiveRecord::Base
  kamome
end

RSpec.configure do |config|
  config.before(:each) do
    %w(blue green).each do |name|
      ActiveRecord::Base.establish_connection(name.to_sym)
      ActiveRecord::Base.connection.execute("DELETE FROM users;")
    end
  end

  config.after(:suite) do
    FileUtils.rm_r(File.join(File.dirname(__FILE__), "../.db"), secure: true, force: true)
  end
end

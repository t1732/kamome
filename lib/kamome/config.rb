# config/initializers/kamome.rb
#
#   Rails.application.config.to_prepare do
#     Kamome.configure do |config|
#       config.config_path = Rails.root.join("config/kamome.yml").expand_path
#     end
#   end
module Kamome
  class Config
    attr_accessor :config_path, :database_config

    def loading
      if File.exist?(config_path)
        conf = YAML.load(File.read(config_path)).with_indifferent_access
        self.database_config = conf[rails_env]
      else
        raise ConfigFileNotFound.new(config_path)
      end
    end

    def shard_names
      database_config.keys
    end

    def rails_env
      defined?(Rails) ? Rails.env : (ENV['RAILS_ENV'] || 'test')
    end
  end

  class << self
    def configure(&block)
      yield config
      config.tap{|c| c.loading }
    end

    def config
      @config ||= Config.new
    end
  end
end

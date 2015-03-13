module Kamome
  class Proxy
    def initialize(target_key)
      @target_key = target_key
      @constant_name = @target_key.to_s.singularize.camelcase
      create_proxy_model
    end

    def connection
      proxy_model.connection
    end

    def proxy_model
      self.class.const_get(@constant_name)
    end

    def create_proxy_model
      model = Class.new(ActiveRecord::Base)
      self.class.const_set @constant_name, model
      model.establish_connection(Kamome.config.database_config.fetch(@target_key))
      model
    end
  end
end

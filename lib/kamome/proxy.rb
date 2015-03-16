module Kamome
  class Proxy
    def initialize(target_key)
      @target_key = target_key
      @model_name = "#{@target_key}_connection_model".to_s.classify
      create_proxy_model
    end

    def connection
      proxy_model.connection
    end

    def proxy_model
      self.class.const_get(@model_name)
    end

    def create_proxy_model
      Class.new(ActiveRecord::Base).tap do |model|
        self.class.const_set @model_name, model
        model.establish_connection(Kamome.config.database_config.fetch(@target_key))
      end
    end
  end
end

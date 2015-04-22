module Kamome
  class BaseError < StandardError
    def initialize(message)
      super("\e[31m#{message}\e[0m")
    end
  end

  class TargetNotFound < BaseError
    def initialize(message)
      super("Kamome.target has not been set. [#{message}]")
    end
  end

  class ConfigFileNotFound < BaseError
    def initialize(config_path)
      super("Kamome config not found #{config_path}")
    end
  end
end

require 'singleton'

module Kamome
  class Ship
    include Singleton

    def self.unload(target_key)
      instance.unload(target_key)
    end

    def unload(target_key)
      proxies[target_key] ||= Proxy.new(target_key)
    end

    def proxies
      @proxies ||= {}.with_indifferent_access
    end
  end
end

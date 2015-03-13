require 'singleton'

module Kamome
  class ProxyStation
    include Singleton

    def self.checkout(target_key)
      instance.checkout(target_key)
    end

    def checkout(target_key)
      proxies[target_key] ||= Proxy.new(target_key)
    end

    def proxies
      @proxies ||= {}.with_indifferent_access
    end
  end
end

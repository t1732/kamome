module Kamome
  module Connection
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :connection, :kamome
      end
    end

    class_methods do
      def kamome_enable?
        true
      end

      def connection_with_kamome
        if kamome_enable?
          target_key = Kamome.anchor_key || Kamome.target
          raise TargetNotFound if target_key.blank?
          Ship.unload(target_key).connection
        else
          connection_without_kamome
        end
      end
    end
  end
end

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
          raise TargetNotFound if Kamome.target.blank?
          Ship.unload(Kamome.target).connection
        else
          connection_without_kamome
        end
      end
    end
  end
end

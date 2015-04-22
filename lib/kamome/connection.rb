module Kamome
  concern :Connection do
    included do
      singleton_class.prepend(ConnectionWrapper)
    end

    class_methods do
      def kamome_enable?
        true
      end
    end
  end

  module ConnectionWrapper
    def connection
      raise TargetNotFound, "#{name}.#{__method__}" unless Kamome.target
      Ship.unload(Kamome.target).connection
    end
  end
end

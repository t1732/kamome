module Kamome
  concern :Model do
    class_methods do
      def kamome
        include Connection
      end

      def kamome_enable?
        false
      end
    end

    def kamome_enable?
      self.class.kamome_enable?
    end
  end
end

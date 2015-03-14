module Kamome
  class Railtie < Rails::Railtie
    initializer "kamome.on_load_active_record" do
      ActiveSupport.on_load(:active_record) do
        include Kamome::Model
      end
    end

    initializer "kamome.configure" do
      Kamome.configure do |config|
        config.config_path = Rails.root.join("config/kamome.yml")
      end
    end

    rake_tasks do
      Dir[File.join(__dir__, "../tasks/**/*.rake")].each { |f| load f }
    end
  end
end

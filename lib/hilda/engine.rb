module Hilda
  class Engine < ::Rails::Engine
    isolate_namespace Hilda

    config.autoload_paths += %W(#{config.root}/app/jobs/concerns #{config.root}/app/modules/concerns)

    initializer "hilda.id_translators" do |app|
      DurhamRails::IdTranslations.set_active_fedora_translators
    end

    initializer "hilda.assets.precompile" do |app|
      app.config.assets.precompile += %w( hilda/logo.png )
    end

    config.generators do |g|
      g.test_framework      :rspec,        :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end
  end
end

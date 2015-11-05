module HildaDurham
  class Engine < ::Rails::Engine
    isolate_namespace HildaDurham

    config.autoload_paths += %W(#{config.root}/app/jobs/concerns #{config.root}/app/modules/concerns)

    config.generators do |g|
      g.test_framework      :rspec,        :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end
  end
end

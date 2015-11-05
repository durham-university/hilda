require 'rsolr'

namespace :hilda do
  desc "create process templates"
  task "create_templates" => :environment do
    Hilda::IngestionProcessTemplate.new_template('Test process','test','Testing process useful only in system development') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver) \
        .add_module(Hilda::Modules::FileMetadata, metadata_fields: {
          title: {label: 'Title', type: :string},
          test: {label: 'Test', type: :string}
         }) \
        .add_module(Hilda::Modules::DebugModule, sleep: 20 ) \
        .add_module(Hilda::Modules::Preservation) \
        .add_module(Hilda::Modules::DebugModule,
          param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
          info_template: 'hilda/modules/debug_info',
          sleep: 20 )
    end
  end
end

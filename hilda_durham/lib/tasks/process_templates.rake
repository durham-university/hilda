require 'rsolr'

namespace :hilda_durham do
  desc "create process templates"
  task "create_templates" => :environment do
    Hilda::IngestionProcessTemplate.new_template('Durham test process','durham_test','Testing process useful only in system development') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver, module_group: 'Upload') \
        .add_module(Hilda::Modules::BulkFileMetadata, module_group: 'Metadata',
          metadata_fields: {
            title: {label: 'Title', type: :string }
          }) \
        .add_module(HildaDurham::Modules::SchmitLinker, module_group: 'Metadata') \
        .add_module(Hilda::Modules::DetectContentType, module_group: 'Ingest', allow_only: ['image/tiff']) \
        .add_module(HildaDurham::Modules::OublietteIngest, module_group: 'Ingest') \
        .add_module(HildaDurham::Modules::TrifleIngest, module_group: 'Ingest') # \
#        .add_module(Hilda::Modules::DebugModule,
#          module_group: 'Debug',
#          param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
#          info_template: 'hilda/modules/debug_info',
#          sleep: 20 )
    end
  end
end

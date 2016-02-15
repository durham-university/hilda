require 'rsolr'

namespace :hilda_durham do
  desc "create process templates"
  task "create_templates" => :environment do
    Hilda::IngestionProcessTemplate.new_template('Durham test process','durham_test','Testing process useful only in system development') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver) \
        .add_module(Hilda::Modules::FileMetadata, metadata_fields: {
          title: {label: 'Title', type: :string, default: '__key__'}
         }) \
        .add_module(HildaDurham::Modules::SchmitLinker) \
        .add_module(Hilda::Modules::DetectContentType) \
        .add_module(HildaDurham::Modules::OublietteIngest) \
        .add_module(HildaDurham::Modules::TrifleIngest) # \
#        .add_module(Hilda::Modules::DebugModule,
#          param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
#          info_template: 'hilda/modules/debug_info',
#          sleep: 20 )
    end
  end
end

require 'rsolr'

namespace :hilda_durham do
  desc "create process templates"
  task "create_templates" => :environment do
    Hilda::IngestionProcessTemplate.new_template('IIIF Ingestion','iiif_ingest','Ingest a batch of images into Oubliette and Trifle and generate IIIF metadata') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver, module_name: 'Upload_files', module_group: 'Upload') \
        .add_module(Hilda::Modules::BulkFileMetadata, module_name: 'Set_canvas_titles', module_group: 'Metadata',
          metadata_fields: {
            title: {label: 'Title', type: :string }
          }) \
        .add_module(HildaDurham::Modules::SchmitLinker, module_name: 'Select_collection', module_group: 'Metadata') \
        .add_module(Hilda::Modules::DetectContentType, module_name: 'Verify_content_type', module_group: 'Verify', allow_only: ['image/tiff']) \
        .add_module(HildaDurham::Modules::OublietteIngest, module_name: 'Ingest_to_Oubliette', module_group: 'Ingest') \
        .add_module(HildaDurham::Modules::TrifleIngest, module_name: 'Ingest_to_Trifle', module_group: 'Ingest') # \
#        .add_module(Hilda::Modules::DebugModule,
#          module_group: 'Debug',
#          param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
#          info_template: 'hilda/modules/debug_info',
#          sleep: 20 )
    end
  end
end

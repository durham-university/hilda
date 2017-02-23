require 'rsolr'

namespace :hilda_durham do
  desc "create process templates"
  task "create_templates" => :environment do
    Hilda::IngestionProcessTemplate.new_template('IIIF Ingestion','iiif_ingest','Ingest a batch of images into Oubliette and Trifle and generate IIIF metadata') do |template|
      template \
#        .add_start_module(Hilda::Modules::FileReceiver, module_name: 'Upload_files', module_group: 'Upload') \
        .add_start_module(Hilda::Modules::FileSelector, module_name: 'Select_files', module_group: 'Upload', root_path: '/digitisation_staging', filter_re: '(?i)^.*\\.tiff?$') \
        .add_module(HildaDurham::Modules::LibraryLinker, module_name: 'Select_library_record', module_group: 'Metadata', optional_module: true) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Manifest_metadata', module_group: 'Metadata', optional_module: true, default_disabled: true,
          param_defs: {
            title: {label: 'Title', type: :string},
            date: {label: 'Date of publication', type: :string, optional: true},
            author: {label: 'Author', type: :string, optional: true},
            description: {label: 'Description', type: :text, optional: true}
          }) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Digitisation_metadata', module_group: 'Metadata',
          param_defs: {
            subtitle: {label: 'Subtitle', type: :string, optional: true},
            digitisation_note: {label: 'Digitisation note', type: :text, optional: true}
          }) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Licence_and_attribution', module_group: 'Metadata',
          param_defs: {
            licence: {label: 'Licence', type: :select, collection: [
                'All rights reserved',
                'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'
              ], default: 'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'},
            attribution: {label: 'Attribution', type: :string, default: 'Provided by Durham Priory Library Project - a collaboration between Durham University and Durham Cathedral'}
          }) \
        .add_module(Hilda::Modules::BulkFileMetadata, module_name: 'Set_canvas_titles', module_group: 'Metadata',
          metadata_fields: {
            title: {label: 'Title', type: :string }
          }) \
        .add_module(HildaDurham::Modules::TrifleCollectionLinker, module_name: 'Select_IIIF_collection', module_group: 'Metadata') \
#        .add_module(Hilda::Modules::DetectContentType, module_name: 'Verify_content_type', module_group: 'Verify', allow_only: ['image/tiff']) \
        .add_module(Hilda::Modules::FitsValidator, module_name: 'Fits_validation', module_group: 'Verify', validation_rules: [
            { label: 'mimetype', xpath: '/xmlns:fits/xmlns:identification/xmlns:identity[@mimetype="image/tiff"]'},
            { label: 'well-formed', xpath: '/xmlns:fits/xmlns:filestatus/xmlns:well-formed[@toolname="Jhove"][text()="true"]'},
            { label: 'valid', xpath: '/xmlns:fits/xmlns:filestatus/xmlns:valid[@toolname="Jhove"][text()="true"]'},
            { label: 'uncompressed', xpath: '/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:compressionScheme[@toolname="Jhove"][text()="Uncompressed"]'},
            { label: 'colourspace', xpath: '/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:colorSpace[@toolname="Jhove"][(text()="RGB") or (text()="BlackIsZero")]'}
          ]) \
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

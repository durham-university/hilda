require 'rsolr'

namespace :hilda_durham do
  desc "create process templates"
  task "create_templates" => :environment do
    validation_rules = [
        { label: 'mimetype', xpath: '/xmlns:fits/xmlns:identification/xmlns:identity[@mimetype="image/tiff"]'},
        { label: 'well-formed', xpath: '/xmlns:fits/xmlns:filestatus/xmlns:well-formed[@toolname="Jhove"][text()="true"]'},
        { label: 'valid', xpath: '/xmlns:fits/xmlns:filestatus/xmlns:valid[@toolname="Jhove"][text()="true"]'},
        { label: 'uncompressed', xpath: '/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:compressionScheme[@toolname="Jhove"][text()="Uncompressed"]'},
        { label: 'colourspace', xpath: '/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:colorSpace[@toolname="Jhove"][(text()="RGB") or (text()="BlackIsZero") or (text()="WhiteIsZero")]'}
      ]
    
    file_selector_root = Rails.env.development? ? '/home/qgkb58/hydra/testdata' : '/shared_data/ingestion_temp'
    
    iiif_ingest = Hilda::IngestionProcessTemplate.new_template('IIIF Ingestion','iiif_ingest','Ingest a batch of images into Oubliette and Trifle and generate IIIF metadata') do |template|
      template \
#        .add_start_module(Hilda::Modules::FileReceiver, module_name: 'Upload_files', module_group: 'Upload') \
        .add_start_module(Hilda::Modules::FileSelector, module_name: 'Select_files', module_group: 'Upload', root_path: file_selector_root, filter_re: '(?i)^.*\\.tiff?$') \
        .add_module(HildaDurham::Modules::LibraryLinker, module_name: 'Select_library_record', module_group: 'Metadata', optional_module: true) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Manifest_metadata', module_group: 'Metadata', optional_module: true, default_disabled: true,
          param_defs: {
            date: {label: 'Date of publication', type: :string, optional: true},
            author: {label: 'Author', type: :string, optional: true},
            description: {label: 'Description', type: :text, optional: true}
          }) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Digitisation_metadata', module_group: 'Metadata',
          param_defs: {
            title: {label: 'Title', type: :string, graph_title: true},
            digitisation_note: {label: 'Digitisation note', type: :text, optional: true},
            tags: {label: 'Oubliette tags', type: :string, optional: true}
          }) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Conversion_profile', module_group: 'Metadata',
          param_defs: {
            conversion_profile: {label: 'Conversion profile', type: :select, collection: ['default'], default: 'default'},
          }) \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Licence_and_attribution', module_group: 'Metadata',
          param_defs: {
            licence: {label: 'Licence', type: :select, collection: [
                'All rights reserved',
                'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'
              ], default: 'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'},
            attribution: {label: 'Attribution', type: :string, default: 'Provided by Durham Priory Library Project - a collaboration between Durham University and Durham Cathedral'}
          }) \
        .add_module(Hilda::Modules::BulkFileMetadata, module_name: 'Set_canvas_metadata', module_group: 'Metadata',
          metadata_fields: {
            title: {label: 'Title', type: :string },
            image_record: {label: 'Image record', type: :string, optional: true },
            image_description: {label: 'Image description', type: :string, optional: true }
          },
          data_delimiter: ',',
          note: "image label, [image record], [image description]<br>Use double quotes around values if they contain any commas.") \
        .add_module(HildaDurham::Modules::TrifleCollectionLinker, module_name: 'Select_IIIF_collection', module_group: 'Metadata') \
        .add_module(Hilda::Modules::FitsValidator, module_name: 'Fits_validation', module_group: 'Verify', validation_rules: validation_rules) \
        .add_module(HildaDurham::Modules::OublietteIngest, module_name: 'Ingest_to_Oubliette', module_group: 'Ingest') \
        .add_module(HildaDurham::Modules::TrifleIngest, module_name: 'Ingest_to_Trifle', module_group: 'Ingest') # \
    end
    
    iiif_ingest.clone('Museum IIIF Ingest', 'museum_ingest', 'Ingest a batch of images into Oubliette and Trifle and generate IIIF metadata using museum presets') do |template|
      template.find_module('Select_files').param_values[:file_sorter] = 'HildaDurham::MuseumTools'
      template.find_module('Set_canvas_metadata').param_values[:defaults_setter] = 'HildaDurham::MuseumTools'
    end
    
    Hilda::IngestionProcessTemplate.new_template('Batch ingest','batch_ingest','Ingest a batch into Oubliette and Trifle and generate a series of IIIF manifests') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver, module_name: 'Upload_batch_metadata', module_group: 'Setup', graph_title: true, graph_title_prefix: "Batch ingest - ") \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Licence_and_attribution', module_group: 'Setup',
          param_defs: {
            licence: {label: 'Licence', type: :select, collection: [
                'All rights reserved',
                'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'
              ], default: 'http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode'},
            attribution: {label: 'Attribution', type: :string, default: ''}
          }) \
        .add_module(HildaDurham::Modules::TrifleCollectionLinker, module_name: 'Select_IIIF_collection', module_group: 'Setup') \
        .add_module(HildaDurham::Modules::LettersBatchIngest, module_name: 'Batch_ingest', module_group: 'Batch', 
                      ingest_root: '/digitisation_staging/', 
                      title_base: '',
                      validation_rules: validation_rules)
    end
    Hilda::IngestionProcessTemplate.new_template('Bagit ingest','bagit_ingest','Ingest a BagIt bag into Oubliette') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver, module_name: 'Upload_bagit', module_group: 'Setup') \
        .add_module(Hilda::Modules::ProcessMetadata, module_name: 'Deposit_metadata', module_group: 'Setup',
          param_defs: {
            title: {label: 'Title', type: :string, graph_title: true}
          }) \
        .add_module(Hilda::Modules::BagitValidator, module_name: 'Bagit_validation', module_group: 'Verify') \
        .add_module(HildaDurham::Modules::OublietteIngest, module_name: 'Ingest_to_Oubliette', module_group: 'Ingest')
    end
  end
end

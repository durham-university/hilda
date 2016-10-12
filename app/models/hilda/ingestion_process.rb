module Hilda
  class IngestionProcess < ActiveFedora::Base
    include Hilda::HydraModuleGraph
    include Hilda::ModuleGraphAutosave
    include Hilda::BackgroundRunnable
    include DurhamRails::WithFedoraFileService # Note that depending on options, a file system file service might be used instead

    property :owner, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#owner')

#    Bootstrap view generation requires this to work
#    def self.columns
#      []
#    end

    def file_service
      @file_service ||= begin
        options = file_service_options
        if options[:type].to_s.downcase == 'fedora'
          DurhamRails::Services::FedoraFileService.new(self, options)
        else
          DurhamRails::Services::FileService.new(options)
        end
      end
    end

    def file_service_options
      (Hilda.config['temp_file_service'] || {}).symbolize_keys
    end
  end
end

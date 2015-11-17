module Hilda
  class FileServiceFile < ActiveFedora::Base
    TYPE_FILE = 'file'.freeze
    TYPE_DIRECTORY = 'directory'.freeze

    property :title, multiple: false, predicate: ::RDF::Vocab::DC.title

    belongs_to :ingestion_process, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#ingestion_process'), class_name: 'Hilda::IngestionProcess'

    property :file_type, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#file_type')
    validates_inclusion_of :file_type, in: [TYPE_FILE, TYPE_DIRECTORY], allow_nil: false

    belongs_to :directory, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#file_location'), class_name: 'Hilda::FileServiceFile'
    validate :validate_directory_type

    # Ideally dependent: would be :destroy but ActiveFedora has a bug when you can reach
    # dependent objects in several different ways, in this case through the ingestion_process.
    has_many :file_service_files, as: :directory, class_name: 'Hilda::FileServiceFile', dependent: :nullify

    contains "file_contents", class_name: 'ActiveFedora::File'
    validate :validate_file_contents

    def directory?
      file_type == TYPE_DIRECTORY
    end

    private

      def validate_directory_type
        if directory.present?
          if directory.file_type != TYPE_DIRECTORY
            errors[:file_type] ||= []
            errors[:file_type] << 'File directory must be nil or a directory'
            return false
          end
        end
        true
      end

      def validate_file_contents
        if file_contents.content_changed? && file_type == TYPE_DIRECTORY && file_contents.content.present?
          errors[:file_contents] ||= []
          errors[:file_contents] << 'Directories cannot have file contents'
          return false
        end
        true
      end

  end
end

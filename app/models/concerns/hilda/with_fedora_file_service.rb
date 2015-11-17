module Hilda::WithFedoraFileService
  extend ActiveSupport::Concern

  included do
    has_many :file_service_files, as: :ingestion_process, class_name: 'Hilda::FileServiceFile', dependent: :destroy
  end

  def file_service
    @file_service ||= Hilda::Services::FedoraFileService.new(self)
  end

end

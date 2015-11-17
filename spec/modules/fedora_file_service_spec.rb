require 'rails_helper'
require 'shared/file_service'

RSpec.describe Hilda::Services::FedoraFileService do
  let( :graph ) { Hilda::IngestionProcess.new }
  let( :file_service ) { graph.file_service }

  let( :test_file1 ) { fixture('test1.jpg') }
  let( :test_file2 ) { fixture('test2.jpg') }
  let( :file_key ) { file_service.add_file('file1',nil,test_file1) }
  let( :file_key2 ) { file_service.add_file('file2',dir_key,test_file2) }
  let( :dir_key ) { file_service.add_dir('dir1') }
  let( :dir_key2 ) { file_service.add_dir('dir2',dir_key) }

  it_behaves_like 'file service' do
    let( :graph ) { Hilda::IngestionProcess.new }
    let( :file_service ) { graph.file_service }
  end



end

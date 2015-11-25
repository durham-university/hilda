require 'rails_helper'

RSpec.describe Hilda::Modules::DetectContentType do
  let( :file_service ) { graph.file_service }
  let( :file1_name ) { 'test1.jpg' }
  let( :file1_path ) { file_service.add_file(file1_name,nil,fixture(file1_name)) }
  let( :file2_name ) { 'test.zip' }
  let( :file2_path ) { file_service.add_file(file2_name,nil,fixture(file2_name)) }
  let( :file1 ) { fixture(file1) }
  let( :file2 ) { fixture(file2) }

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod_input ) {
    {
      source_files: {
        file1: { path: file1_path, original_filename: file1_name},
        file2: { path: file2_path, original_filename: file2_name}
      }
    }
  }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::DetectContentType, mod_params).tap do |mod|
      allow(mod).to receive(:module_input).and_return(mod_input)
    end
  }
  let( :mod_output ) {
    mod.log! :info, 'Starting module'
    mod.log! :info, 'Dummy message'
    mod.run_status = :running
    mod.module_output = {}
    mod.run_module
    mod.module_output
  }

  describe "#run_module" do
    it "correctly outputs content types" do
      expect(mod_output[:source_files]).not_to be_empty
      expect(mod_output[:source_files][:file1][:path]).to eql file1_path
      expect(mod_output[:source_files][:file1][:original_filename]).to eql file1_name
      expect(mod_output[:source_files][:file1][:content_type]).to eql 'image/jpeg'
      expect(mod_output[:source_files][:file2][:content_type]).to eql 'application/zip'
    end
  end
end

require 'rails_helper'

RSpec.describe Hilda::Modules::BagitValidator do
  let( :file1_mock ) { double('file1mock') }
  let( :file2_mock ) { double('file2mock') }
  let( :file_service ) { 
    graph.file_service.tap do |fs|
      allow(fs).to receive(:get_file).with('file1').and_yield(file1_mock)
      allow(fs).to receive(:get_file).with('file2').and_yield(file2_mock)
    end
  }

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { { } }  
  let( :mod_input ) {
    {
      source_files: {
        file1: { path: 'file1', original_filename: 'file1'},
        file2: { path: 'file2', original_filename: 'file2'}
      }
    }
  }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::BagitValidator, mod_params).tap do |mod|
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
    it "calls #validate_files" do
      expect(mod).to receive(:validate_files).and_return(true)
      expect(mod_output).to be_present 
    end
  end
  
  describe "#validate_files" do
    before {
      expect(mod).to receive(:validate_bag).twice.and_return(true)
    }
    it "runs bagit validation for each file" do
      file_service # setup file service mocks
      mod.validate_files(mod_input[:source_files])
      expect(mod.log.errors?).to eql(false)
    end
  end
  
  describe "#validate_bag" do
    let(:io_mock) { double('io_mock') }
    it "validates bag" do
      expect_any_instance_of(DurhamRails::BagitValidator).to receive(:read_bagit_zip_io).with(io_mock)
      expect_any_instance_of(DurhamRails::BagitValidator).to receive(:validate).and_return(true)
      mod.validate_bag(io_mock)
      expect(mod.run_status).not_to eql(:error)
    end
    
    it "handles read errors" do
      expect_any_instance_of(DurhamRails::BagitValidator).to receive(:read_bagit_zip_io) do 
        mod.log!(:error, "read error")
      end
      expect_any_instance_of(DurhamRails::BagitValidator).not_to receive(:validate)
      mod.validate_bag(io_mock)
      expect(mod.run_status).to eql(:error)
    end
    it "handles validation errors" do
      expect_any_instance_of(DurhamRails::BagitValidator).to receive(:read_bagit_zip_io).with(io_mock)
      expect_any_instance_of(DurhamRails::BagitValidator).to receive(:validate).and_return(false)
      mod.validate_bag(io_mock)
      expect(mod.run_status).to eql(:error)
    end
  end
  
end

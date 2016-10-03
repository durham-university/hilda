require 'rails_helper'

RSpec.describe Hilda::Modules::FitsValidator do
  let( :file_service ) { graph.file_service }
  let( :file1_name ) { 'test1.jpg' }
  let( :file1_path ) { file_service.add_file(file1_name,nil,fixture(file1_name)) }
  let( :file2_name ) { 'test.zip' }
  let( :file2_path ) { file_service.add_file(file2_name,nil,fixture(file2_name)) }
  let( :file1 ) { fixture(file1) }
  let( :file2 ) { fixture(file2) }

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :validation_xpath ) { '/xmlns:fits/xmlns:test' }
  let( :mod_params ) { 
    { validation_rules: [
      { label: 'mimetype', xpath: validation_xpath}
    ] }
  }
  let( :mod_input ) {
    {
      source_files: {
        file1: { path: file1_path, original_filename: file1_name},
        file2: { path: file2_path, original_filename: file2_name}
      }
    }
  }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::FitsValidator, mod_params).tap do |mod|
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
    it "runs fits and validation for each file" do
      expect(mod).to receive(:run_fits_io).twice.and_return([Nokogiri::XML('<fits></fits'),'',0])
      expect(mod).to receive(:run_validation_rules).twice.and_return(true)
      mod.validate_files
      expect(mod.log.errors?).to eql(false)
    end
  end
  
  describe "#run_validation_rules" do
    let(:xml) { Nokogiri::XML('<fits xmlns="http://hul.harvard.edu/ois/xml/ns/fits/fits_output"><test/></fits>') }
    it "checks xpath" do
      expect(xml).to receive(:xpath).with(validation_xpath).and_call_original
      mod.run_validation_rules('test label', xml)
      expect(mod.log.errors?).to eql(false)
    end
    context "with failing xml" do
      let( :validation_xpath ) { '/xmlns:fits/xmlns:test/xmlns:moo' }
      it "sets log error when rules fail" do
        mod.run_validation_rules('test label', xml)
        expect(mod.log.errors?).to eql(true)
      end
    end
  end
end

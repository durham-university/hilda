require 'rails_helper'

RSpec.describe Hilda::Modules::WithTempFiles do
  before {
    class ModClass
      include Hilda::ModuleBase
      include Hilda::Modules::WithTempFiles
    end
  }
  let( :mod ) {
    graph.add_start_module(ModClass).tap do |mod|
      mod.param_values = {}
    end
  }
  let( :file_service ) {
    double('file_service').tap do |file_service|
      allow(file_service).to receive(:add_file) do |file_name, in_path, io_or_path|
        "#{in_path || '/tmp'}/#{file_name}"
      end
      allow(file_service).to receive(:add_dir) do |file_name, in_path|
        "#{in_path || '/tmp'}/#{file_name}"
      end
    end
  }
  let( :graph ) {
    Hilda::ModuleGraph.new.tap do |graph|
      allow(graph).to receive(:file_service).and_return(file_service)
    end
  }

  after { Object.send(:remove_const,:ModClass) }

  describe "#file_basename" do
    it "works" do
      expect(mod.file_basename('/tmp/test/testing.pdf')).to eql 'testing.pdf'
      expect(mod.file_basename(OpenStruct.new(original_filename: 'moo.jpg'))).to eql 'moo.jpg'
    end
  end

  describe "#add_temp_file" do
    it "adds files to output" do
      expect(mod.param_values[:temp_files]).to be_nil
      mod.add_temp_file('/tmp/aaa',nil,'/tmp/abababab/test.pdf')
      mod.add_temp_file(nil,nil,'/tmp/abababab/moo.jpg')
      expect(mod.param_values[:temp_files]).to eql ['/tmp/aaa/test.pdf','/tmp/moo.jpg']
    end
    it "can use other temp file indices" do
      expect(mod.param_values[:temp_files]).to be_nil
      index = []
      mod.add_temp_file(nil,index,'/tmp/ababab/aaa')
      mod.add_temp_file(nil,index,'/tmp/ababab/bbb')
      expect(mod.param_values[:temp_files]).to be_nil
      expect(index).to eql ['/tmp/aaa','/tmp/bbb']
    end
  end

  describe "#add_temp_dir" do
    it "adds dirs to output" do
      expect(mod.param_values[:temp_files]).to be_nil
      mod.add_temp_dir('/tmp/ababab',nil,'baa')
      mod.add_temp_dir(nil,nil,'moo')
      expect(mod.param_values[:temp_files]).to eql ['/tmp/ababab/baa','/tmp/moo']
    end
    it "can use other temp file indices" do
      expect(mod.param_values[:temp_files]).to be_nil
      index = []
      mod.add_temp_dir('/tmp/ababab', index, 'baa')
      mod.add_temp_dir(nil, index, 'moo')
      expect(mod.param_values[:temp_files]).to be_nil
      expect(index).to eql ['/tmp/ababab/baa','/tmp/moo']
    end
  end

  describe "#reset_module" do
    it "removes temp files" do
      expect(mod).to receive(:remove_temp_files)
      mod.reset_module
    end
  end

  describe "#cleanup" do
    it "removes temp files" do
      expect(mod).to receive(:remove_temp_files)
      mod.cleanup
    end
  end

  describe "#remove_temp_files" do
    before { allow(file_service).to receive(:file_exists?).and_return(true) }
    it "removes a series of files" do
      temp_dir = mod.add_temp_file
      temp_file = mod.add_temp_file(temp_dir)
      expect(mod.param_values[:temp_files].length).to eql 2
      expect(file_service).to receive(:remove_file).twice
      mod.remove_temp_files
    end
    it "can use other indices" do
      index = []
      temp_dir = mod.add_temp_file(nil,index)
      temp_file = mod.add_temp_file(temp_dir,index)
      expect(index.length).to eql 2
      expect(file_service).to receive(:remove_file).twice
      mod.remove_temp_files(index)
    end
  end

end

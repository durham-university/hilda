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
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }

  after { mod.remove_temp_files }
  after { Object.send(:remove_const,:ModClass) }

  describe "add_temp_file" do
    it "adds files to output" do
      expect(mod.module_output[:temp_files]).to be_nil
      mod.add_temp_file('/tmp/aaa')
      mod.add_temp_file('/tmp/bbb')
      expect(mod.module_output[:temp_files]).to eql ['/tmp/aaa','/tmp/bbb']
    end
    it "can use other temp file indices" do
      expect(mod.module_output[:temp_files]).to be_nil
      index = []
      mod.add_temp_file('/tmp/aaa', index)
      mod.add_temp_file('/tmp/bbb', index)
      expect(mod.module_output[:temp_files]).to be_nil
      expect(index).to eql ['/tmp/aaa','/tmp/bbb']
    end
  end

  describe "#temp_dir" do
    let( :temp_dir ) { mod.temp_dir }
    it "uses system temp dir by default" do
      expect(temp_dir).to eql Dir.tmpdir
    end
    it "can be overridden" do
      graph[:temp_dir] = '/tmp/testtemp'
      expect(temp_dir).to eql '/tmp/testtemp'
    end
  end

  describe "#make_temp_file_path" do
    let( :temp_path ) { mod.make_temp_file_path }
    it "creates temp file paths" do
      expect(File.dirname(temp_path)).to eql Dir.tmpdir
      expect(File.exists?(temp_path)).to eql false
    end
  end

  describe "#sanitise_filename" do
    it "sanitises strange filenames" do
      expect(mod.sanitise_filename('../aaa < test.tmp')).not_to include '..'
      expect(mod.sanitise_filename('../test.tmp')).to end_with '.tmp'
      expect(mod.sanitise_filename('test/aaa.tmp')).not_to include '/'
      expect(mod.sanitise_filename('../aaa < test.tmp')).not_to include '<'
      expect(mod.sanitise_filename('../aaa > test.tmp')).not_to include '>'
      expect(mod.sanitise_filename('| aaa.tmp')).not_to include '|'
      expect(mod.sanitise_filename('aaa bbb.tmp')).not_to include ' '
    end
  end

  describe "#reset_module" do
    it "removes temp files" do
      expect(mod).to receive(:remove_temp_files).twice # Twice because there's one in a spec-wide before block
      mod.reset_module
    end
  end

  describe "#remove_temp_files" do
    it "removes a series of files" do
      temp_dir = mod.make_temp_file_path
      mod.add_temp_file(temp_dir)
      Dir.mkdir(temp_dir)
      temp_file = File.join(temp_dir,'temp_file')
      mod.add_temp_file(temp_file)
      File.new(temp_file,'wb').close
      expect(File.exists?(temp_file)).to eql true
      expect(File.exists?(temp_dir)).to eql true
      expect(mod.module_output[:temp_files].length).to eql 2
      mod.remove_temp_files
      expect(File.exists?(temp_file)).to eql false
      expect(File.exists?(temp_dir)).to eql false
    end
    it "can use other indices" do
      index = []
      temp_dir = mod.make_temp_file_path
      mod.add_temp_file(temp_dir,index)
      Dir.mkdir(temp_dir)
      temp_file = File.join(temp_dir,'temp_file')
      mod.add_temp_file(temp_file,index)
      File.new(temp_file,'wb').close
      expect(File.exists?(temp_file)).to eql true
      expect(File.exists?(temp_dir)).to eql true
      expect(index.length).to eql 2
      mod.remove_temp_files(index)
      expect(File.exists?(temp_file)).to eql false
      expect(File.exists?(temp_dir)).to eql false
    end
  end

end

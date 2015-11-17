require 'rails_helper'
require 'shared/file_service'

RSpec.describe Hilda::Services::FileService do
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :file_service ) { described_class.new(graph) }

  let( :test_file1 ) { fixture('test1.jpg') }
  let( :test_file2 ) { fixture('test2.jpg') }
  let( :file_key ) { file_service.add_file('file1',nil,test_file1).tap do |key| created_files << key end }
  let( :file_key2 ) { file_service.add_file('file2',dir_key,test_file2).tap do |key| created_files << key end }
  let( :dir_key ) { file_service.add_dir('dir1').tap do |key| created_files << key end }
  let( :dir_key2 ) { file_service.add_dir('dir2',dir_key).tap do |key| created_files << key end }

  let( :created_files ) { [] }
  after {
    created_files.reverse.each do |file|
      begin
        file_service.remove_file(file)
      rescue StandardError => e
      end
    end
  }

  it_behaves_like 'file service'

  describe "#add_file" do
    it "creates uses make_temp_file_path" do
      expect(file_service).to receive(:make_temp_file_path).with(dir_key,'file2').and_call_original
      file_key2 # create by referencing
    end
    it "creates a file on disk" do
      expect(File.exists?(file_key)).to eql true
    end
  end

  describe "#remove_file" do
    it "removes the file from disk" do
      expect(File.exists?(file_key)).to eql true
      expect(File.exists?(dir_key)).to eql true
      file_service.remove_file(file_key)
      expect(File.exists?(file_key)).to eql false
      expect(File.exists?(dir_key)).to eql true
      file_service.remove_file(dir_key)
      expect(File.exists?(dir_key)).to eql false
    end
  end

  describe "#add_dir" do
    it "creates uses make_temp_file_path" do
      expect(file_service).to receive(:make_temp_file_path).with(dir_key,'dir2').and_call_original
      dir_key2 # create by referencing
    end
    it "creates a file on disk" do
      expect(File.exists?(dir_key)).to eql true
    end
  end

  describe "#under_temp_dir?" do
    before { expect(file_service).to receive(:temp_dir).at_least(:once).and_return('/tmp') }
    it "returns true when under temp dir" do
      expect(file_service.send(:under_temp_dir?,'/tmp/test')).to eql true
      expect(file_service.send(:under_temp_dir?,'/tmp/test/test2')).to eql true
      expect(file_service.send(:under_temp_dir?,'/tmp/test/../aaa')).to eql true
    end
    it "returns false when not under temp dir" do
      expect(file_service.send(:under_temp_dir?,'/tmp/')).to eql false
      expect(file_service.send(:under_temp_dir?,'/tmp/../test')).to eql false
      expect(file_service.send(:under_temp_dir?,'/test/aaa')).to eql false
      expect(file_service.send(:under_temp_dir?,'tmp/aaa')).to eql false
    end
  end

  describe "#temp_dir" do
    it "returns Dir.tmpdir by default" do
      expect(file_service.send(:temp_dir)).to eql Dir.tmpdir
    end
    it "can be set explicitly in graph" do
      graph[:temp_dir]='/other_temp_dir'
      expect(file_service.send(:temp_dir)).to eql '/other_temp_dir'
    end
  end

  describe "#make_temp_file_path" do
    context "without any arguments" do
      let( :path ) { file_service.send(:make_temp_file_path) }
      it "returns a temp path" do
        expect(path).to start_with Dir.tmpdir
        expect(file_service.send(:under_temp_dir?,path)).to eql true
      end
    end
    context "with dir" do
      let( :path ) { file_service.send(:make_temp_file_path,dir_key) }
      it "returns a path under dir" do
        expect(path).to start_with dir_key
        expect(file_service.send(:under_temp_dir?,path)).to eql true
      end
    end
    context "with file name" do
      let( :path ) { file_service.send(:make_temp_file_path,dir_key,'test_file_name') }
      let( :path2 ) { file_service.send(:make_temp_file_path,dir_key,'test_file_name') }
      it "uses the file name" do
        expect(path).to end_with 'test_file_name'
      end
      it "can handle duplicates" do
        file = File.open(path,'wb')
        file.close
        begin
          expect(path).to end_with 'test_file_name'
          expect(path2).not_to end_with 'test_file_name'
          expect(file_service.send(:under_temp_dir?,path2)).to eql true
        ensure
          File.unlink(path)
        end
      end
      it "uses random file name if given a blank name" do
        allow(file_service).to receive(:temp_dir).and_return('/tmp')
        expect(file_service.send(:make_temp_file_path,nil,'').length).to be > 10
        expect(file_service.send(:make_temp_file_path,nil,nil).length).to be > 10
      end
    end
  end

  describe "#sanitise_filename" do
    it "sanitises file names" do
      expect(file_service.send(:sanitise_filename,'test_file')).to eql 'test_file'
      expect(file_service.send(:sanitise_filename,'test-file.pdf')).to eql 'test-file.pdf'
      expect(file_service.send(:sanitise_filename,'dir/test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'dir>test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'dir&test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'dir;test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'dir<test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'dir|test_file')).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,"dir\x00test_file")).to eql 'dir_test_file'
      expect(file_service.send(:sanitise_filename,'..')).to eql '__'
      expect(file_service.send(:sanitise_filename,'.')).to eql '_'
    end
  end

end

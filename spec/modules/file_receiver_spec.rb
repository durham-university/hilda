require 'rails_helper'

RSpec.describe Hilda::Modules::FileReceiver do
  let( :image_file1_uploaded ) {
    Rack::Test::UploadedFile.new(File.join(ActionController::TestCase.fixture_path, 'test1.jpg'), 'image/jpeg')
  }
  let( :image_file1 ) { fixture('test1.jpg') }
  let( :image_file2 ) { fixture('test2.jpg') }
  let( :zip_file ) { fixture('test.zip') }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::FileReceiver).tap do |mod|
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :sent_files ) { [image_file1, image_file2] }

  before {
    graph[:sent_files] = sent_files
  }
  after { mod.remove_temp_files }

  describe "#file_basename" do
    it "handles Strings" do
      expect(mod.file_basename('/tmp/testfile.zip')).to eql 'testfile.zip'
    end
    it "handles Files" do
      expect(mod.file_basename(image_file1)).to eql 'test1.jpg'
    end
    it "handles uploads" do
      expect(mod.file_basename(image_file1_uploaded)).to eql 'test1.jpg'
    end
  end

  describe "#make_copies_of_files" do
    let( :files ) { [image_file1, zip_file] }
    let( :new_files ) { mod.make_copies_of_files(files) }

    it "copies files" do
      expect(new_files.length).to eql 2
      expect(new_files[0]).to end_with 'test1.jpg'
      expect(new_files[1]).to end_with 'test.zip'
      expect(File.size(new_files[0])).to eql files[0].size
      expect(File.size(new_files[1])).to eql files[1].size
    end

    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.module_output[:temp_files].length).to eql 3
    end
  end

  describe "#unzip" do
    let( :new_files ) { mod.unzip(zip_file.path) }
    it "unzips file contents" do
      expect(new_files.length).to eql 2
      expect(new_files[0]).to end_with 'test1.jpg'
      expect(new_files[1]).to end_with 'test2.jpg'
      expect(File.size(new_files[0])).to eql image_file1.size
      expect(File.size(new_files[1])).to eql image_file2.size
    end

    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.module_output[:temp_files].length).to eql 3
    end
  end

  describe "#unpack_files" do
    let( :files ) { [image_file1.path, zip_file.path] }
    let( :new_files ) { new_files = mod.unpack_files(files) }
    it "adds unpacked files to file list" do
      expect(new_files.length).to eql 3
      expect(new_files[0]).to end_with 'test1.jpg'
      expect(new_files[1]).to end_with 'test1.jpg'
      expect(new_files[2]).to end_with 'test2.jpg'
    end
    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.module_output[:temp_files].length).to eql 3
    end
  end

  describe "#run_module" do
    let(:file_copies) { ['/tmp/aaa/test1.jpg','/tmp/aaa/test1.jpg'] }
    it "calls essential functions" do
      expect(mod).to receive(:make_copies_of_files).with(sent_files).and_return(file_copies)
      expect(mod).to receive(:unpack_files).with(file_copies).and_return(file_copies)
      mod.run_module
      expect(mod.module_output[:source_files]).to eql file_copies
    end
  end

end

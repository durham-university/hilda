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
      mod.param_values[:received_files] = sent_files
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :sent_files ) { [image_file1, image_file2] }

  after { mod.remove_temp_files if mod.module_output.try(:[],:temp_files).try(:any?) }

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
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test.zip'][:original_filename]).to eql 'test.zip'
      expect(new_files['test.zip'][:path]).to end_with 'test.zip'
      expect(File.size(new_files['test1.jpg'][:path])).to eql files[0].size
      expect(File.size(new_files['test.zip'][:path])).to eql files[1].size
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
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test2.jpg'][:original_filename]).to eql 'test2.jpg'
      expect(new_files['test2.jpg'][:path]).to end_with 'test2.jpg'
      expect(File.size(new_files['test1.jpg'][:path])).to eql image_file1.size
      expect(File.size(new_files['test2.jpg'][:path])).to eql image_file2.size
    end

    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.module_output[:temp_files].length).to eql 3
    end
  end

  describe "#unpack_files" do
    let( :files ) { {
      'test1.jpg' => { path: image_file1.path, original_filename: 'test1.jpg' },
      'test.zip' => { path: zip_file.path, original_filename: 'test.zip' },
    } }
    let( :new_files ) { new_files = mod.unpack_files(files) }
    it "adds unpacked files to file list" do
      expect(new_files.length).to eql 3
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test1.jpg_2'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg_2'][:path]).to end_with 'test1.jpg'
      expect(new_files['test2.jpg'][:original_filename]).to eql 'test2.jpg'
      expect(new_files['test2.jpg'][:path]).to end_with 'test2.jpg'
    end
    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.module_output[:temp_files].length).to eql 3
    end
  end

  describe "#run_module" do
    let(:file_copies) { {
      'test1.jpg': { path: '/tmp/aaa/test1.jpg', original_filename: 'test1.jpg'},
      'test2.jpg': { path: '/tmp/aaa/test2.jpg', original_filename: 'test2.jpg'},
    } }
    it "calls essential functions" do
      expect(mod).to receive(:make_copies_of_files).with(sent_files).and_return(file_copies)
      expect(mod).to receive(:unpack_files).with(file_copies).and_return(file_copies)
      mod.run_module
      expect(mod.module_output[:source_files]).to eql file_copies
    end
    it "doesn't copy files when asked not to" do
      mod.param_values[:received_files] = file_copies
      mod.param_values[:copy_files] = false
      expect(mod).not_to receive(:make_copies_of_files)
      mod.run_module
    end
  end

  describe "#receive_params" do
    let(:params){ {file: image_file1_uploaded} }
    it "makes copies of received files" do
      expect(mod).to receive(:make_copies_of_files).with([params[:file]],Array)
      mod.receive_params(params)
    end
    it "sets param values" do
      mod.receive_params(params)
      expect(mod.param_values[:received_files]).to be_a Hash
      expect(mod.param_values[:received_files].size).to eql 1
      expect(mod.param_values[:copy_files]).to eql false
    end
    it "adds received temporary files to their own index" do
      mod.receive_params(params)
      expect(mod.param_values[:received_temp_files]).to be_a Array
      expect(mod.param_values[:received_temp_files].size).to eql 2
      expect(mod.module_output[:temp_files]).to eql nil
    end
  end

  describe "#cleanup" do
    it "removes received temporary files" do
      expect(mod).to receive(:remove_received_temp_files)
      mod.cleanup
    end
  end

  describe "#reset_module" do
    it "doesn't remove received temporary files" do
      mod.param_values[:received_temp_files] = ['/tmp/aaa']
      expect(mod).to receive(:remove_temp_files).with(no_args)
      mod.reset_module
      expect(mod.param_values[:received_temp_files]).not_to be_empty
    end
  end

  describe "#remove_received_temp_files" do
    it "removes received temp files" do
      mod.param_values[:received_temp_files] = ['/tmp/aaa']
      expect(mod).to receive(:remove_temp_files).with(['/tmp/aaa'])
      mod.remove_received_temp_files
      expect(mod.param_values[:received_temp_files]).to be_empty
    end
  end

end

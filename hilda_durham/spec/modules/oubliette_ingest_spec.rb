require 'rails_helper'

RSpec.describe HildaDurham::Modules::OublietteIngest do
  let( :file_service ) { graph.file_service }
  let( :file1_name ) { 'test1.jpg' }
  let( :file1_path ) { file_service.add_file(file1_name,nil,fixture(file1_name)) }
  let( :file2_name ) { 'test2.jpg' }
  let( :file2_path ) { file_service.add_file(file2_name,nil,fixture(file2_name)) }
  let( :file1_md5 ) { '15eb7a5c063f0c4cdda6a7310b536ba4' }
  let( :file2_md5 ) { '628ad656aba353bdf06edd6e5d25785d' }

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod_input ) {
    {
      source_files: {
        file1: { path: file1_path, original_filename: file1_name, md5: file1_md5, content_type: 'image/jpeg'},
        file2: { path: file2_path, original_filename: file2_name, md5: file2_md5, content_type: 'image/jpeg'}
      },
      file_metadata: { file1__title: 'File 1', file2__title: 'File 2'}
    }
  }
  let( :mod ) {
    graph.add_start_module(HildaDurham::Modules::OublietteIngest, mod_params).tap do |mod|
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

  describe "#archival_files" do
    it "returns source files" do
      expect(mod.archival_files).to eql(mod_input[:source_files])
    end
  end

  describe "#file_title" do
    it "returns metadata title" do
      expect(mod.file_title(mod.archival_files[:file1],:file1)).to eql 'File 1'
      expect(mod.file_title(mod.archival_files[:file2],:file2)).to eql 'File 2'
    end

    it "returns key if no metadata title" do
      mod_input[:file_metadata] = {}
      expect(mod.file_title(mod.archival_files[:file1],:file1)).to eql 'file1'
      expect(mod.file_title(mod.archival_files[:file2],:file2)).to eql 'file2'
    end
  end

  describe "#original_filename" do
    it "returns the original_filename" do
      expect(mod.original_filename(mod.archival_files[:file1])).to eql 'test1.jpg'
    end
  end

  describe "#ingestion_log" do
    it "serialises graph log messages" do
      expect(graph).to receive(:combined_log).and_return([
          DurhamRails::Log::LogMessage.new(:info,'test message'),
          DurhamRails::Log::LogMessage.new(:info,'another message'),
        ])
      log = mod.ingestion_log
      expect(log).to be_a String
      expect(log).to include 'INFO'
      expect(log).to include 'test message'
      expect(log).to include 'another message'
    end
  end

  describe "#run_module" do
    it "ingests files to Oubliette" do
      expect(Oubliette::API::PreservedFile).to receive(:ingest).twice do |file,params|
        expect(["md5:#{file1_md5}", "md5:#{file2_md5}"]).to include params[:ingestion_checksum]
        expect(["File 1", "File 2"]).to include params[:title]
        expect(["test1.jpg", "test2.jpg"]).to include params[:original_filename]
        expect(params[:content_type]).to eql 'image/jpeg'
        expect(params[:ingestion_log]).not_to be_empty
        Oubliette::API::PreservedFile.from_json({'title'=>params[:title], 'ingestion_checksum'=>params[:ingestion_checksum], 'id'=>"id_#{params[:ingestion_checksum]}"})
      end
      # referencing mod_output runs module
      expect(mod_output[:source_files]).not_to be_empty
      expect(mod_output[:stored_files][:file1]).to be_a Oubliette::API::PreservedFile
      expect(mod_output[:stored_files][:file2]).to be_a Oubliette::API::PreservedFile
    end
  end
end

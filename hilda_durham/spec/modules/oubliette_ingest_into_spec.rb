require 'rails_helper'

RSpec.describe HildaDurham::Modules::OublietteIngestInto do
  let( :file_service ) { graph.file_service }
  let( :file1_name ) { 'test1.jpg' }
  let( :file1_path ) { file_service.add_file(file1_name,nil,fixture(file1_name)) }
  let( :file2_name ) { 'test2.jpg' }
  let( :file2_path ) { file_service.add_file(file2_name,nil,fixture(file2_name)) }
  let( :file1_md5 ) { '15eb7a5c063f0c4cdda6a7310b536ba4' }
  let( :file2_md5 ) { '628ad656aba353bdf06edd6e5d25785d' }

  let( :file_batch_id) { 'testfilebatchid' }
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod_input ) {
    {
      source_files: {
        file1: { path: file1_path, original_filename: file1_name, md5: file1_md5, content_type: 'image/jpeg'},
        file2: { path: file2_path, original_filename: file2_name, md5: file2_md5, content_type: 'image/jpeg'}
      },
      file_metadata: { file1__title: 'File 1', file2__title: 'File 2'},
      process_metadata: { oubliette_file_batch_id: file_batch_id }
    }
  }
  let( :mod ) {
    graph.add_start_module(HildaDurham::Modules::OublietteIngestInto, mod_params).tap do |mod|
      mod.assign_job_tag
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

  describe "#run_module" do
    let(:parent_double){double('parent',as_json:{dummy:'json'})}

    it "ingests files to Oubliette" do
      expect(mod).to receive(:create_parent).and_return(parent_double)
      expect(Oubliette::API::PreservedFile).to receive(:ingest).twice do |file,params|
        expect(["md5:#{file1_md5}", "md5:#{file2_md5}"]).to include params[:ingestion_checksum]
        expect(["File 1", "File 2"]).to include params[:title]
        expect(["test1.jpg", "test2.jpg"]).to include params[:original_filename]
        expect(params[:parent]).to eql(parent_double)
        expect(params[:content_type]).to eql 'image/jpeg'
        expect(params[:ingestion_log]).not_to be_empty
        Oubliette::API::PreservedFile.from_json({'title'=>params[:title], 'ingestion_checksum'=>params[:ingestion_checksum], 'id'=>"id_#{params[:ingestion_checksum]}"})
      end      
      # referencing mod_output runs module
      expect(mod_output[:source_files]).not_to be_empty
      expect(mod_output[:stored_files][:file1]).to be_a Hash
      expect(mod_output[:stored_files][:file2]).to be_a Hash
      # stored_file_batch should not be included, otherwise it will be deleted in rollback
      expect(mod_output[:stored_file_batch]).not_to be_present
    end
  end
  
  describe "#create_parent" do
    let(:batch_double){double('batch', id: '123456')}
    it "creates the parent" do
      expect(Oubliette::API::FileBatch).to receive(:find).with(file_batch_id).and_return(batch_double)
      expect(mod.create_parent).to eql(batch_double)
    end
  end
  
  describe "#rollback" do
    before {
      mod.run_status = :finished
      mod.log!(:info,"Dummy message")
    }
    context "when files have been ingested" do
      before {
        mod.module_output = { 
          stored_files: { 
            'file1' => {"id" => "b1aa11bb22x","ingestion_date" => "2015-11-23T13:10:44.494+00:00","status" => "not checked","check_date" => "2015-11-23T13:11:00.000+00:00","title" => "Test file 1","note" => "","ingestion_checksum" => "md5:dcca695ddf72313d5f9f80935c58cf9ddcca695ddf72313d5f9f80935c58cf9d"}, 
            'file2' => {"id" => "b1cc33dd44y","ingestion_date" => "2015-11-23T13:10:44.494+00:00","status" => "not checked","check_date" => "2015-11-23T13:11:00.000+00:00","title" => "Test file 1","note" => "","ingestion_checksum" => "md5:dcca695ddf72313d5f9f80935c58cf9ddcca695ddf72313d5f9f80935c58cf9d"}
          },
          stored_file_batch: {"id" => "b1bb55cc66z", "title" => "batch", "type" => "batch"}
        }
      }
      it "destroys ingested files, file batch and calls super" do
        deleted = []
        allow_any_instance_of(Oubliette::API::PreservedFile).to receive(:destroy) do |file|
          deleted << file.id
          true
        end
        expect_any_instance_of(Oubliette::API::FileBatch).to receive(:destroy) do |batch|
          expect(batch.id).to eql("b1bb55cc66z")
        end
        mod.rollback
        expect(deleted).to match_array(['b1aa11bb22x','b1cc33dd44y'])
        expect(mod.run_status).to eql(:initialized)
        expect(mod.log).to be_empty
      end
    end
    context "when nothing was ingested" do
      it "only calls super" do
        deleted = []
        expect_any_instance_of(Oubliette::API::PreservedFile).not_to receive(:destroy)
        mod.rollback
        expect(mod.run_status).to eql(:initialized)
        expect(mod.log).to be_empty
      end
    end
  end
end

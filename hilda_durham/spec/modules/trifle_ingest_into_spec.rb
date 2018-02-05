require 'rails_helper'

RSpec.describe HildaDurham::Modules::TrifleIngestInto do
  
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :trifle_manifest_id ) { 'testmanfiestid' }
  let( :mod_params ) { {} }
  let( :mod_input ) {
    {
      stored_files: {
        file1: { "id" => "file_id_1", "title" => "1", "status" => "not checked", "note" => nil, "ingestion_checksum" => "md5:de02212abc61637c961df6240715cb64"},
        file2: { "id" => "file_id_2", "title" => "2", "status" => "not checked", "note" => nil, "ingestion_checksum" => "md5:de02212abc61637c961df6240715cb64"},
      },
      process_metadata: {
        trifle_manifest_id: trifle_manifest_id
      },
      file_metadata: {
        file1__title: "1",
        file1__image_description: "test image description",
        file1__image_record: "schmit:ark:/12345/othertestid#abcdef",
        file2__title: "2"
      }
    }
  }
  let( :mod ) {
    graph.add_start_module(HildaDurham::Modules::TrifleIngestInto, mod_params).tap do |mod|
      mod.assign_job_tag
      allow(mod).to receive(:module_input).and_return(mod_input)
    end
  }  
  let( :expected_deposit_items ) { [
    {'source_path' => 'oubliette:file_id_1', 'title' => '1', 'temp_file' => nil, 'description' => 'test image description', 'source_record' => 'schmit:ark:/12345/othertestid#abcdef', 'identifier' => nil},
    {'source_path' => 'oubliette:file_id_2', 'title' => '2', 'temp_file' => nil, 'description' => nil, 'source_record' => nil, 'identifier' => nil}
  ] }
  let( :deposit_response ) { { status: 'ok', message: nil, resource: double('man_res', id: trifle_manifest_id, as_json: { "id" => trifle_manifest_id, "title" => "manifest title", "image_container_location" => "image_container", "identifier" => ['ark:/12345/dummydummy']} ) } }
  let( :mod_output ) {
    mod.log! :info, 'Starting module'
    mod.log! :info, 'Dummy message'
    mod.run_status = :running
    mod.module_output = {}
    mod.run_module
    mod.module_output
  }
  
  describe "#run_module" do
    it "deposits and responds" do
      expect(Trifle::API::IIIFManifest).to receive(:deposit_into).with(trifle_manifest_id, expected_deposit_items).and_return(deposit_response)
      expect(mod_output[:trifle_manifest]['id']).to eql(trifle_manifest_id)
    end
    
    it "retries on deposit failures" do
      counter = 0
      expect(Trifle::API::IIIFManifest).to receive(:deposit_into).with(trifle_manifest_id, expected_deposit_items).twice do 
        counter += 1
        raise 'Test error' if counter == 1
        deposit_response
      end
      expect(mod_output[:trifle_manifest]['id']).to eql(trifle_manifest_id)
    end
  end
  
  describe "#rollback" do
    before {
      mod.run_status = :finished
      mod.log!(:info,"Dummy message")
    }
    context "when files have been ingested" do
      before {
        mod.module_output = { trifle_manifest:  
          {"id" => "tajd472w44j","title" => "Test title 1","image_container_location" => "testimages","identifier" => ["ark:/12345/tajd472w44j"]}
        }
      }
      it "does not destroy ingested files" do
        expect_any_instance_of(Trifle::API::IIIFManifest).not_to receive(:destroy)
        mod.rollback
      end
    end
  end  
  
end

require 'rails_helper'

RSpec.describe HildaDurham::Modules::TrifleIngest do
  
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod_input ) {
    {
      stored_files: {
        file1: { "id" => "file_id_1", "title" => "1", "status" => "not checked", "note" => nil, "ingestion_checksum" => "md5:de02212abc61637c961df6240715cb64"},
        file2: { "id" => "file_id_2", "title" => "2", "status" => "not checked", "note" => nil, "ingestion_checksum" => "md5:de02212abc61637c961df6240715cb64"},
      },
      process_metadata: {
        title: 'test title',
        date: 'test date',
        description: 'test description',
        author: 'test author',
        attribution: 'test attribution'
      }
    }
  }
  let( :mod ) {
    graph.add_start_module(HildaDurham::Modules::TrifleIngest, mod_params).tap do |mod|
      allow(mod).to receive(:module_input).and_return(mod_input)
    end
  }  
  let( :expected_deposit_items ) { [
    {source_path: 'http://localhost:3000/oubliette/preserved_files/file_id_1/download', 'title' => '1'},
    {source_path: 'http://localhost:3000/oubliette/preserved_files/file_id_2/download', 'title' => '2'}
  ] }
  let( :expected_manifest_metadata ){ {
    'title' => 'test title',
    'date_published' => 'test date',
    'description' => 'test description',
    'author' => ['test author'],
    'attribution' => 'test attribution',
    'licence' => nil
  } }
  let( :deposit_response ) { { status: 'ok', message: nil, resource: double('man_res', id: 'man_id_1', as_json: { "id" => "man_id_1", "title" => "manifest title", "image_container_location" => "image_container", "identifier" => ['ark:/12345/dummydummy']} ) } }
  let( :mod_output ) {
    mod.log! :info, 'Starting module'
    mod.log! :info, 'Dummy message'
    mod.run_status = :running
    mod.module_output = {}
    expect(Trifle::API::IIIFManifest).to receive(:deposit_new).with(expected_deposit_items, expected_manifest_metadata).and_return(deposit_response)
    mod.run_module
    mod.module_output
  }
  
  describe "#run_module" do
    it "deposits and responds" do
      expect(mod_output[:trifle_manifest]['id']).to eql('man_id_1')
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
      it "destroys ingested files and calls super" do
        expect_any_instance_of(Trifle::API::IIIFManifest).to receive(:destroy) do |manifest|
          expect(manifest.id).to eql('tajd472w44j')
          true
        end
        mod.rollback
        expect(mod.run_status).to eql(:initialized)
        expect(mod.log).to be_empty
      end
    end
    context "when nothing was ingested" do
      it "only calls super" do
        deleted = []
        expect_any_instance_of(Trifle::API::IIIFManifest).not_to receive(:destroy)
        mod.rollback
        expect(mod.run_status).to eql(:initialized)
        expect(mod.log).to be_empty
      end
    end
  end  
  
end

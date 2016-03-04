require 'rails_helper'

RSpec.describe "hilda_durham/modules/_trifle_collection_linker_form.html.erb", type: :view do

  let( :graph ) { Hilda::IngestionProcess.create }
  let( :mod_params ) { {
      trifle_root_collection: root_collection.id
    } }
  let( :mod ) { graph.add_start_module(HildaDurham::Modules::TrifleCollectionLinker, mod_params) }

  let(:root_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection', 'id' => 'test_col_id', 'sub_collections' => [sub_collection.as_json,sub_collection2.as_json]}) }
  let(:sub_collection) { Schmit::API::Fonds.from_json({'title' => 'test sub collection', 'id' => 'test_subocl_id', 'parent_id' => 'test_col_id'}) }
  let(:sub_collection2) { Schmit::API::Fonds.from_json({'title' => 'test sub collection2', 'id' => 'test_subocl_id2', 'parent_id' => 'test_col_id'}) }

  before {
    allow(Trifle::API::IIIFCollection).to receive(:all).and_return([root_collection])
    allow(Trifle::API::IIIFCollection).to receive(:find).with(root_collection.id).and_return(root_collection)
    allow(Trifle::API::IIIFCollection).to receive(:find).with(sub_collection.id).and_return(sub_collection)
    allow(Trifle::API::IIIFCollection).to receive(:find).with(sub_collection2.id).and_return(sub_collection2)
    allow(Trifle::API::IIIFCollection).to receive(:all_in_collection).with(root_collection).and_return([sub_collection,sub_collection2])
  }

  before {
    assign(:ingestion_process,graph)
    render "hilda_durham/modules/trifle_collection_linker_form", mod: mod
  }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  it "renders the template" do
    expect(page).to have_selector("select[name='ingestion_process[trifle_root_collection]']>option[selected='selected']", root_collection.title )
    expect(page).to have_selector("select[name='ingestion_process[trifle_sub_collection]']>option", sub_collection.title )
    expect(page).to have_selector("select[name='ingestion_process[trifle_sub_collection]']>option", sub_collection2.title )
  end

end

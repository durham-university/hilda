require 'rails_helper'

RSpec.describe "hilda_durham/modules/_schmit_linker_form.html.erb", type: :view do

  let( :graph ) { Hilda::IngestionProcess.create }
  let( :mod_params ) { {
      schmit_repository: repository.id
    } }
  let( :mod ) { graph.add_start_module(HildaDurham::Modules::SchmitLinker, mod_params) }

  let(:repository) { Schmit::API::Repository.from_json({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id', fonds: [fonds.as_json,fonds2.as_json]}.with_indifferent_access) }
  let(:fonds) { Schmit::API::Fonds.from_json({title: 'test fonds', public_id: 'test_fon', id: 'test_fon_id', parent_id: 'test_repo_id', catalogues: [catalogue.as_json]}.with_indifferent_access) }
  let(:fonds2) { Schmit::API::Fonds.from_json({title: 'test fonds 2', public_id: 'test_fon2', id: 'test_fon2_id', parent_id: 'test_repo_id', catalogues: [catalogue2.as_json]}.with_indifferent_access) }
  let(:catalogue) { Schmit::API::Catalogue.from_json({title: 'test catalogue', public_id: 'test_cat', id: 'test_cat_id', parent_id: 'test_fon_id'}.with_indifferent_access) }
  let(:catalogue2) { Schmit::API::Catalogue.from_json({title: 'test catalogue 2', public_id: 'test_cat2', id: 'test_cat2_id', parent_id: 'test_fon2_id'}.with_indifferent_access) }

  before {
    allow(Schmit::API::Repository).to receive(:all).and_return([repository])
    allow(Schmit::API::Repository).to receive(:find).with(repository.id).and_return(repository)
    allow(Schmit::API::Fonds).to receive(:all_in).with(repository).and_return([fonds,fonds2])
    allow(Schmit::API::Fonds).to receive(:find).with(fonds.id).and_return(fonds)
    allow(Schmit::API::Catalogue).to receive(:all_in).with(repository).and_return([catalogue,catalogue2])
    allow(Schmit::API::Catalogue).to receive(:find).with(catalogue.id).and_return(catalogue)
  }

  before {
    assign(:ingestion_process,graph)
    render "hilda_durham/modules/schmit_linker_form", mod: mod
  }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  it "renders the template" do
    expect(page).to have_selector("select[name='ingestion_process[schmit_repository]']>option[selected='selected']", repository.title )
    expect(page).to have_selector("select[name='ingestion_process[schmit_fonds]']>option", fonds.title )
    expect(page).to have_selector("select[name='ingestion_process[schmit_fonds]']>option", fonds2.title )
    expect(page).to have_selector("select[name='ingestion_process[schmit_catalogue]']>option", catalogue.title )
    expect(page).to have_selector("select[name='ingestion_process[schmit_catalogue]']>option", catalogue2.title )
  end

end

require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/edit", type: :view do
  let( :ingestion_process ) { FactoryGirl.create(:ingestion_process,:params) }
  let( :mod_a ) { ingestion_process.find_module('mod_a') }
  let( :mod_b ) { ingestion_process.find_module('mod_b') }
  let( :module_notices ) { {} }
  before {
    assign(:ingestion_process, ingestion_process)
    assign(:module_notices, module_notices)
  }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  it "renders the edit form with all modules" do
    render
    ingestion_process.graph.keys.each do |mod|
      expect(page).to have_selector("form[action='#{ingestion_process_module_path(ingestion_process.id,mod.module_name)}']")
    end
  end

  describe "module notices" do
    let(:module_notices) { { mod_a => [{message: 'test notice', level: :warn}] } }
    it "renders notices" do
      render
      expect(page).to have_selector('div.alert-warn')
      expect(rendered).to include 'test notice'
    end
  end
end

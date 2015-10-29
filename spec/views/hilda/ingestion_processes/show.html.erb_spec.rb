require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/show", type: :view do
  
  let( :ingestion_process ) { FactoryGirl.create(:ingestion_process,:params) }
  let( :mod_a ) { ingestion_process.find_module('mod_a') }
  let( :mod_b ) { ingestion_process.find_module('mod_b') }
  before {
    assign(:ingestion_process, ingestion_process)
  }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  it "renders the page" do
    render
  end
end

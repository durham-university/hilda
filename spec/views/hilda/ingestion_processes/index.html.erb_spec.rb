require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/index", type: :view do
  before(:each) do
    assign(:ingestion_processes, [
      FactoryGirl.create(:ingestion_process,:params),
      FactoryGirl.create(:ingestion_process,:execution)
    ])
  end

  it "renders a list of hilda/ingestion_processes" do
    render
  end
end

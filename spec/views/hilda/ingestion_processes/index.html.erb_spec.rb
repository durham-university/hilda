require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/index", type: :view do
  before(:each) do
    assign(:hilda_ingestion_processes, [
      Hilda::IngestionProcess.create!(),
      Hilda::IngestionProcess.create!()
    ])
  end

  it "renders a list of hilda/ingestion_processes" do
    render
  end
end

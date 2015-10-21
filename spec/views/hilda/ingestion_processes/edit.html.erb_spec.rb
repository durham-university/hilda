require 'rails_helper'

RSpec.xdescribe "hilda/ingestion_processes/edit", type: :view do
  before(:each) do
    @hilda_ingestion_process = assign(:hilda_ingestion_process, Hilda::IngestionProcess.create!())
  end

  it "renders the edit hilda_ingestion_process form" do
    render

    assert_select "form[action=?][method=?]", hilda_ingestion_process_path(@hilda_ingestion_process), "post" do
    end
  end
end

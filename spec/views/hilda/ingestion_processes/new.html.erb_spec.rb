require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/new", type: :view do
  before(:each) do
    assign(:hilda_ingestion_process, Hilda::IngestionProcess.new())
  end

  it "renders new hilda_ingestion_process form" do
    render

    assert_select "form[action=?][method=?]", hilda_ingestion_processes_path, "post" do
    end
  end
end

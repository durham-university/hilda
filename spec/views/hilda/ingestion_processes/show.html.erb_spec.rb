require 'rails_helper'

RSpec.xdescribe "hilda/ingestion_processes/show", type: :view do
  before(:each) do
    @hilda_ingestion_process = assign(:hilda_ingestion_process, Hilda::IngestionProcess.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end

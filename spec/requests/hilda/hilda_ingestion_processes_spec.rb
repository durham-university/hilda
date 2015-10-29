require 'rails_helper'

RSpec.describe "Hilda::IngestionProcesses", type: :request do
  describe "GET /hilda_ingestion_processes" do
    it "works! (now write some real specs)" do
      get hilda.ingestion_processes_path
      expect(response).to have_http_status(200)
    end
  end
end

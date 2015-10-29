require "rails_helper"

RSpec.describe Hilda::IngestionProcessesController, type: :routing do
  describe "routing" do
    routes { Hilda::Engine.routes }

    it "routes to #index" do
      expect(:get => "/processes").to route_to("hilda/ingestion_processes#index")
    end

    it "routes to #new" do
      expect(:get => "/processes/new").to route_to("hilda/ingestion_processes#new")
    end

    it "routes to #show" do
      expect(:get => "/processes/1").to route_to("hilda/ingestion_processes#show", :id => "1")
    end

    it "routes to #edit" do
      expect(:get => "/processes/1/edit").to route_to("hilda/ingestion_processes#edit", :id => "1")
    end

    it "routes to #create" do
      expect(:post => "/processes").to route_to("hilda/ingestion_processes#create")
    end

    it "routes to #update via PUT" do
      expect(:put => "/processes/1").to route_to("hilda/ingestion_processes#update", :id => "1")
    end

    it "routes to #update via PATCH" do
      expect(:patch => "/processes/1").to route_to("hilda/ingestion_processes#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(:delete => "/processes/1").to route_to("hilda/ingestion_processes#destroy", :id => "1")
    end

  end
end

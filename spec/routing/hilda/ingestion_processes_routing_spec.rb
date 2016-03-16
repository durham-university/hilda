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
    
    it "routes to #rollback_module" do
      expect(:post => "/processes/1/module/foo/rollback").to route_to("hilda/ingestion_processes#rollback_module", id: '1', module: 'foo')
    end
    it "routes to #reset_module" do
      expect(:post => "/processes/1/module/foo/reset").to route_to("hilda/ingestion_processes#reset_module", id: '1', module: 'foo')
    end
    it "routes to #start_moudle" do
      expect(:post => "/processes/1/module/foo/start").to route_to("hilda/ingestion_processes#start_module", id: '1', module: 'foo')
    end
    it "routes to #query_module" do
      expect(:post => "/processes/1/module/foo/query").to route_to("hilda/ingestion_processes#query_module", id: '1', module: 'foo')
    end

    it "routes to #enable_module" do
      expect(:post => "/processes/1/module/foo/enable").to route_to("hilda/ingestion_processes#enable_module", id: '1', module: 'foo')
    end
    it "routes to #disable_module" do
      expect(:post => "/processes/1/module/foo/disable").to route_to("hilda/ingestion_processes#disable_module", id: '1', module: 'foo')
    end
    
    it "routes to #reset_graph" do
      expect(:post => "/processes/1/reset").to route_to("hilda/ingestion_processes#reset_graph", id: '1')
    end
    it "routes to #start_graph" do
      expect(:post => "/processes/1/start").to route_to("hilda/ingestion_processes#start_graph", id: '1')
    end
    it "routes to #rollback_graph" do
      expect(:post => "/processes/1/rollback").to route_to("hilda/ingestion_processes#rollback_graph", id: '1')
    end

  end
end

require 'rails_helper'

RSpec.describe Hilda::IngestionProcessesController, type: :controller do
  routes { Hilda::Engine.routes }

  let( :ingestion_process ) { FactoryGirl.create(:ingestion_process,:params) }
  let( :mod ) {
    ingestion_process.find_module('mod_a').tap do |mod|
      expect(mod).to be_a Hilda::ModuleBase
    end
  }
  let( :other_mod ) {
    ingestion_process.find_module('mod_b').tap do |mod|
      expect(mod).to be_a Hilda::ModuleBase
    end
  }
  let( :mod_loaded ) { Hilda::IngestionProcess.find(ingestion_process.id).find_module(mod.module_name) }
  let( :other_mod_loaded ) { Hilda::IngestionProcess.find(ingestion_process.id).find_module(other_mod.module_name) }

  describe "GET #index" do
    it "assigns all ingestion_processes as @ingestion_processes" do
      ingestion_process # create by reference
      get :index, {}
      expect(assigns(:ingestion_processes)).to eq([ingestion_process])
    end
  end

  describe "GET #show" do
    it "assigns the requested ingestion_process as @ingestion_process" do
      get :show, {id: ingestion_process.to_param}
      expect(assigns(:ingestion_process)).to eq(ingestion_process)
    end
  end

  describe "GET #new" do
    before { FactoryGirl.create(:ingestion_process_template) }
    it "assigns a new ingestion_process as @ingestion_process" do
      get :new, {}
      expect(assigns(:ingestion_process)).to be_a_new(Hilda::IngestionProcess)
    end
    it "assigns a list of templates as @templates" do
      get :new, {}
      expect(assigns(:templates)).to be_a Array
      expect(assigns(:templates)).not_to be_empty
      assigns(:templates).each do |template|
        expect(template).to be_a Hilda::IngestionProcessTemplate
      end
    end
  end

  describe "GET #edit" do
    it "assigns the requested ingestion_process as @ingestion_process" do
      get :edit, {id: ingestion_process.to_param}
      expect(assigns(:ingestion_process)).to eq(ingestion_process)
    end
  end

  describe "POST #create" do
    let( :template ) { FactoryGirl.create(:ingestion_process_template,:params) }

    describe "template loading" do
      it "creates a new IngestionProcess when using template_key" do
        expect {
          post :create, {ingestion_process: { template: template.template_key }}
        }.to change(Hilda::IngestionProcess, :count).by(1)
      end
      it "creates a new IngestionProcess when using template id" do
        expect {
          post :create, {ingestion_process: { template: template.id }}
        }.to change(Hilda::IngestionProcess, :count).by(1)
      end
      it "doesn't creat a new IngestionProcess when using an invalid template_key" do
        expect {
          expect {
            post :create, {ingestion_process: { template: 'moo' }}
          }.to raise_error('Template not found')
        }.not_to change(Hilda::IngestionProcess, :count)
      end
      it "doesn't creat a new IngestionProcess when not specifying template" do
        expect {
          expect {
            post :create, {ingestion_process: { }}
          }.to raise_error('Template not found')
        }.not_to change(Hilda::IngestionProcess, :count)
      end
    end

    context "with valid params" do
      it "assigns a newly created ingestion_process as @ingestion_process" do
        post :create, {ingestion_process: { template: template.template_key }}
        expect(assigns(:ingestion_process)).to be_a(Hilda::IngestionProcess)
        expect(assigns(:ingestion_process)).to be_persisted
      end

      it "redirects to the created ingestion_process" do
        post :create, {ingestion_process: { template: template.template_key }}
        expect(response).to redirect_to(edit_ingestion_process_path(Hilda::IngestionProcess.last))
      end

      it "copies the template" do
        post :create, {ingestion_process: { template: template.template_key }}
        mod = assigns(:ingestion_process).find_module('mod_a')
        expect(mod).to be_a Hilda::Modules::DebugModule
        expect(mod.param_defs[:moo]).to eql({ label: 'moo', type: :string, default: nil, group: nil })
        expect(assigns(:ingestion_process).title).to be_present
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      it "updates the requested ingestion_process" do
        put :update, {id: ingestion_process.to_param, ingestion_process: {}}
        ingestion_process.reload
        skip("Add assertions for updated state")
      end

      it "assigns the requested ingestion_process as @ingestion_process" do
        put :update, {id: ingestion_process.to_param, ingestion_process: {}}
        expect(assigns(:ingestion_process)).to eq(ingestion_process)
      end

      it "redirects to the ingestion_process" do
        put :update, {id: ingestion_process.to_param, ingestion_process: {}}
        expect(response).to redirect_to(edit_ingestion_process_path(ingestion_process))
      end
    end

    context "to module" do
      before {
        mod.param_defs = mod.class.sanitise_field_defs({
          moo: {label: 'moo', type: :string},
          baa: {label: 'baa', type: :string}
        })
        ingestion_process.save
      }
      it "sets param values" do
        put :update, {id: ingestion_process.to_param, module: mod.module_name, ingestion_process: {
          moo: 'new moo',
          baa: 'new baa'
        } }
        expect(mod_loaded.param_values[:moo]).to eql 'new moo'
        expect(mod_loaded.param_values[:baa]).to eql 'new baa'
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ingestion_process" do
      ingestion_process # create by reference
      expect {
        delete :destroy, {id: ingestion_process.to_param}
      }.to change(Hilda::IngestionProcess, :count).by(-1)
    end

    it "redirects to the ingestion_processes list" do
      delete :destroy, {id: ingestion_process.to_param}
      expect(response).to redirect_to(ingestion_processes_url)
    end
  end

  describe "POST #start_module" do
    it "pushes a run job" do
      expect(Hilda.queue).to receive(:push) do |job|
        expect(job.resource_id).to eql ingestion_process.id
        expect(job.module_name).to eql mod.module_name
        job.resource.save # Save would normally be done in push and is needed for the test to pass
      end
      post :start_module, {id: ingestion_process.to_param, module: mod.module_name }
      expect(mod_loaded.run_status).to eql :queued
    end
  end

  describe "POST #reset_module" do
    it "resets the module and cascades" do
      mod.run_status = :finished
      other_mod.run_status = :finished
      ingestion_process.save
      post :reset_module, {id: ingestion_process.to_param, module: mod.module_name }
      expect(mod_loaded.run_status).to eql :initialized
      expect(other_mod_loaded.run_status).to eql :initialized
    end
    it "doesn't reset modules unnecessarily" do
      mod.run_status = :finished
      other_mod.run_status = :finished
      ingestion_process.save
      post :reset_module, {id: ingestion_process.to_param, module: other_mod.module_name }
      expect(mod_loaded.run_status).to eql :finished
      expect(other_mod_loaded.run_status).to eql :initialized
    end
  end

  describe "#use_layout?" do
    before { controller.instance_variable_set(:@_params,params) }
    context "with no params at all" do
      let(:params){ {} }
      it "returns true" do expect(controller.use_layout?).to eql true end
    end
    context "with no_layout at top level" do
      let(:params){ { no_layout: ''} }
      it "returns false" do expect(controller.use_layout?).to eql false end
    end
    context "with no_layout under ingestion_process" do
      let(:params){ { ingestion_process: { no_layout: ''} } }
      it "returns false" do expect(controller.use_layout?).to eql false end
    end
  end
end

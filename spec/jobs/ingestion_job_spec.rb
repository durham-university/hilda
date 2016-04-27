require 'rails_helper'

RSpec.describe Hilda::Jobs::IngestionJob do
  let( :mod_a ) { graph_only.add_start_module(Hilda::Modules::DebugModule, module_name: 'mod_a') }
  let( :mod_b ) { graph_only.add_module(Hilda::Modules::DebugModule, mod_a, module_name: 'mod_b') }
  let( :mod_c ) { graph_only.add_module(Hilda::Modules::DebugModule, mod_b, module_name: 'mod_c') }
  let( :all_modules ) { [mod_a, mod_b, mod_c] }
  let( :graph_only ) { Hilda::IngestionProcess.new }
  let( :graph ) { all_modules ; graph_only }
  let( :job_params ) { {} }
  let( :user ) { FactoryGirl.create(:user,:admin) }

  let( :job ) { Hilda::Jobs::IngestionJob.new( {resource: graph, user: user }.merge(job_params)) }

  describe "#initialize" do
    it "initializes" do
      expect(job).to be_a Hilda::Jobs::IngestionJob
    end
  end

  describe "#queue_job" do
    it "can be queued" do
      expect(Hilda.queue).to receive(:push).with(job)
      job.queue_job
    end
  end

  describe "#run_job" do
    context "with module_name set" do
      let(:job_params) { {module_name: 'mod_b'} }
      it "continues execution with the named module" do
        expect(graph).to receive(:continue_execution).with(mod_b)
        expect(graph).not_to receive(:start_graph)
        job.run_job
      end
    end
    context "with run_mode: :continue" do
      let(:job_params) { {run_mode: :continue} }
      it "continues execution with current state" do
        expect(graph).to receive(:continue_execution).with(no_args)
        expect(graph).not_to receive(:start_graph)
        job.run_job
      end
    end
    context "with no options" do
      it "starts graph" do
        expect(graph).to receive(:continue_execution)
        expect(graph).not_to receive(:start_graph)
        job.run_job
      end
    end
  end
end

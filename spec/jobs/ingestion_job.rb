require 'rails_helper'

RSpec.describe Hilda::Jobs::IngestionJob do
  let( :mod_a ) { graph_only.add_start_module(Hilda::Modules::DebugModule, module_name: 'mod_a') }
  let( :mod_b ) { graph_only.add_module(Hilda::Modules::DebugModule, mod_a, module_name: 'mod_b') }
  let( :mod_c ) { graph_only.add_module(Hilda::Modules::DebugModule, mod_b, module_name: 'mod_c') }
  let( :all_modules ) { [mod_a, mod_b, mod_c] }
  let( :graph_only ) { Hilda::IngestionProcess.new }
  let( :graph ) { all_modules ; graph_only }

  let( :job ) { Hilda::Jobs::IngestionJob.new(resource: graph) }

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
end

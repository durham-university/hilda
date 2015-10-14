require 'rails_helper'

RSpec.describe Hilda::IngestionProcess do

  before {
    class TestModule
      include Hilda::ModuleBase
      def run_module
        module_output = param_values.fetch(:output,{ test_out: 'test' })
      end
      def autorun?
        param_values.fetch(:autorun,true)
      end
    end
  }

  #
  # mod_a -> mod_b -> mod_c
  #       -> mod_d -> mod_e -> mod_f
  # mod_g
  #
  # B and C not autorun
  #

  let( :mod_a ) { graph_only.add_start_module(TestModule,'mod_a') }
  let( :mod_b ) { graph_only.add_module(TestModule,'mod_b',mod_a, autorun: false) }
  let( :mod_c ) { graph_only.add_module(TestModule,'mod_c',mod_b) }
  let( :mod_d ) { graph_only.add_module(TestModule,'mod_d',mod_a) }
  let( :mod_e ) { graph_only.add_module(TestModule,'mod_e',mod_d, autorun: false) }
  let( :mod_f ) { graph_only.add_module(TestModule,'mod_f',mod_e) }
  let( :mod_g ) { graph_only.add_start_module(TestModule,'mod_g') }
  let( :all_modules ) { [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g] }
  let( :graph_only ) { Hilda::IngestionProcess.new }
  let( :graph ) { all_modules ; graph_only }
  let( :process ) { graph }

  describe "persisting graph" do
    before {
      mod_a.run_status = :finished
      mod_a.log! 'Test log message'
      mod_b.run_status = :finished
      process.save
    }
    let( :loaded ) { Hilda::IngestionProcess.find(process.id) }
    it "loads form fedora" do
      expect(loaded).to be_a Hilda::IngestionProcess
      expect(loaded.graph.size).to eql 7
      expect(loaded.run_status).to eql :paused
      expect(loaded.find_module('mod_a').run_status).to eql :finished
      expect(loaded.find_module('mod_a').log.first.message).to eql 'Test log message'
    end
    it "can be updated and reloaded" do
      loaded.log! "Another message"
      loaded.find_module('mod_b').run_status = :error
      loaded.save
      loaded.reload
      expect(loaded.log.last.message).to eql 'Another message'
      expect(loaded.run_status).to eql :error
    end

  end


end

require 'rails_helper'

RSpec.describe 'JobBase' do
  before {
    class FooJob
      include Hilda::Jobs::JobBase
    end
  }
  after {
    Object.send(:remove_const,:FooJob)
  }
  let( :job_already_running ) { false }
  let( :job ) {
    FooJob.new().tap do |job|
    end
  }

  describe "#run" do
    it "calls the necessary methods" do
      expect(job).to receive(:run_job).once
      expect(job).to receive(:job_finished).once
      job.run
    end
  end

  describe "marshalling" do
    let( :dump ) { Marshal.dump(job) }
    let( :loaded ) { Marshal.load( dump ) }
    describe "dumping" do
      it "should dump the object" do
        expect(dump).to be_present
      end
    end

    describe "loading" do
      it "loads the object" do
        expect(loaded).to be_a FooJob
        expect(loaded.id).to eql job.id
      end
    end
  end

end

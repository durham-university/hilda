require 'rails_helper'

RSpec.describe 'WithResource' do
  before {
    class FooJob
      include Hilda::Jobs::JobBase
      include Hilda::Jobs::WithResource
    end
  }
  after {
    Object.send(:remove_const,:FooJob)
  }
  let( :resource ) {
    double('resource').tap do |resource|
      allow(resource).to receive(:id).and_return('foo_id')
      allow(resource).to receive(:background_job_finished).and_return(true)
      allow(resource).to receive(:background_job_running?).and_return(job_already_running)
    end
  }
  let( :job_already_running ) { false }
  let( :job ) {
    FooJob.new(resource: 'foo_id').tap do |job|
      allow(job).to receive(:resource).and_return(resource)
    end
  }
  let( :file ) { StringIO.new('moomoo') }
  let( :file_table ) { job.instance_variable_get(:@file_table) }

  describe "marhsalling" do
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
        expect(loaded.resource_id).to eql 'foo_id'
      end
    end
  end

  describe "#validate_job!" do
    context "with no other background job" do
      it "raises no errors" do
        expect {
          job.validate_job!
        }.not_to raise_error
      end
    end
    context "with a job already running" do
      let( :job_already_running ) { true }
      it "raises an error" do
        expect {
          job.validate_job!
        }.to raise_error("Resource is already processing a background job")
      end
    end
  end

  describe "#queue_job" do
    it "calls the necessary methods" do
      expect(job).to receive(:validate_job!)
      expect(resource).to receive(:start_background_job)
      expect(Hilda.queue).to receive(:push).with(job)
      job.queue_job
    end
  end

  describe "#job_finished" do
    it "calls the necessary methods" do
      expect(resource).to receive(:background_job_finished).and_return(true)
      job.job_finished
    end
    it "raises an error when something goes wrong" do
      expect(resource).to receive(:background_job_finished).and_return(false)
      expect {
        job.job_finished
      }.to raise_error('Unable to mark job finished in Fedora')
    end
  end
end

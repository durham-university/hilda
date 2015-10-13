require 'rails_helper'

RSpec.describe Hilda::Log do
  describe "basic methods" do
    let(:log) { Hilda::Log.new }
    before {
      log.log!('information')
      log.log!(:warn,'warning')
    }
    describe "#log!" do
      it "works" do
        expect(log.size).to eql 2
        log.log!(:warn,'another message')
        expect(log.size).to eql 3
        expect(log.last.message).to eql 'another message'
        expect(log.last.level).to eql :warn
      end
    end
    describe "#empty?" do
      it "works" do expect(log.empty?).to eql false end
    end
    describe "#any?" do
      it "works" do expect(log.any?).to eql true end
    end
    describe "#errors?" do
      it "works" do expect(log.errors?).to eql false end
      context "with errors" do
        before { log.log!(:error,'error message') }
        it "works" do expect(log.errors?).to eql true end
      end
    end
    describe "each" do
      it "iterates over messages" do
        a = []
        log.each do |m| a << m end
        expect(a[0].message).to eql 'information'
        expect(a[1].message).to eql 'warning'
      end
    end
    describe "count" do
      it "works" do expect(log.count).to eql 2 end
    end
    describe "size" do
      it "works" do expect(log.size).to eql 2 end
    end
    describe "length" do
      it "works" do expect(log.length).to eql 2 end
    end
    describe "first" do
      it "works" do expect(log.first.message).to eql 'information' end
    end
    describe "last" do
      it "works" do expect(log.last.message).to eql 'warning' end
    end
  end


  describe Hilda::Log::LogMessage do
    describe "#initialize" do
      it "initializes with a message only" do
        msg = Hilda::Log::LogMessage.new('message')
        expect(msg.message).to eql 'message'
        expect(msg.level).to eql :info
        expect(msg.exception).to be_nil
      end
      it "initializes with a level and a message" do
        msg = Hilda::Log::LogMessage.new(:warn, 'message')
        expect(msg.message).to eql 'message'
        expect(msg.level).to eql :warn
        expect(msg.exception).to be_nil
      end
      it "initializes with an exception only" do
        ex = RuntimeError.new('exception message')
        msg = Hilda::Log::LogMessage.new(ex)
        expect(msg.message).to eql 'exception message'
        expect(msg.level).to eql :error
        expect(msg.exception).to eql ex
      end
      it "initializes with exception and messag" do
        ex = RuntimeError.new('exception message')
        msg = Hilda::Log::LogMessage.new('log message',ex)
        expect(msg.message).to eql 'log message'
        expect(msg.level).to eql :error
        expect(msg.exception).to eql ex
      end
      it "initializes with all" do
        ex = RuntimeError.new('exception message')
        msg = Hilda::Log::LogMessage.new(:warn,'message',ex)
        expect(msg.message).to eql 'message'
        expect(msg.level).to eql :warn
        expect(msg.exception).to eql ex
      end
    end
  end

  describe "serialisation" do
    let(:log) { Hilda::Log.new }
    before {
      log.log!('information')
      log.log!(:warn,'warning')
      begin ; raise 'Test error' ; rescue => e ; log.log! e ; end
    }
    let( :log2 ) { Hilda::Log.from_json(log.to_json) }
    it "serialises and deserialises" do
      expect(log2.size).to eql log.size
      expect(log2.first).to be_a Hilda::Log::LogMessage
      expect(log2.first.message).to eql log.first.message
      expect(log2.last.message).to eql log.last.message
      expect(log2.last.exception).to be_present
      expect(log2.last.exception.backtrace.length).to be > 2
    end
  end
end

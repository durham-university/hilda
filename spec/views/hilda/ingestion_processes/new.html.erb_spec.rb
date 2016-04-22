require 'rails_helper'

RSpec.describe "hilda/ingestion_processes/new", type: :view do
  let(:templates) { [
      FactoryGirl.build(:ingestion_process_template,:params),
      FactoryGirl.build(:ingestion_process_template,:execution),
    ] }
  before(:each) do
    assign(:ingestion_process, Hilda::IngestionProcess.new())
    assign(:templates, templates)
  end

  let(:page) { Capybara::Node::Simple.new(rendered) }

  it "renders all template options" do
    render

    templates.each do |template|
      expect(rendered).to include template.title
      expect(page).to have_selector("input[name='ingestion_process[template]'][value='#{template.template_key}']", visible: :all)
    end
  end
end

FactoryGirl.define do
  factory :ingestion_process_template, parent: :module_graph, class: Hilda::IngestionProcessTemplate do
    sequence(:title) { |n| "Ingestion process #{n}" }
    sequence(:template_key) { |n| "template_#{n}" }
    sequence(:order_hint) { |n| n }
    sequence(:description) { |n| "Ingestion process template description #{n}" }
  end
end

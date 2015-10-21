FactoryGirl.define do
  factory :ingestion_process, parent: :module_graph, class: Hilda::IngestionProcess do
    sequence(:title) { |n| "Ingestion process #{n}" }    
  end
end

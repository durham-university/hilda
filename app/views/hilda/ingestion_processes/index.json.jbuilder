json.array!(@ingestion_processes) do |ingestion_process|
  json.extract! ingestion_process, :id
  json.url ingestion_process_url(ingestion_process, format: :json)
end

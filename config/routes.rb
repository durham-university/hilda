Hilda::Engine.routes.draw do
  root 'ingestion_processes#index'
  resources :ingestion_processes, path: 'processes'
  patch 'processes/:id/module/:module' => 'ingestion_processes#update', as: 'ingestion_process_module'
  put 'processes/:id/module/:module' => 'ingestion_processes#update'
  post 'processes/:id/module/:module/rollback' => 'ingestion_processes#rollback_module', as: 'ingestion_process_module_rollback'
  post 'processes/:id/module/:module/reset' => 'ingestion_processes#reset_module', as: 'ingestion_process_module_reset'
  post 'processes/:id/module/:module/start' => 'ingestion_processes#start_module', as: 'ingestion_process_module_start'
  post 'processes/:id/module/:module/query' => 'ingestion_processes#query_module', as: 'ingestion_process_module_query'
  post 'processes/:id/reset' => 'ingestion_processes#reset_graph', as: 'ingestion_process_reset'
  post 'processes/:id/start' => 'ingestion_processes#start_graph', as: 'ingestion_process_start'
  post 'processes/:id/rollback' => 'ingestion_processes#rollback_graph', as: 'ingestion_process_rollback'
end

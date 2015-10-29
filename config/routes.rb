Hilda::Engine.routes.draw do
  root 'ingestion_processes#index'
  resources :ingestion_processes, path: 'processes'
  patch 'processes/:id/module/:module' => 'ingestion_processes#update', as: 'ingestion_process_module'
  put 'processes/:id/module/:module' => 'ingestion_processes#update'
  post 'processes/:id/module/:module/reset' => 'ingestion_processes#reset_module', as: 'ingestion_process_module_reset'
  post 'processes/:id/module/:module/start' => 'ingestion_processes#start_module', as: 'ingestion_process_module_start'
end

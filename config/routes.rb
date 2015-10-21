Rails.application.routes.draw do
  root 'hilda/ingestion_processes#index'
  resources :ingestion_processes, module: 'hilda', path: 'processes', as: 'hilda_ingestion_processes'
  resources :ingestion_processes, module: 'hilda', path: 'processes'
  patch 'processes/:id/module/:module' => 'hilda/ingestion_processes#update', as: 'ingestion_process_module'
  put 'processes/:id/module/:module' => 'hilda/ingestion_processes#update'
  post 'processes/:id/module/:module/reset' => 'hilda/ingestion_processes#reset_module', as: 'ingestion_process_module_reset'
  post 'processes/:id/module/:module/start' => 'hilda/ingestion_processes#start_module', as: 'ingestion_process_module_start'

  if defined?(Hilda::ResqueAdmin) && defined?(Resque::Server)
    namespace :admin do
      constraints Hilda::ResqueAdmin do
        mount Resque::Server.new, at: 'queues'
      end
    end
  end

end

Rails.application.routes.draw do
  root 'hilda/ingestion_processes#index'

  devise_for :users

  mount Hilda::Engine => "/hilda"

  if defined?(Hilda::ResqueAdmin) && defined?(Resque::Server)
    namespace :admin do
      constraints Hilda::ResqueAdmin do
        mount Resque::Server.new, at: 'queues'
      end
    end
  end
end

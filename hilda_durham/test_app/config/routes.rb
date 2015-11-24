Rails.application.routes.draw do
  root 'hilda/ingestion_processes#index'

  mount Hilda::Engine => "/hilda"

  mount Schmit::Engine => "/schmit"

  mount Oubliette::Engine => "/oubliette"

  devise_for :users

  if defined?(Hilda::ResqueAdmin) && defined?(Resque::Server)
    namespace :admin do
      constraints Hilda::ResqueAdmin do
        mount Resque::Server.new, at: 'queues'
      end
    end
  end
end

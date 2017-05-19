Rails.application.routes.draw do
  root 'hilda/static_pages#home'

  mount Hilda::Engine => "/hilda"

  unless Rails.env.test?
    mount Schmit::Engine => "/schmit"

    mount Oubliette::Engine => "/oubliette"

    mount Trifle::Engine => "/trifle"
  end

  devise_for :users
  
  resources :users, only: [:index, :show, :edit, :update, :destroy]

  if defined?(Hilda::ResqueAdmin) && defined?(Resque::Server)
    namespace :admin do
      constraints Hilda::ResqueAdmin do
        mount Resque::Server.new, at: 'queues'
      end
    end
  end
end

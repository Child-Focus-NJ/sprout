Rails.application.routes.draw do
  get "welcome/index"
  get "application_dashboard", to: "application_dashboard#index"
  get "admin/settings", to: "admin/settings#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :information_sessions do
    member do
      get :sign_in
      post :check_in
    end
  end
  resources :volunteers do
    collection do
      post :bulk_add_note
    end

    member do
      patch :update_status
      post :send_application
      patch :mark_submitted
      get :sms
      post :send_sms
      post :add_note
    end
  end
  resources :inquiry_form
  resources :reporting_exporting
  resources :system_management

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  get "/login", to: "sessions#new", as: :login

  # Defines the root path route ("/")
  root "welcome#index"
end

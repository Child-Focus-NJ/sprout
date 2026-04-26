Rails.application.routes.draw do
  get "system_management/index"
  get "welcome/index"
  get "application_dashboard", to: "application_dashboard#index", as: :application_dashboard
  get "admin/settings", to: "admin/settings#index", as: :admin_settings
  patch "admin/settings", to: "admin/settings#update"
  get "application_dashboard", to: "application_dashboard#index"
  get "admin/settings", to: "admin/settings#index"

  namespace :admin do
    resources :communication_templates do
      member do
        get :preview
        post :preview
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :information_sessions do
    member do
      get :sign_in
      post :check_in
      delete "remove_attendee/:volunteer_id", to: "information_sessions#remove_attendee", as: "remove_attendee"
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
  resource :inquiry_form, controller: "inquiry_form"
  resources :reporting_exporting do
    collection do
      post :export_report
      post :export_data
    end
  end

  resource :system_management, only: [ :show ], controller: "system_management" do
    collection do
      post :import
    end
  end
  resources :reminder_frequencies, only: [ :create, :destroy ]
  resources :volunteer_tags, only: [ :create, :destroy ]
  resources :users, only: [ :create, :destroy ]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  get "/login", to: "sessions#new", as: :login

  get '/favicon.ico', to: proc { [204, {}, []] }


  # Defines the root path route ("/")
  root "welcome#index"
end

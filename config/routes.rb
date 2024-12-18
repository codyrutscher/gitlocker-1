Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  resources :follows
  get 'proxy/fetch_forum', to: 'proxy#fetch_forum', as: :fetch_forum
  get 'proxy/fetch_youtube', to: 'proxy#fetch_youtube', as: :fetch_youtube
  get '/workflows/:id', to: 'workflows#index', as: "workflows"
  post '/workflows/:id', to: 'workflows#index'
  get '/workflows/:id/open_file', to: 'workflows#open_file', as: "open_file"
  post '/workflows/:id/save_file', to: 'workflows#save_file', as: "save_file"
  get '/workflows/:id/create_file', to: 'workflows#create_file', as: "create_file"
  get '/workflows/:id/rename_file', to: 'workflows#rename_file', as: "rename_file"
  get '/workflows/:id/rename_folder', to: 'workflows#rename_folder', as: "rename_folder"
  get '/workflows/:id/delete_file', to: 'workflows#delete_file', as: "delete_file"

  get '/workflows/:id/download_zip', to: 'workflows#download_zip', as: "download_zip"
  post '/workflows/:id/upload_zip', to: 'workflows#upload_zip', as: "upload_zip"
  get '/workflows/:id/download_repo', to: 'workflows#download_repo', as: "download_repo"
  get '/workflows/:id/push_to_git', to: 'workflows#push_to_git', as: "push_to_git"

  post '/workflows/:id/new_project', to: 'workflows#new_project', as: "new_project"
  delete '/workflows/:id/delete_project', to: 'workflows#delete_project', as: "delete_project"
  get '/workflows/:id/save_project', to: 'workflows#save_project', as: "save_project"
  get '/workflows/:id/project_from_s3', to: 'workflows#project_from_s3', as: "project_from_s3"
  delete '/workflows/:id/remove_existing_project', to: 'workflows#remove_existing_project', as: "remove_existing_project"
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  if Rails.env.production?
    constraints(host: /^(?!www\.)/i) do
      match '(*any)', to: redirect { |params, request|
        URI.parse(request.url).tap { |uri| uri.host = "www.#{uri.host}" }.to_s
      }, via: :all
    end
  end
  root "marketplace/home#index"

  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    omniauth_callbacks: "users/omniauth_callbacks",
    passwords: 'passwords'
  }
  devise_scope :user do
    get '/password_instructions', to: 'passwords#show_instructions'
    get '/signup_success', to: 'users/registrations#signup_success', as: 'signup_success'
  end
  # config/routes.rb

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")

  get "privacy", to: "home#privacy"
  get "explore", to: "home#explore"
  get "terms", to: "home#terms"
  get "refund_policy", to: "home#refund_policy"
  get "deployment_options", to: "home#deployment_options"
  get "contact", to: "home#contact"
  # get "pricing", to: "home#pricing"
  get "robots.txt", to: "home#robots"
  get '/sitemaps/:filename', to: 'home#sitemap'

  get "dashboard", to: "dashboard#index"
  get "seller_dashboard", to: "dashboard#seller_dashboard"

  get "complete_registrations", to: "complete_registrations#index"
  put "complete_registration", to: "complete_registrations#update"

  get "complete_developer_registrations", to: "complete_developer_registrations#index"
  put "complete_developer_registration", to: "complete_developer_registrations#update"

  get "pricing", to: "pricing#index"
  get 'toggle_pricing', to: 'pricing#toggle_pricing'

  namespace :pricing do
    get :success
    get :subscription
    get :process_checkout_result
    get :cancel_subscription
  end

  resources :accounts

  resources :products, only: [:index, :show, :edit, :update,:new, :create, :destroy] do
    resources :covers, only: [:create, :destroy], controller: "product_covers"
    post 'like', on: :member
    post 'unlike', on: :member
    get 'search', on: :collection
  end
  get 'search_repositories/(:query)', to: "products#search_repositories"

  resources :subscribed_users, only: :create


  resources :sales, only: [:index, :show]
  resources :funds, only: [:index, :create]
  resources :blogs, param: :slug

  get "coming_soon", to: "coming_soon#index"
  get "index_deploy", to: "coming_soon#index_deploy"
  get "index_jobs", to: "coming_soon#index_jobs"
  get "index_versioning", to: "coming_soon#index_versioning"
  get "index_messages", to: "coming_soon#index_messages"
  get "landing_page", to: "coming_soon#landing_page"
  get "faq", to: "faq#index"
  get "resources", to: "marketplace/home#resources"
  get "forum", to: "marketplace/home#forum"
  get "youtube", to: "marketplace/home#youtube"
  
  namespace :marketplace do
    root "home#index"
    get "browse", to: "browse#index"
    get "browse/popular", to: "browse#popular"
     get "browse/free", to: "browse#free"
      get "browse/premium", to: "browse#premium"
    get "browse/featured", to: "browse#featured"
    get "browse/recent", to: "browse#recent"
    get "browse/languages", to: "browse#languages"
    get "browse/categories", to: "browse#categories"
    get "creators/show", to: "creators#show"
    resources :creators, only: [:index, :show]
    resources :languages, only: :show, param: :slug
    resources :categories, only: [:show, :create], param: :slug
    resources :library, only: :show, path: "l" do
      resources :reviews, only: [:new, :create]
    end
    resources :purchases, only: [:index]
    resources :cart_items, only: [:index, :create, :destroy]
    get "checkout", to: "checkout#index"
    post "checkout", to: "checkout#create"
    post "refund_payment", to: "checkout#refund"
    get '/success_payment', to: 'checkout#success_payment', as: 'success_payment'
    get '/cancel_payment', to: 'checkout#cancel_payment', as: 'cancel_payment'
    resources :refunds, only: [:new, :create]
    resources :users, only: [:show, :edit, :update, :destroy] do
      resources :products, only: :index, controller: "users/products"
      get :synchronizations, to: "users/synchronizations#show", on: :member
      put :product_activations, to: "users/product_activations#update", on: :member
      member do
        get 'followers', to: 'users#followers', as: 'user_followers'
        get 'followees', to: 'users#followees', as: 'user_followees'
      end
    end
    post '/users/:id/follow', to: "users#follow", as: "follow_user"
    post '/users/:id/unfollow', to: "users#unfollow", as: "unfollow_user"
    get "search", to: "search_results#index"
    
    resources :notifications, only: [:index] do
      member do
        get :mark_as_read
      end
      collection do
        get :mark_all_as_read
      end
    end
  end

  # Error Pages
  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#unacceptable', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end

Rails.application.routes.draw do
  # Secure Sidekiq web UI with authentication
  authenticate :admin_user do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  resources :follows
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
        URI.parse(request.url).tap { |uri| uri.host = "www.#{uri.host}"; uri.scheme = "https" }.to_s
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
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")

  get "privacy", to: "home#privacy"
  get "test", to: "home#test"
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

  resources :templates, only: %i[show index] do
    member do
      post :clone
    end
    collection do
      get :create_default_templates
    end
  end

  resources :products, only: [:index, :show, :edit, :update,:new, :create, :destroy] do
    resources :covers, only: [:create, :destroy], controller: "product_covers"
    post :add_collaborator, on: :member
    delete :remove_collaborator, on: :member
    get 'new_product', on: :collection
    post 'create_from_github', on: :collection
    post 'create_from_gitlab', on: :collection
    post 'import_products', on: :collection
    post 'build_product_from_ai', on: :collection
    post 'build_product_file_from_ai', on: :collection
    post 'like', on: :member
    post 'unlike', on: :member
    get 'search', on: :collection
    post 'replace_file', on: :member
    get 'show_file_content', on: :member
    get 'deployments', on: :member
    get 'issues', on: :member
    get 'configurations', on: :member
    get 'pullrequests', on: :member
    get 'branches', on: :member
    get 'commits', on: :member
    get 'team', on: :member
    get 'code', on: :member
    get 'load_more_github_repos', on: :collection
    get 'load_more_gitlab_repos', on: :collection
    get :export_data, on: :collection
    get 'add_collaborator', on: :member
    get 'add_file_or_folder', on: :member
  end
  get 'search_repositories/(:query)', to: "products#search_repositories"
  get 'teamrepositories', to: "products#teamrepositories"

  resources :subscribed_users, only: :create

  resources :sales, only: [:index, :show]
  resources :funds, only: [:index, :create]
  resources :blogs, param: :slug do
    get :export_data, on: :collection
  end

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
  get "careers", to: "marketplace/home#careers"
  get "manage", to: "marketplace/home#manage"
  get "documentationindex", to: "marketplace/home#documentationindex"
  get "documentationreact", to: "marketplace/home#documentationreact"
  get "documentation_rails", to: "marketplace/home#documentation_rails"
  get "documentation_django", to: "marketplace/home#documentation_django"
  get "documentation_laravel", to: "marketplace/home#documentation_laravel"
  get "documentation_html_css", to: "marketplace/home#documentation_html_css"
  get "documentation_tailwindcss", to: "marketplace/home#documentation_tailwindcss"

  post 'update_file_content', to: 'products#update_file_content'

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
    resources :languages, only: :show, param: :slug do
      collection do
        get :load_more
      end
    end
    resources :categories, only: [:show, :create], param: :slug do
      collection do
        get :load_more
      end
    end
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
      collection do
        get :search # this maps to Marketplace::UsersController#search
      end
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

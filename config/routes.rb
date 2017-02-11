Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => 'brakes#index'
  resources :brakes do
    member do
      get :brake_products
    end
  end

  get '/gather_brake_category' => 'brakes#gather_brake_category', :as => 'brake_data'
  put '/print_me' => 'brakes#print_me', :as => 'print_me'


end

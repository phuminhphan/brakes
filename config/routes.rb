Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => 'brakes#index'
  resources :brakes

  get '/gather_brake_data' => 'brakes#gather_brake_data', :as => 'brake_data'
  put '/print_me' => 'brakes#print_me', :as => 'print_me'
end

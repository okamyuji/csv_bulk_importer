# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users,
             path: "api/v1",
             path_names: {
               sign_in: "sessions",
               sign_out: "sessions",
               registration: "registrations",
             },
             controllers: {
               sessions: "api/v1/sessions",
               registrations: "api/v1/registrations",
             },
             defaults: {
               format: :json,
             }

  namespace :api do
    namespace :v1 do
      get "me", to: "me#show"
      resources :csv_imports, only: %i[index show create] do
        post :retry, on: :member
      end
    end
  end

  get "up" => "rails/health#show", :as => :rails_health_check

  get "*path", to: "spa#index", constraints: ->(req) { !req.path.start_with?("/api/", "/cable", "/rails/") }
  root "spa#index"
end

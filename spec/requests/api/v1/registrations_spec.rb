# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  describe "POST /api/v1/registrations" do
    it "creates a user and returns a bearer token without relying on session cookies" do
      post "/api/v1/registrations",
           params: {
             user: {
               email: "new-user@example.com",
               password: "password",
               password_confirmation: "password",
               name: "New User",
             },
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Origin" => "http://localhost:5173",
           }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("user", "email")).to eq("new-user@example.com")
      expect(body["token"]).to be_present
      expect(response.headers["Authorization"]).to match(/\ABearer /)
      expect(response.headers["Set-Cookie"]).to be_blank
    end

    it "returns validation errors" do
      post "/api/v1/registrations",
           params: { user: { email: "", password: "password", password_confirmation: "password", name: "" } }.to_json,
           headers: {
             "Content-Type" => "application/json",
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("invalid")
    end

    it "audits sign-up failures with attribute names instead of full messages to avoid PII leak" do
      events = []
      allow(AuditLogger).to receive(:event) { |name, **payload| events << [name, payload] }

      post "/api/v1/registrations",
           params: {
             user: {
               email: "leaks@example.com",
               password: "x",
               password_confirmation: "y",
               name: "",
             },
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
           }

      failure = events.find { |name, _| name == "auth.sign_up_failure" }
      expect(failure).not_to be_nil
      reasons = failure.last[:reasons]
      expect(reasons).to all(be_a(Symbol))
      expect(reasons).not_to include(match(/leaks@example\.com/i))
    end

    it "rolls back the user when JWT issuance fails so the email is not orphaned" do
      stub_const(
        "Warden::JWTAuth::UserEncoder",
        Class.new do
          def call(*)
            raise JWT::EncodeError, "boom"
          end
        end,
      )

      expect {
        post "/api/v1/registrations",
             params: {
               user: {
                 email: "rollback@example.com",
                 password: "password",
                 password_confirmation: "password",
                 name: "Rollback",
               },
             }.to_json,
             headers: {
               "Content-Type" => "application/json",
             }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["error"]).to eq("service_unavailable")
    end
  end
end

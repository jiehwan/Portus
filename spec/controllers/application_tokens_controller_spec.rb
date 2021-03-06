# frozen_string_literal: true

# == Schema Information
#
# Table name: application_tokens
#
#  id          :integer          not null, primary key
#  application :string(255)      not null
#  token_hash  :string(255)      not null
#  token_salt  :string(255)      not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_application_tokens_on_user_id  (user_id)
#

require "rails_helper"

describe ApplicationTokensController do
  let(:user) { create(:user) }
  let(:application) { "test application" }

  describe "POST #create" do
    before do
      sign_in user
    end

    it "creates the token" do
      expect do
        post :create, application_token: { application: application }, format: "js"
      end.to change(user.application_tokens, :count).by(1)
    end

    it "creates an activity event" do
      expect do
        post :create, application_token: { application: application }, format: "js"
      end.to change(PublicActivity::Activity, :count).by(1)

      activity = PublicActivity::Activity.last
      expect(activity.owner).to eq(user)
      expect(activity.parameters[:application]).to eq(application)
    end

    it "responds with unprocessable entity when the token cannot be created" do
      create(:application_token, application: application, user: user)
      expect do
        post :create, application_token: { application: application }, format: "js"
      end.to change(user.application_tokens, :count).by(0)

      expect(response.status).to be 422
    end
  end

  describe "DELETE #destroy" do
    before do
      sign_in user
    end

    it "removes the token" do
      token = create(:application_token, user: user)
      expect do
        delete :destroy, id: token.id, format: "js"
      end.to change(user.application_tokens, :count).by(-1)
    end

    it "creates an activity event" do
      token = create(:application_token, user: user)
      expect do
        delete :destroy, id: token.id, format: "js"
      end.to change(PublicActivity::Activity, :count).by(1)

      activity = PublicActivity::Activity.last
      expect(activity.owner).to eq(user)
      expect(activity.parameters[:application]).to eq(token.application)
    end
  end

  describe "Authentication through application tokens" do
    it "can authenticate through an application token" do
      create(:registry)
      create(:application_token, application: application, user: user)

      # Here's the trick :)
      request.headers["PORTUS-AUTH"] = "#{user.username}:#{application}"

      expect do
        post :create, application_token: { application: "another" }, format: "js"
      end.to change(user.application_tokens, :count).by(1)
    end
  end
end

class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    auth_hash = request.env["omniauth.auth"]
    user = User.find_or_create_from_google(auth_hash)

    if user.persisted?
      start_new_session_for(user)
      claim_anonymous_decks!(user)
      redirect_to root_path, notice: "Signed in as #{user.email_address}."
    else
      redirect_to new_session_path, alert: "Could not sign in with Google. Please try again."
    end
  end

  def failure
    redirect_to new_session_path, alert: "Google sign-in failed: #{params[:message].humanize}."
  end
end

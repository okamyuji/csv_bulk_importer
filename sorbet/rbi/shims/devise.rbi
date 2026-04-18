# typed: true

# Shim for Devise helpers and controllers that Tapioca's RBI doesn't expose.

class ActionController::Base
  sig { returns(T.nilable(User)) }
  def current_user; end

  sig { returns(T::Boolean) }
  def user_signed_in?; end

  sig { void }
  def authenticate_user!; end
end

class ActionController::API
  sig { returns(T.nilable(User)) }
  def current_user; end

  sig { returns(T::Boolean) }
  def user_signed_in?; end

  sig { void }
  def authenticate_user!; end
end

class ActiveRecord::Base
  class << self
    sig { params(modules: Symbol, options: T.untyped).void }
    def devise(*modules, **options); end
  end
end

# DeviseController (the shared parent of Devise::SessionsController/RegistrationsController/...)
# is declared in sorbet/rbi/annotations/devise.rbi without the Rails controller API.
# Reopen it here to expose the controller methods our subclasses actually call.
class DeviseController
  class << self
    sig { params(args: T.untyped).void }
    def respond_to(*args); end

    sig { params(actions: T.untyped, options: T.untyped).void }
    def skip_before_action(*actions, **options); end

    sig { params(options: T.untyped).void }
    def protect_from_forgery(**options); end
  end

  sig { returns(ActionDispatch::Request) }
  def request; end

  sig { returns(T.nilable(User)) }
  def current_user; end

  sig { returns(ActionController::Parameters) }
  def params; end

  sig { params(args: T.untyped).void }
  def render(*args); end

  sig { params(status: T.untyped, options: T.untyped).void }
  def head(status, **options); end
end

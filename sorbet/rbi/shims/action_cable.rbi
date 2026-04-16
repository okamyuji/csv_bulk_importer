# typed: true

class ActionCable::Channel::Base
  sig { returns(T.untyped) }
  def params; end

  sig { returns(T.nilable(User)) }
  def current_user; end
end

class ActionCable::Connection::Base
  sig { returns(ActionDispatch::Request) }
  def request; end

  sig { returns(T.noreturn) }
  def reject_unauthorized_connection; end
end

# typed: true

class Pundit::NotAuthorizedError
  sig { returns(T.untyped) }
  def policy; end

  sig { returns(T.untyped) }
  def query; end

  sig { returns(T.untyped) }
  def record; end
end

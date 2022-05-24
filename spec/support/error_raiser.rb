class ErrorRaiser
  def initialize(error_class)
    @error_class = error_class
  end

  def call
    raise error_class
  end

  private

  attr_reader :error_class
end
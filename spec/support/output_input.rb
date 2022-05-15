class OutputInput
  def initialize(input)
    @input = input
  end

  def call
    input
  end

  private

  attr_reader :input
end
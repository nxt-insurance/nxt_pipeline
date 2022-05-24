class StringTransformer
  def initialize(word, operation)
    @word = word
    @operation = operation
  end

  attr_reader :word, :operation

  def call
    word.send(operation)
  end
end
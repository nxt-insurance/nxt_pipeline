module NxtPipeline
  class Constructor
    def initialize(name, opts, block)
      @name = name
      @block = block
      @opts = opts
    end

    attr_reader :opts, :block

    delegate :call, :arity, to: :block
  end
end

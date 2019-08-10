module NxtPipeline
  class Constructor
    def initialize(name, opts, block)
      @name = name
      @block = block
      @opts = opts
    end

    attr_reader :block, :opts

    delegate_missing_to :block
  end
end

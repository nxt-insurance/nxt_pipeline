module NxtPipeline
  class Constructor
    def initialize(name, opts, block)
      @name = name
      @block = block
      @opts = opts
    end

    attr_reader :opts

    def call(*args, **opts)
      block.call(*args, **opts)
    end

    private

    attr_reader :block
  end
end

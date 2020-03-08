module NxtPipeline
  class Constructor
    def initialize(name, **opts, &block)
      @name = name
      @block = block
      @opts = opts
    end

    attr_reader :opts, :block
    
    delegate :arity, to: :block
    
    def call(*args, **opts, &block)
      # ActiveSupport's #delegate does not properly handle keyword arg passing
      # in the latest released version. Thefore we bypass delegation by reimplementing
      # the method ourselves. This is already fixed in Rails master though.
      self.block.call(*args, **opts, &block)
    end
  end
end

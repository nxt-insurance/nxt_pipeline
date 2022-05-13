module NxtPipeline
  class Constructor
    def initialize(type, **opts, &block)
      @type = type
      @block = block
      @opts = opts
    end

    attr_reader :opts, :block
    
    delegate :arity, to: :block
    
    def call(step, **opts, &block)
      # ActiveSupport's #delegate does not properly handle keyword arg passing
      # in the latest released version. Thefore we bypass delegation by reimplementing
      # the method ourselves. This is already fixed in Rails master though.
      self.block.call(step, **opts, &block)
    end
  end
end

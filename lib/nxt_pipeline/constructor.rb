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
      # Delegating #call to block somehow passes the opts as hash to it without
      # double splat operator which causes Ruby 2.7 to scream warning like crazy.
      # Therefore we implement #call here again.
      self.block.call(*args, **opts, &block)
    end
  end
end

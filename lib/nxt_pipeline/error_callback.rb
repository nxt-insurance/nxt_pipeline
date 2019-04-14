module NxtPipeline
  class ErrorCallback < Hash
    def initialize(errors, block)
      @errors = errors
      @block = block
    end

    attr_accessor :errors, :block

    def applies_to_error?(error)
      (error.class.ancestors & errors).any?
    end

    def call(step, arg, error)
      block.call(step, arg, error)
    end
  end
end
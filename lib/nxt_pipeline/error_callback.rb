module NxtPipeline
  class ErrorCallback
    def initialize(errors, callback)
      @errors = errors
      @callback = callback
    end

    attr_accessor :errors, :callback

    def applies_to_error?(error)
      (error.class.ancestors & errors).any?
    end

    def call(step, arg, error)
      callback.call(step, arg, error)
    end
  end
end

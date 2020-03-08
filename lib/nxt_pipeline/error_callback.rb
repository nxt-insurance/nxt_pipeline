module NxtPipeline
  class ErrorCallback
    def initialize(errors, halt_on_error, &callback)
      @errors = errors
      @halt_on_error = halt_on_error
      @callback = callback
    end

    attr_accessor :errors, :callback

    def halt_on_error?
      @halt_on_error
    end

    def continue_after_error?
      !halt_on_error?
    end

    def applies_to_error?(error)
      (error.class.ancestors & errors).any?
    end

    def call(step, arg, error)
      callback.call(step, arg, error)
    end
  end
end

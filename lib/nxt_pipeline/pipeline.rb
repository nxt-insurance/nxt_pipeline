module NxtPipeline
  class Pipeline
    def self.execute(opts, &block)
      new(&block).execute(opts)
    end

    def initialize(&block)
      @steps = []
      @error_callbacks = []
      @logger = Logger.new
      @current_step = nil
      @current_arg = nil
      @default_constructor_name = nil
      @registry = {}
      configure(&block) if block_given?
    end

    attr_accessor :logger

    # register steps with name and block
    def constructor(name, **opts, &constructor)
      name = name.to_sym
      raise StandardError, "Already registered step :#{name}" if registry[name]

      registry[name] = constructor

      return unless opts.fetch(:default, false)
      default_constructor_name ? (raise ArgumentError, 'Default step already defined') : self.default_constructor_name = name
    end

    def step(type = nil, **opts, &block)
      constructor = if block_given?
        type ||= :inline
        # make first argument the to_s of step if given
        # opts.merge!(to_s: type) if type && !opts.key?(:to_s)
        block
      else
        if type
          registry.fetch(type) { raise KeyError, "No step :#{type} registered" }
        else
          type = default_constructor_name
          default_constructor || (raise StandardError, 'No default step registered')
        end
      end

      steps << Step.new(type, constructor, **opts)
    end

    def execute(arg, &block)
      reset

      configure(&block) if block_given?
      before_execute_callback.call(self, arg) if before_execute_callback.respond_to?(:call)

      result = steps.inject(arg) do |argument, step|
        execute_step(step, argument)
      end

      after_execute_callback.call(self, result) if after_execute_callback.respond_to?(:call)
      result
    rescue StandardError => error

      log_step(current_step)
      callback = find_error_callback(error)

      raise unless callback
      callback.call(current_step, current_arg, error)
    end

    def on_errors(*errors, &callback)
      error_callbacks << ErrorCallback.new(errors, callback)
    end

    alias :on_error :on_errors

    def before_execute(&callback)
      self.before_execute_callback = callback
    end

    def after_execute(&callback)
      self.after_execute_callback = callback
    end

    def configure(&block)
      block.call(self)
      self
    end

    private

    attr_reader :error_callbacks, :registry
    attr_accessor :steps, :current_step, :current_arg, :default_constructor_name, :before_execute_callback, :after_execute_callback

    def default_constructor
      return unless default_constructor_name
      @default_constructor ||= registry[default_constructor_name.to_sym]
    end

    def execute_step(step, arg)
      self.current_step = step
      self.current_arg = arg
      result = step.execute(arg)
      log_step(step)
      result || arg
    end

    def find_error_callback(error)
      error_callbacks.find { |callback| callback.applies_to_error?(error) }
    end

    def log_step(step)
      logger.call(step) if logger.respond_to?(:call)
    end

    def reset
      self.current_arg = nil
      self.current_step = nil
    end
  end
end

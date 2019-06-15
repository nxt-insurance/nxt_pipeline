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

    alias_method :configure, :tap

    attr_accessor :logger

    # register steps with name and block
    def constructor(name, **opts, &constructor)
      name = name.to_sym
      raise StandardError, "Already registered step :#{name}" if registry[name]

      registry[name] = constructor

      return unless opts.fetch(:default, false)
      set_default_constructor(name)
    end

    def set_default_constructor(name)
      raise_duplicate_default_constructor if default_constructor_name.present?
      self.default_constructor_name = name
    end

    def raise_duplicate_default_constructor
      raise ArgumentError, 'Default step already defined'
    end

    def step(type = nil, **opts, &block)
      constructor = if block_given?
        # make type the :to_s of inline steps
        # fall back to :inline if no type is given
        type ||= :inline
        opts.reverse_merge!(to_s: type)
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

    private

    attr_reader :error_callbacks, :registry
    attr_accessor :steps,
                  :current_step,
                  :current_arg,
                  :default_constructor_name,
                  :before_execute_callback,
                  :after_execute_callback

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
      return unless logger.respond_to?(:call)

      logger.call(step)
    end

    def reset
      self.current_arg = nil
      self.current_step = nil
    end
  end
end

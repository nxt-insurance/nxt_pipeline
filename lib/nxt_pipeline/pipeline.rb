module NxtPipeline
  class Pipeline
    def self.execute(opts, &block)
      new(&block).execute(opts)
    end

    def initialize(&block)
      @steps = []
      @error_callbacks = []
      @log = {}
      @current_step = nil
      @current_arg = nil
      @default_constructor = nil
      @registry = {}
      configure(&block) if block_given?
    end

    attr_reader :log

    # register steps with name and block
    def constructor(name, **opts, &constructor)
      name = name.to_sym
      raise StandardError, "Already registered step :#{name}" if registry[name]

      registry[name] = constructor

      return unless opts.fetch(:default, false)
      default_constructor ? (raise ArgumentError, 'Default step already defined') : self.default_constructor = constructor
    end

    def step(type = nil, **opts, &block)
      constructor = if block_given?
        # make first argument the to_s of step if given
        opts.merge!(to_s: type) if type && !opts.key?(:to_s)
        block
      else
        if type
          registry.fetch(type) { raise KeyError, "No step :#{type} registered" }
        else
          default_constructor || (raise StandardError, 'No default step registered')
        end
      end

      steps << Step.new(constructor, **opts)
    end

    def execute(arg, &block)
      reset_log
      before_execute_callback.call(arg) if before_execute_callback.respond_to?(:call)
      configure(&block) if block_given?
      result = steps.inject(arg) do |argument, step|
        execute_step(step, argument)
      end
      after_execute_callback.call(result, log) if after_execute_callback.respond_to?(:call)
      result
    rescue StandardError => error
      log[current_step] = { status: :failed, reason: "#{error.class}: #{error.message}" }
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
    attr_accessor :steps, :current_step, :current_arg, :default_constructor, :before_execute_callback, :after_execute_callback
    attr_writer :log

    def execute_step(step, arg)
      self.current_step = step.to_s
      self.current_arg = arg
      result = step.execute(arg)

      if result # step was successful
        log[current_step] = { status: :success }
        result
      else # step was not successful if nil or false
        log[current_step] = { status: :skipped }
        arg
      end
    end

    def find_error_callback(error)
      error_callbacks.find { |callback| callback.applies_to_error?(error) }
    end

    def reset_log
      self.log = {}
      self.current_arg = nil
    end
  end
end

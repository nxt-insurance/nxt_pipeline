module NxtPipeline
  class Pipeline
    def self.execute(**opts, &block)
      new(&block).execute(**opts)
    end

    def initialize(step_resolvers = default_step_resolvers, &block)
      @steps = []
      @error_callbacks = []
      @logger = Logger.new
      @current_step = nil
      @current_arg = nil
      @default_constructor_name = nil
      @constructors = {}
      @step_resolvers = step_resolvers

      configure(&block) if block_given?
    end

    alias_method :configure, :tap

    attr_accessor :logger, :steps

    def constructor(name, **opts, &constructor)
      name = name.to_sym
      raise StandardError, "Already registered step :#{name}" if constructors[name]

      constructors[name] = Constructor.new(name, opts, constructor)

      return unless opts.fetch(:default, false)
      set_default_constructor(name)
    end

    def step_resolver(&block)
      step_resolvers << block
    end

    def set_default_constructor(name)
      raise_duplicate_default_constructor if default_constructor_name.present?
      self.default_constructor_name = name
    end

    def raise_duplicate_default_constructor
      raise ArgumentError, 'Default step already defined'
    end

    def step(argument = nil, **opts, &block)
      constructor = if block_given?
        # make type the :to_s of inline steps
        # fall back to :inline if no type is given
        argument ||= :inline
        opts.reverse_merge!(to_s: argument)
        Constructor.new(:inline, opts, block)
      else
        constructor = step_resolvers.lazy.map do |resolver|
          resolver.call(argument)
        end.find(&:itself)

        if constructor
          constructor && constructors.fetch(constructor) { raise KeyError, "No step :#{argument} registered" }
        elsif default_constructor
          argument ||= default_constructor_name
          default_constructor
        else
          raise StandardError, "Could not resolve step from: #{argument}"
        end
      end

      steps << Step.new(argument, constructor, steps.count, **opts)
    end

    def execute(**changeset, &block)
      reset

      configure(&block) if block_given?
      before_execute_callback.call(self, changeset) if before_execute_callback.respond_to?(:call)

      result = steps.inject(changeset) do |changeset, step|
        execute_step(step, **changeset)
      rescue StandardError => error
        callback = find_error_callback(error)
        raise unless callback && callback.continue_after_error?
        handle_step_error(error)
        changeset
      end

      after_execute_callback.call(self, result) if after_execute_callback.respond_to?(:call)
      result
    rescue StandardError => error
      handle_step_error(error)
    end

    def handle_step_error(error)
      log_step(current_step)
      callback = find_error_callback(error)

      raise unless callback

      callback.call(current_step, current_arg, error)
    end

    def on_errors(*errors, halt_on_error: true, &callback)
      error_callbacks << ErrorCallback.new(errors, halt_on_error, callback)
    end

    alias :on_error :on_errors

    def before_execute(&callback)
      self.before_execute_callback = callback
    end

    def after_execute(&callback)
      self.after_execute_callback = callback
    end

    private

    attr_reader :error_callbacks, :constructors, :step_resolvers
    attr_accessor :current_step,
                  :current_arg,
                  :default_constructor_name,
                  :before_execute_callback,
                  :after_execute_callback

    def default_constructor
      return unless default_constructor_name

      @default_constructor ||= constructors[default_constructor_name.to_sym]
    end

    def execute_step(step, **changeset)
      self.current_step = step
      self.current_arg = changeset
      result = step.execute(**changeset)
      log_step(step)
      result || changeset
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

    def raise_reserved_type_inline_error
      raise ArgumentError, 'Type :inline is reserved for inline steps!'
    end

    def default_step_resolvers
      [->(step_argument) { step_argument.is_a?(Symbol) && step_argument }]
    end
  end
end

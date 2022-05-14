module NxtPipeline
  class Pipeline
    def self.call(acc, configuration = nil, resolvers: [], &block)
      new(configuration, resolvers: resolvers, &block).call(acc)
    end

    def initialize(configuration = nil, resolvers: [], &block)
      @steps = []
      @error_callbacks = []
      @logger = Logger.new
      @current_step = nil
      @current_arg = nil
      @default_constructor_name = nil
      @constructors = {}
      @constructor_resolvers = resolvers
      @result = nil

      if configuration.present?
        config = ::NxtPipeline.configuration(configuration)
        configure(&config)
      end

      configure(&block) if block_given?
    end

    alias_method :configure, :tap

    attr_accessor :logger
    attr_reader :result

    def constructor(name, default: false, &constructor)
      name = name.to_sym
      raise StandardError, "Already registered step :#{name}" if constructors[name]

      constructors[name] = constructor

      return unless default
      set_default_constructor(name)
    end

    def constructor_resolver(&block)
      constructor_resolvers << block
    end

    def set_default_constructor(default_constructor)
      raise_duplicate_default_constructor if default_constructor_name.present?
      self.default_constructor_name = default_constructor
    end

    def raise_duplicate_default_constructor
      raise ArgumentError, 'Default step already defined'
    end

    # Overwrite reader to also define steps
    def steps(steps = [], &block)
      return @steps unless steps.any?

      steps.each do |args|
        arguments = Array(args)
        if arguments.size == 1
          step(arguments.first)
        elsif arguments.size == 2
          step(arguments.first, **arguments.second)
        else
          raise ArgumentError, "Either pass a single argument or an argument and options"
        end
      end
    end

    # Allow to force steps with setter
    def steps=(steps = [])
      # reset steps to be zero
      @steps = []
      steps(steps)
    end

    def step(argument, constructor: nil, **opts, &block)

      if constructor.present? and block_given?
        msg = "Either specify a block or a constructor but not both at the same time!"
        raise ArgumentError, msg
      end

      to_s = if opts[:to_s].present?
               opts[:to_s] = opts[:to_s].to_s
             else
               if argument.is_a?(Proc) || argument.is_a?(Method)
                 steps.count.to_s
               else
                 argument.to_s
               end
             end


      opts.reverse_merge!(to_s: to_s)

      if constructor.present?
        # p.step Service, constructor: ->(step, **changes) { ... }
        if constructor.respond_to?(:call)
          # resolved_constructor = Constructor.new(:block, **opts, &constructor)
          resolved_constructor = constructor
        else
          # p.step Service, constructor: :service
          resolved_constructor = constructors.fetch(constructor) {
            ::NxtPipeline.constructor(constructor) || (raise ArgumentError, "No constructor defined for #{constructor}")
          }
        end
      elsif block_given?
        # p.step :inline do ... end
        # resolved_constructor = Constructor.new(:block, **opts, &block)
        resolved_constructor = block
      else
        # If no constructor was given try to resolve one
        resolvers = constructor_resolvers.any? ? constructor_resolvers : []

        constructor_from_resolvers = resolvers.map do |resolver|
          resolver.call(argument, **opts)
        end.find(&:itself)

        # resolved constructor is a proc
        if constructor_from_resolvers.is_a?(Proc)
          # resolved_constructor = Constructor.new(:proc, **opts, &constructor_from_resolvers)
          resolved_constructor = constructor_from_resolvers
        elsif constructor_from_resolvers.present?
          resolved_constructor = constructors[constructor_from_resolvers]
        else
          # try to resolve constructor by argument --> #TODO: Is this a good idea?
          resolved_constructor = constructors[argument]
        end


        # if still no constructor resolved
        unless resolved_constructor.present?
          if argument.is_a?(NxtPipeline::Pipeline)
            pipeline_constructor = ->(changes) { argument.call(changes) }
            # resolved_constructor = Constructor.new(:pipeline, **opts, &pipeline_constructor)
            resolved_constructor = pipeline_constructor
          # last chance: default constructor
          elsif default_constructor.present?
            resolved_constructor = default_constructor
          # now we really give up :-(
          else
            raise ArgumentError, "Could neither find nor resolve any constructor for #{argument}, #{opts}"
          end
        end
      end

      register_step(argument, resolved_constructor, callbacks, **opts)
    end

    def call(acc, &block)
      reset

      configure(&block) if block_given?
      callbacks.run(:before, :execution, acc)

      self.result = callbacks.around :execution, acc do
        steps.inject(acc) do |changes, step|
          self.result = call_step(step, changes)
        rescue StandardError => error
          decorate_error_with_details(error, changes, step, logger)
          handle_error_of_step(error)
          result
        end
      end

      # callbacks.run(:after, :execution, result) TODO: Better pass result to callback?
      self.result = callbacks.run(:after, :execution, acc) || result
    rescue StandardError => error
      handle_step_error(error)
    end

    def handle_step_error(error)
      log_step(current_step)
      callback = find_error_callback(error)

      raise unless callback

      callback.call(current_arg, current_step, error)
    end

    def on_errors(*errors, halt_on_error: true, &callback)
      error_callbacks << ErrorCallback.new(errors, halt_on_error, &callback)
    end

    alias :on_error :on_errors

    def before_step(&block)
      callbacks.register([:before, :step], block)
    end

    def after_step(&block)
      callbacks.register([:after, :step], block)
    end

    def around_step(&block)
      callbacks.register([:around, :step], block)
    end

    def before_execution(&block)
      callbacks.register([:before, :execution], block)
    end

    def after_execution(&block)
      callbacks.register([:after, :execution], block)
    end

    def around_execution(&block)
      callbacks.register([:around, :execution], block)
    end

    private

    attr_writer :result

    def callbacks
      @callbacks ||= NxtPipeline::Callbacks.new(pipeline: self)
    end

    attr_reader :error_callbacks, :constructors, :constructor_resolvers
    attr_accessor :current_step,
      :current_arg,
      :default_constructor_name

    def default_constructor
      return unless default_constructor_name

      @default_constructor ||= constructors[default_constructor_name.to_sym]
    end

    def call_step(step, acc)
      self.current_step = step
      self.current_arg = acc
      result = step.call(acc)
      log_step(step)
      result || acc
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

    # def default_constructor_resolver
    #   [->(argument, _) { argument }]
    # end

    def decorate_error_with_details(error, change_set, step, logger)
      error.define_singleton_method :details do
        OpenStruct.new(
          change_set: change_set,
          logger: logger,
          step: step
        )
      end
      error
    end

    def register_step(argument, constructor, callbacks, **opts)
      steps << Step.new(argument, constructor, steps.count, self, callbacks, **opts)
    end

    def handle_error_of_step(error)
      error_callback = find_error_callback(error)
      raise error unless error_callback.present? && error_callback.continue_after_error?

      log_step(current_step)
      raise error unless error_callback.present?

      error_callback.call(current_arg, current_step, error)
    end
  end
end

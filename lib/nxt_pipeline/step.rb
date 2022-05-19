module NxtPipeline
  class Step
    RESERVED_OPTION_KEYS  = %i[to_s unless if]

    def initialize(argument, constructor, index, pipeline, callbacks, **opts)
      @opts = opts.symbolize_keys

      @pipeline = pipeline
      @callbacks = callbacks
      @argument = argument
      @index = index
      @constructor = constructor
      @to_s = opts.fetch(:to_s) { argument }
      @options_mapper = opts[:map_options]

      @status = nil
      @result = nil
      @error = nil
      @mapped_options = nil
      @meta_data = nil

      define_option_readers
    end

    attr_reader :argument,
      :result,
      :execution_started_at,
      :execution_finished_at,
      :execution_duration,
      :error,
      :opts,
      :index,
      :mapped_options

    attr_writer :to_s
    attr_accessor :meta_data, :status

    def call(acc)
      track_execution_time do
        set_mapped_options(acc)
        guard_args = [acc, self]

        callbacks.run(:before, :step, acc)

        if evaluate_unless_guard(guard_args) && evaluate_if_guard(guard_args)
          callbacks.around(:step, acc) do
            set_result(acc)
          end
        end

        callbacks.run(:after, :step, acc)

        set_status
        result
      end
    rescue StandardError => e
      self.status = :failed
      self.error = e
      raise
    end

    def set_mapped_options(acc)
      mapper = options_mapper || default_options_mapper
      mapper_args = [acc, self].take(mapper.arity)
      self.mapped_options = mapper.call(*mapper_args)
    end

    def to_s
      @to_s.to_s
    end

    private

    attr_writer :result, :error, :mapped_options, :execution_started_at, :execution_finished_at, :execution_duration
    attr_reader :constructor, :options_mapper, :pipeline, :callbacks

    def evaluate_if_guard(args)
      execute_callable(if_guard, args)
    end

    def evaluate_unless_guard(args)
      !execute_callable(unless_guard, args)
    end

    def set_result(acc)
      args = [acc, self]
      self.result = execute_callable(constructor, args)
    end

    def execute_callable(callable, args)
      args = args.take(callable.arity) unless callable.arity.negative?

      callable.call(*args)
    end

    def if_guard
      opts.fetch(:if) { guard(true) }
    end

    def unless_guard
      opts.fetch(:unless) { guard(false) }
    end

    def guard(result)
      -> { result }
    end

    def define_option_readers
      raise ArgumentError, "#{invalid_option_keys} are not allowed as options" if invalid_option_keys.any?

      options_without_reserved_options.each do |key, value|
        define_singleton_method key.to_s do
          value
        end
      end
    end

    def set_status
      self.status = result.present? ? :success : :skipped
    end

    def track_execution_time(&block)
      set_execution_started_at
      block.call
    ensure
      set_execution_finished_at
      set_execution_duration
    end

    def set_execution_started_at
      self.execution_started_at = Time.current
    end

    def set_execution_finished_at
      self.execution_finished_at = Time.current
    end

    def set_execution_duration
      self.execution_duration = execution_finished_at - execution_started_at
    end

    def default_options_mapper
      # returns an empty hash
      ->(_) { {} }
    end

    def options_without_reserved_options
      opts.except(*reserved_option_keys)
    end

    def reserved_option_keys
      @reserved_option_keys ||= methods + RESERVED_OPTION_KEYS
    end

    def invalid_option_keys
      opts.except(*RESERVED_OPTION_KEYS).keys & methods
    end
  end
end

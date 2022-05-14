module NxtPipeline
  class Step
    def initialize(argument, constructor, index, pipeline, callbacks, **opts)
      define_attr_readers(opts)

      @pipeline = pipeline
      @callbacks = callbacks
      @argument = argument
      @index = index
      @opts = opts
      @constructor = constructor
      @to_s = "#{opts.merge(argument: argument)}"
      @options_mapper = opts[:map_options]

      @status = nil
      @result = nil
      @error = nil
      @mapped_options = nil
    end

    attr_reader :argument,
      :result,
      :status,
      :execution_started_at,
      :execution_finished_at,
      :execution_duration,
      :error,
      :opts,
      :index,
      :mapped_options

    attr_writer :to_s

    alias_method :name=, :to_s=
    alias_method :name, :to_s

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

    attr_writer :result, :status, :error, :mapped_options, :execution_started_at, :execution_finished_at, :execution_duration
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

    def define_attr_readers(opts)
      opts.each do |key, value|
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
  end
end

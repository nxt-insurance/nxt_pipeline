module NxtPipeline
  class Callbacks
    def initialize(pipeline:)
      @registry = build_registry
      @pipeline = pipeline
    end

    def register(path, callback)
      registry.resolve!(*path) << callback
    end

    def run(kind_of_callback, type, change_set)
      callbacks = registry.resolve!(kind_of_callback, type)
      return unless callbacks.any?

      callbacks.inject(change_set) do |changes, callback|
        run_callback(callback, changes)
      end
    end

    def around(type, change_set, &execution)
      around_callbacks = registry.resolve!(:around, type)
      return execution.call unless around_callbacks.any?

      callback_chain = around_callbacks.reverse.inject(execution) do |previous, callback|
        -> { callback.call(change_set, previous, pipeline) }
      end

      callback_chain.call
    end

    private

    attr_reader :registry, :pipeline

    def run_callback(callback, change_set)
      args = [change_set, pipeline]
      args = args.take(callback.arity) unless callback.arity.negative?
      callback.call(*args)
    end

    def build_registry
      NxtRegistry::Registry.new(:callbacks) do
        register(:before) do
          register(:step, [])
          register(:execution, [])
        end

        register(:around) do
          register(:step, [])
          register(:execution, [])
        end

        register(:after) do
          register(:step, [])
          register(:execution, [])
        end
      end
    end
  end
end

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
      registry.resolve!(type, kind_of_callback).each do |callback|
        run_callback(callback, change_set)
      end
    end

    def around(type, change_set, &execution)
      around_callbacks = registry.resolve!(type, :around)
      return execution.call unless around_callbacks.any?

      callback_chain = around_callbacks.reverse.inject(execution) do |previous, callback|
        -> { callback.call(pipeline, change_set, previous) }
      end

      callback_chain.call
    end

    private

    attr_reader :registry, :pipeline

    def run_callback(callback, change_set)
      args = [pipeline, change_set]
      args = args.take(callback.arity)
      callback.call(*args)
    end

    def build_registry
      NxtRegistry::Registry.new(:callbacks) do
        register(:execution) do
          register(:before, [])
          register(:after, [])
          register(:around, [])
        end

        register(:step) do
          register(:before, [])
          register(:after, [])
          register(:around, [])
        end
      end
    end
  end
end

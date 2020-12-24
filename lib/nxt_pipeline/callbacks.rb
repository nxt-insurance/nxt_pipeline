module NxtPipeline
  class Callbacks
    def initialize
      @registry = build_registry
    end

    def register(path, callback)
      registry.resolve!(*path) << callback
    end

    def run(pipeline, type, kind, change_set)
      registry.resolve!(type, kind).each do |callback|
        run_callback(pipeline, callback, change_set)
      end
    end

    def run_around(pipeline, type, args, &execution)
      around_callbacks = registry.resolve!(type, :around)
      return execution.call unless around_callbacks.any?

      callback_chain = around_callbacks.reverse.inject(execution) do |previous, callback|
        -> { callback.call(pipeline, args, previous) }
      end

      callback_chain.call
    end

    private

    attr_reader :registry

    def run_callback(pipeline, callback, change_set)
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

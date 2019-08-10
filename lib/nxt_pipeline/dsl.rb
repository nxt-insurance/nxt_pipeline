module NxtPipeline
  module Dsl
    module ClassMethods
      def pipeline(name = :default, &block)
        name = name.to_sym

        if block_given?
          raise_already_registered_error(name) if pipeline_registry.key?(name)
          pipeline_registry[name] = block
        else
          config = pipeline_registry.fetch(name) { raise KeyError, "No pipeline #{name} registered"}
          NxtPipeline::Pipeline.new(&config)
        end
      end

      def pipeline!(name, &block)
        raise ArgumentError, "No block given!" unless block_given?
        pipeline_registry[name] = block
      end

      private

      def inherited(child)
        child.instance_variable_set(:@pipeline_registry, pipeline_registry.clone)
      end

      def raise_already_registered_error(name)
        raise KeyError, "Already registered a pipeline #{name}. Call pipeline! to overwrite already registered pipelines"
      end

      def pipeline_registry
        @pipeline_registry ||= ActiveSupport::HashWithIndifferentAccess.new
      end
    end

    def self.included(base)
      base.extend(ClassMethods)

      def pipeline(name = :default)
        self.class.pipeline(name)
      end
    end
  end
end

module NxtPipeline
  module Dsl
    module ClassMethods
      def pipeline(name = :default, parent = NxtPipeline::Pipeline, &block)
        name = name.to_sym

        if block_given?
          raise_already_registered_error(name) if pipeline_registry.key?(name)
          register_pipeline(name, block, parent)
        else
          entry = pipeline_registry.fetch(name) { raise KeyError, "No pipeline #{name} registered"}
          config = entry.fetch(:config)
          entry.fetch(:parent).send(:new, &config)
        end
      end

      def pipeline!(name, parent = NxtPipeline::Pipeline, &block)
        raise ArgumentError, "No block given!" unless block_given?
        register_pipeline(name, block, parent)
      end

      private

      def inherited(child)
        child.instance_variable_set(:@pipeline_registry, pipeline_registry.deep_dup)
      end

      def raise_already_registered_error(name)
        raise KeyError, "Already registered a pipeline #{name}. Call pipeline! to overwrite already registered pipelines"
      end

      def pipeline_registry
        @pipeline_registry ||= ActiveSupport::HashWithIndifferentAccess.new
      end

      def register_pipeline(name, block, parent)
        pipeline_registry[name] = { config: block, parent: parent }
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

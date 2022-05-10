require 'active_support/all'
require 'nxt_registry'
require 'nxt_pipeline/version'
require 'nxt_pipeline/logger'
require 'nxt_pipeline/constructor'
require 'nxt_pipeline/pipeline'
require 'nxt_pipeline/step'
require 'nxt_pipeline/callbacks'
require 'nxt_pipeline/error_callback'

module NxtPipeline
  class << self
    delegate :new, :call, to: Pipeline
  end

  def configuration(name, &block)
    @configurations ||= {}

    if block_given?
      raise ArgumentError, "Configuration already defined for #{name}" if @configurations[name].present?
      @configurations[name] = block
    else
      @configurations.fetch(name)
    end
  end

  module_function :configuration
end

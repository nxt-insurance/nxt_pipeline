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

  def configure(name, &block)
    @configurations ||= {}
    raise ArgumentError, "Configuration already defined for #{name}" if @configurations[name].present?

    @configurations[name] = block
  end

  def configuration(name)
    @configurations.fetch(name)
  end

  module_function :configure, :configuration
end

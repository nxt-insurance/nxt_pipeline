RSpec.describe NxtPipeline do
  NxtPipeline.configuration(:test_processor) do |pipeline|
    pipeline.constructor(:processor) do |acc, step|
      step.argument.call(acc)
    end
  end

  subject do
    NxtPipeline.new(configuration: :test_processor) do |p|
      p.step ->(acc) { acc + 'first ' }, constructor: :processor
      p.step ->(acc) { acc + 'second ' }, constructor: :processor
      p.step ->(acc) { acc + 'third' }, constructor: :processor
    end
  end

  it 'configures the pipeline with the configuration' do
    expect(subject.call('')).to eq('first second third')
  end
end
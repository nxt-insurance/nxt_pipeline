RSpec.describe NxtPipeline do
  NxtPipeline.configuration(:test_processor) do |pipeline|
    pipeline.constructor(:processor) do |step, arg:|
      { arg: step.argument.call(step, arg: arg) }
    end
  end

  subject do
    NxtPipeline.new(:test_processor) do |p|
      p.step ->(_, arg:) { arg + 'first ' }, constructor: :processor
      p.step ->(_, arg:) { arg + 'second ' }, constructor: :processor
      p.step ->(_, arg:) { arg + 'third' }, constructor: :processor
    end
  end

  it 'configures the pipeline with the configuration' do
    expect(subject.call(arg: '')).to eq(arg: 'first second third')
  end
end
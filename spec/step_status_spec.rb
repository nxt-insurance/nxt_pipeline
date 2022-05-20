RSpec.describe NxtPipeline do
  subject do
    NxtPipeline::Pipeline.new do |pipeline|
      pipeline.constructor(:step, default: true) do |acc, step|
        step.status = step.proc.call(acc)
        step.meta_data = 'additional info'
        acc
      end

      pipeline.step :first_step do |acc, step|
        step.status = 'it worked'
        step.meta_data = { extra: 'info' }
        acc
      end

      pipeline.step :second, proc: ->(acc) { acc }
    end
  end

  it 'is possible to set the status of a step in the constructor' do
    subject.call('injected')
    expect(subject.logger.log).to eq("first_step" => 'it worked', "second" => 'injected')
    expect(subject.steps.map(&:meta_data)).to eq([{:extra=>"info"}, "additional info"])
  end
end
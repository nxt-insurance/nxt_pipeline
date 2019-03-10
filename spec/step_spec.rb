RSpec.describe NxtPipeline::Step do
  subject do
    Class.new(NxtPipeline::Step[:param_1, :param_2]) do
      def pipe_through
        { param_1: param_1, param_2: param_2 }
      end
    end
  end

  let(:segment_without_pipe_through) do
    Class.new(NxtPipeline::Step[:param])
  end

  it 'should enforce the implementation of #pipe_through' do
    expect { segment_without_pipe_through.new(param: nil).pipe_through }.to raise_error(NotImplementedError)
  end

  it 'should enforce passing arguments to the constructor' do
    expect { Class.new(NxtPipeline::Step[]) }.to raise_error(
      ArgumentError,
      'Arguments missing'
    )
  end

  it 'should enforce passing the required arguments to the constructor' do
    expect { subject.new }.to raise_error(
      ArgumentError,
      'Arguments missing: param_1:, param_2:'
    )

    expect { subject.new(param_1: nil) }.to raise_error(
      ArgumentError,
      'Arguments missing: param_2:'
    )

    expect { subject.new(param_2: nil) }.to raise_error(
      ArgumentError,
      'Arguments missing: param_1:'
    )

    expect { subject.new(param_1: nil, param_2: nil) }.not_to raise_error
  end
end

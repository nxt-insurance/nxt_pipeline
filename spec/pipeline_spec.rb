RSpec.describe NxtPipeline::Pipeline do
  let(:pipe_attr) { %w[Ruby is awesome] }
  
  context 'with reliable segments' do
    let(:uppercase_step) do
      Class.new(NxtPipeline::Step) do
        def pipe_through
          words.map(&:upcase)
        end
      end
    end

    let(:sort_step) do
      Class.new(NxtPipeline::Step) do
        def pipe_through
          words.sort
        end
      end
    end

    subject do
      klass = Class.new(NxtPipeline::Pipeline) do
        pipe_attr :words
      end

      klass.step uppercase_step
      klass.step sort_step

      klass
    end

    it 'pipes the pipe attr through the steps and returns them transformed' do
      expect(subject.new(words: pipe_attr).call).to eq %w[AWESOME IS RUBY]
    end
  end

  context 'with failing steps' do
    class TestError < StandardError; end

    let(:uppercase_step) do
      Class.new(NxtPipeline::Step) do
        def pipe_through
          words.map(&:upcase)
        end
      end
    end

    let(:sort_step) do
      Class.new(NxtPipeline::Step) do
        def pipe_through
          words.sort
        end
      end
    end

    let(:failing_step) do
      class FailingStep < NxtPipeline::Step
        def pipe_through
          raise TestError, 'This step has failed!'
        end
      end

      FailingStep
    end

    context 'without rescuing for step errors' do
      subject do
        klass = Class.new(NxtPipeline::Pipeline) do
          pipe_attr :words
        end

        klass.step uppercase_step
        klass.step failing_step
        klass.step sort_step

        klass
      end

      it 'raises an error and remembers which step error' do
        expect { subject.new(words: pipe_attr).call }.to raise_error(
          TestError,
          'This step has failed!'
        )
      end

      it 'remembers the step that failed' do
        pipeline = subject.new(words: pipe_attr)
        pipeline.call rescue TestError

        expect(pipeline.failed_step).to eq 'failing_step'
        expect(pipeline.failed?).to be_truthy
      end
    end

    context 'when rescuing for step errors' do
      subject do
        klass = Class.new(NxtPipeline::Pipeline) do
          pipe_attr :words
        end

        klass.step uppercase_step
        klass.step failing_step
        klass.step sort_step

        klass.rescue_errors TestError do |error, failed_step|
          puts "Failed in step #{failed_step} with #{error.class}: #{error.message}"
        end

        klass
      end

      it 'should call the block defined for step error rescues' do
        expect { subject.new(words: pipe_attr).call }.to raise_error(
          TestError,
          'This step has failed!'
        ).and output("Failed in step failing_step with TestError: This step has failed!\n").to_stdout
      end
    end
  end
  
  context 'callbacks' do
    let(:empty_step) do
      Class.new(NxtPipeline::Step) do
        def pipe_through
          words
        end
      end
    end
        
    subject do
      klass = Class.new(NxtPipeline::Pipeline) do
        pipe_attr :words
        
        def history
          @history ||= []
        end
      end

      klass.step empty_step
      
      klass.before_each_step do |pipeline|
        pipeline.history << 'Pipeline ran before_each_step callback'
      end
      
      klass.after_each_step do |pipeline|
        pipeline.history << 'Pipeline ran after_each_step callback'
      end
      
      klass.around_each_step do |pipeline, block|
        pipeline.history << 'Pipeline ran around_each_step callback start'
        block.call
        pipeline.history << 'Pipeline ran around_each_step callback end'
      end

      klass
    end
    
    it 'should execute the callbacks in the correct order' do
      pipeline = subject.new(words: pipe_attr)
      pipeline.call
      
      expect(pipeline.history).to eq [
        'Pipeline ran before_each_step callback',
        'Pipeline ran around_each_step callback start',
        'Pipeline ran around_each_step callback end',
        'Pipeline ran after_each_step callback',
      ]
    end
  end
end

RSpec.describe NxtPipeline::Pipeline do

  let(:pipeline) do
    NxtPipeline::Pipeline.new do |pipeline|
      pipeline.step to_s: '1' do |_, change_set|
        change_set[:acc] << 'step 1'
        change_set
      end

      pipeline.step to_s: '2' do |_, change_set|
        change_set[:acc] << 'step 2'
        change_set
      end

      pipeline.step to_s: '3' do |_, change_set|
        change_set[:acc] << 'step 3'
        change_set
      end
    end
  end

  subject { pipeline.execute(change_set)[:acc] }

  context 'execution' do
    let(:change_set) { { acc: [] } }

    context 'before execution' do
      before do
        pipeline.configure do |pipeline|
          pipeline.before_execution do |_, change_set|
            change_set[:acc] << 'before execution 1'
            change_set
          end

          pipeline.before_execution do |_, change_set|
            change_set[:acc] << 'before execution 2'
            change_set
          end

          pipeline.before_execution do |_, change_set|
            change_set[:acc] << 'before execution 3'
            change_set
          end
        end
      end

      it 'executes the callbacks in order' do
        expect(subject).to eq([
          "before execution 1",
          "before execution 2",
          "before execution 3",
          "step 1",
          "step 2",
          "step 3"
        ])
      end
    end

    context 'around execution' do
      before do
        pipeline.configure do |pipeline|
          pipeline.around_execution do |_, change_set, execution|
            change_set[:acc] << 'around execution 1'
            execution.call
            change_set[:acc] << 'around execution 1'
            change_set
          end

          pipeline.around_execution do |_, change_set, execution|
            change_set[:acc] << 'around execution 2'
            execution.call
            change_set[:acc] << 'around execution 2'
            change_set
          end

          pipeline.around_execution do |_, change_set, execution|
            change_set[:acc] << 'around execution 3'
            execution.call
            change_set[:acc] << 'around execution 3'
            change_set
          end
        end
      end

      it 'executes the callbacks in order' do
        expect(subject).to eq([
          "around execution 1",
          "around execution 2",
          "around execution 3",
          "step 1",
          "step 2",
          "step 3",
          "around execution 3",
          "around execution 2",
          "around execution 1"
        ])
      end
    end

    context 'after execution' do
      before do
        pipeline.configure do |pipeline|
          pipeline.after_execution do |_, change_set|
            change_set[:acc] << 'after execution 1'
          end

          pipeline.after_execution do |_, change_set|
            change_set[:acc] << 'after execution 2'
          end

          pipeline.after_execution do |_, change_set|
            change_set[:acc] << 'after execution 3'
          end
        end
      end

      it 'executes the callbacks in order' do
        expect(subject).to eq([
          "step 1",
          "step 2",
          "step 3",
          "after execution 1",
          "after execution 2",
          "after execution 3"
        ])
      end
    end
  end

  context 'step' do
    context 'before execution' do

    end

    context 'around execution' do

    end

    context 'after execution' do

    end
  end

  context 'order' do

  end
end

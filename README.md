[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

The idea of nxt_pipeline is to provide the functionality to reduce over service objects and callables in general. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_pipeline'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nxt_pipeline

## Usage

### Constructors

In order to reduce over your service objects you have to define constructors so that the pipeline knows how to execute
each step. Consider the following pipelines that processes an array of strings, 

```ruby
class Upcaser
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.map(&:upcase)
  end
end

class Stripper
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.map(&:strip)
  end
end

class Compacter
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.reject(&:blank?)
  end
end

subject do
  NxtPipeline::Pipeline.new do |p|
    p.constructor(:service, default: true) do |step, arg:|
      result = step.argument.new(arg).call
      result && { arg: result }
    end

    p.step Compacter
    p.step Stripper
    p.step Upcaser
  end
end

# In case your service objects already implement call there is no need to define constructors as long as they 
# all use the same input arguments
class Service
  def self.call(*args)
    new(*args).call
  end
end

# Once a pipeline was created you can still configure it
pipeline.constructor(:call) do |step, arg:|
  result = step.caller.new(arg).call
  result && { arg: result }
end

# same with block syntax
# You can use this to split up execution from configuration
pipeline.configure do |p|
 p.constructor(:call) do |step, arg:|
   result = step.caller.new(arg).call
   result && { arg: result }
 end
end
```

### Defining steps

Once your pipeline knows how to execute your steps you can add those.

```ruby
pipeline.step :service, service_class: MyServiceClass, to_s: 'First step'
pipeline.step service_class: MyOtherServiceClass, to_s: 'Second step'
# ^ Since service is the default step you don't have to specify it the step type each time
pipeline.step :job, job_class: MyJobClass # to_s is optional
pipeline.step :job, job_class: MyOtherJobClass

pipeline.step :step_name_for_better_log do |_, arg:|
  # ...
end

pipeline.step to_s: 'This is the same as above' do |step, arg:|
  # ... step.to_s => 'This is the same as above'
end
```

You can also define inline steps, meaning the block will be executed. When you do not provide a :to_s option, type
will be used as :to_s option per default. When no type was given for an inline block the type of the inline block
will be set to :inline.

### Execution

You can then execute the steps with:

```ruby
pipeline.execute(arg: 'initial argument')

# Or run the steps directly using block syntax

pipeline.execute(arg: 'initial argument') do |p|
  p.step :service, service_class: MyServiceClass, to_s: 'First step'
  p.step :service, service_class: MyOtherServiceClass, to_s: 'Second step'
  p.step :job, job_class: MyJobClass # to_s is optional
  p.step :job, job_class: MyOtherJobClass
end

```

You can also directly execute a pipeline with:

```ruby
NxtPipeline::Pipeline.execute(arg: 'initial argument') do |p|
  p.step do |_, arg:|
    { arg: arg.upcase }
  end
end
```

You can query the steps of your pipeline simply by calling `pipeline.steps`. A NxtPipeline::Step will provide you with
an interface to it's type, options, status (:success, :skipped, :failed), execution_finished_at execution_started_at, execution_duration, result, error and the index in the pipeline.

```
pipeline.steps.first
# will give you something like this:

#<NxtPipeline::Step:0x00007f83eb399448
 @constructor=
  #<Proc:0x00007f83eb399498@/Users/andy/workspace/nxt_pipeline/spec/pipeline_spec.rb:467>,
 @error=nil,
 @index=0,
 @opts={:to_s=>:transformer, :method=>:upcase},
 @result=nil,
 @status=nil,
 @type=:transformer
 @execution_duration=1.0e-05,
 @execution_finished_at=2020-10-22 15:52:55.806417 +0100,
 @execution_started_at=2020-10-22 15:52:55.806407 +0100,>
```

### Guard clauses

You can also define guard clauses that take a proc to prevent the execution of a step.
When the guard takes an argument the step argument is yielded.

 ```ruby
 pipeline.execute(arg: 'initial argument') do |p|
   p.step :service, service_class: MyServiceClass, if: -> (arg:) { arg == 'initial argument' }
   p.step :service, service_class: MyOtherServiceClass, unless: -> { false }
 end

 ```

### Error callbacks

Apart from defining constructors and steps you can also define error callbacks.

```ruby
NxtPipeline::Pipeline.new do |p|
  p.step do |_, arg:|
    { arg: arg.upcase }
  end

  p.on_error MyCustomError do |step, opts, error|
    # First matching error callback will be executed!
  end

  p.on_errors ArgumentError, KeyError do |step, opts, error|
    # First matching error callback will be executed!
  end

  p.on_errors YetAnotherError, halt_on_error: false do |step, opts, error|
    # After executing the callback the pipeline will not halt but continue to
    # execute the next steps.
  end

  p.on_errors do |step, opts, error|
    # This will match all errors inheriting from StandardError
  end
end
```

### Before, around and after callbacks

You can also define callbacks :before, :around and :after each step and or the `#execute` method. You can also register
multiple callbacks, but probably you want to keep them to a minimum to not end up in hell.

#### Step callbacks

```ruby
NxtPipeline::Pipeline.new do |p|
  p.before_step do |_, change_set|
    change_set[:acc] << 'before step 1'
    change_set
  end

  p.around_step do |_, change_set, execution|
    change_set[:acc] << 'around step 1'
    execution.call # you have to specify where in your callback you want to call the inner block
    change_set[:acc] << 'around step 1'
    change_set
  end

  p.after_step do |_, change_set|
    change_set[:acc] << 'after step 1'
    change_set
  end
end
```

#### Execution callbacks

```ruby
NxtPipeline::Pipeline.new do |p|
  p.before_execution do |_, change_set|
    change_set[:acc] << 'before execution 1'
    change_set
  end

  p.around_execution do |_, change_set, execution|
    change_set[:acc] << 'around execution 1'
    execution.call # you have to specify where in your callback you want to call the inner block
    change_set[:acc] << 'around execution 1'
    change_set
  end

  p.after_execution do |_, change_set|
    change_set[:acc] << 'after execution 1'
    change_set
  end
end
```

Note that the `after_execute` callback will not be called in case a step raises an error. 
See the previous section (_Error callbacks_) for how to define callbacks that run in case of errors.

### Step resolvers

NxtPipeline is using so called constructor_resolvers to find the constructor for a given step by the arguments passed in.
You can also use this if you are not fine with resolving the constructor from the step argument. Check out the
`nxt_pipeline/spec/constructor_resolver_spec.rb` for examples how you can implement your own constructor_resolvers.


## Topics
- Constructors should take arg as first and step as second arg

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

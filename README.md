[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

nxt_pipeline provides a DSL to define pipeline classes which take an object and pass it through multiple steps which can read or modify the object.

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

First you probably want to configure a pipeline so that it can execute your steps. 
Therefore you want to define constructors for your steps. Constructors take a name 
as the first argument and step options as the second. All step options are being exposed
by the step yielded to the constructor. 

```ruby
pipeline = NxtPipeline::Pipeline.new do |p|
  # Add a named constructor that will be used to execute your steps later
  # All options that you pass in your step will be available through accessors in your constructor 
  p.constructor(:service, default: true) do |step, arg|
    step.service_class.new(options: arg).call
  end
  
  p.constructor(:job) do |step, arg|
    step.job_class.perform_later(*arg) && arg
  end
end

# Once a pipeline was created you can still configure it 
pipeline.constructor(:call) do |step, arg|
  step.caller.new(arg).call
end

# same with block syntax 
# You can use this to split up execution from configuration  
pipeline.configure do |p|
 p.constructor(:call) do |step, arg|
   step.caller.new(arg).call
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

pipeline.step :step_name_for_better_log do |_, arg|
  # ...
end

pipeline.step to_s: 'This is the same as above' do |step, arg|
  # ... step.to_s => 'This is the same as above'
end
```

You can also define inline steps, meaning the block will be executed

### Execution

You can then execute the steps with: 

```ruby
pipeline.execute('initial argument')

# Or run the steps directly using block syntax

pipeline.execute do |p|
  p.step :service, service_class: MyServiceClass, to_s: 'First step'
  p.step :service, service_class: MyOtherServiceClass, to_s: 'Second step'
  p.step :job, job_class: MyJobClass # to_s is optional
  p.step :job, job_class: MyOtherJobClass
end

```

You can also directly execute a pipeline with:

```ruby
NxtPipeline::Pipeline.execute('initial argument') do |p|
  p.step do |_, arg|
    arg.upcase
  end
end
``` 

### Error callbacks

Apart from defining constructors and steps you can also define error callbacks.

```ruby
NxtPipeline::Pipeline.new do |p|
  p.step do |_, arg|
    arg.upcase
  end
  
  p.on_error MyCustomError do |step, arg, error|
    # First matching error callback will be executed!
  end
  
  p.on_errors ArgumentError, KeyError do |step, arg, error|
    # First matching error callback will be executed!
  end
  
  p.on_errors do |step, arg, error|
    # This will match all errors inheriting from StandardError
  end
end
``` 

### Before and After callbacks

You can also define callbacks that run before and after the `#execute` action. Both callback blocks get the pipeline instance (to access stuff like the `log`) and the argument of the pipeline yielded.

```ruby
NxtPipeline::Pipeline.new do |p|
  p.before_execute do |pipeline, arg|
    # Will be called from within #execute before entering the first step
  end
  
  p.after_execute do |pipeline, arg|
    # Will be called from within #execute after executing last step
  end
end
```

Note that the `after_execute` callback will not be called, when an error is raised in one of the steps. See the previous section (_Error callbacks_) for how to define callbacks that run in case of errors. 


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

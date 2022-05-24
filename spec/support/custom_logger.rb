class CustomLogger
  def call(step)
    log << step.to_s
  end

  def log
    @log ||= []
  end
end
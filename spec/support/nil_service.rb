class NilService
  def self.call
    new.call
  end

  def call
    nil
  end
end
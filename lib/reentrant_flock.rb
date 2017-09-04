require "reentrant_flock/version"

class ReentrantFlock
  attr_reader :fp

  def initialize(fp)
    @fp = fp
    Thread.current[:reentrant_flock_count] = 0
  end

  def synchronize(operation)
    raise 'Must be called with a block' unless block_given?

    begin
      lock(operation)
      yield
    ensure
      unlock
    end
  end

  # File::LOCK_EX
  #   if obtained a lock, return 0
  #   otherwise, blocked
  #
  # File::LOCK_EX | File::LOCK_NB
  #   if obtained a lock, return 0
  #   otherwise, return false
  def lock(operation)
    c = incr
    if c <= 1
      fp.flock(operation)
    else
      (operation & File::LOCK_NB) > 0 ? false : 0
    end
  end

  def unlock
    c = decr
    if c <= 0
      fp.flock(File::LOCK_UN)
      del
    end
  end

  def locked?
    Thread.current[:reentrant_flock_count] ?
      Thread.current[:reentrant_flock_count] >= 1 : false
  end

  private

  def incr
    Thread.current[:reentrant_flock_count] ||= 0
    Thread.current[:reentrant_flock_count] += 1
  end

  def decr
    Thread.current[:reentrant_flock_count] -= 1
  end

  def del
    Thread.current[:reentrant_flock_count] = nil
  end
end

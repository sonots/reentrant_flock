require "test_helper"

class ReentrantFlockTest < Test::Unit::TestCase
  def open(&block)
    File.open(File.join(TEST_TMP_DIR, 'lock'), File::RDWR | File::CREAT, &block)
  end

  sub_test_case '#synchronize' do
    test 'raise an error when no block is given' do
      open do |fp|
        assert_raise { ReentrantFlock.synchronize(fp, File::LOCK_EX) }
        assert_raise { ReentrantFlock.synchronize(fp, File::LOCK_EX | File::LOCK_NB) }
      end
    end

    test 'should not block when called twice' do
      assert_nothing_raised do
        open do |fp|
          ReentrantFlock.synchronize(fp, File::LOCK_EX) do
            open do |fp|
              ReentrantFlock.synchronize(fp, File::LOCK_EX) do
              end
            end
          end
        end
      end
    end

    test 'return whatever the block returns' do
      open do |fp|
        assert { ReentrantFlock.synchronize(fp, File::LOCK_EX) { 42 } == 42 }
      end
    end

    test 'should leave unlocked' do
      open do |fp|
        ReentrantFlock.synchronize(fp, File::LOCK_EX) {}
        assert { ReentrantFlock.self_locked?(fp) == false }
      end
    end

    test 'should be locked in the block' do
      open do |fp|
        ReentrantFlock.synchronize(fp, File::LOCK_EX) do
          assert { ReentrantFlock.self_locked?(fp) == true }
        end
      end
    end

    test 'nonblock should raise AlreadyLocked when called in another thread' do
      assert_raise(ReentrantFlock::AlreadyLocked) do
        th = Thread.new do
          open do |fp|
            ReentrantFlock.synchronize(fp, File::LOCK_EX | File::LOCK_NB) do
              sleep 0.5
            end
          end
        end
        sleep 0.1
        open do |fp|
          ReentrantFlock.synchronize(fp, File::LOCK_EX | File::LOCK_NB) do
            sleep 0.5
          end
        end
        th.join
      end
    end
  end

  sub_test_case '#lock' do
    test 'should not deadlock when called twice' do
      open do |fp|
        ReentrantFlock.flock(fp, File::LOCK_EX)
        open do |fp|
          assert_nothing_raised { ReentrantFlock.flock(fp, File::LOCK_EX) }
          ReentrantFlock.flock(fp, File::LOCK_UN)
        end
        ReentrantFlock.flock(fp, File::LOCK_UN)
      end
    end

    test 'reentrant lock' do
      open do |fp|
        assert { ReentrantFlock.flock(fp, File::LOCK_EX) == 0 }
        open do |fp|
          assert { ReentrantFlock.flock(fp, File::LOCK_EX) == 0 }
          assert { ReentrantFlock.self_locked?(fp) == true }
          ReentrantFlock.flock(fp, File::LOCK_UN)
        end
        ReentrantFlock.flock(fp, File::LOCK_UN)
      end
    end

    test 'reentrant nonblock lock' do
      open do |fp|
        assert { ReentrantFlock.flock(fp, File::LOCK_EX | File::LOCK_NB) == 0 }
        open do |fp|
          assert { ReentrantFlock.flock(fp, File::LOCK_EX | File::LOCK_NB) == 0 }
          assert { ReentrantFlock.self_locked?(fp) == true }
          ReentrantFlock.flock(fp, File::LOCK_UN)
        end
        ReentrantFlock.flock(fp, File::LOCK_UN)
      end
    end

    test 'nonblock lock should return false when called in another thread' do
      th = Thread.new do
        open do |fp|
          assert { ReentrantFlock.flock(fp, File::LOCK_EX | File::LOCK_NB) == 0 }
          sleep 0.5
          ReentrantFlock.flock(fp, File::LOCK_UN)
        end
      end
      sleep 0.1
      open do |fp|
        assert { ReentrantFlock.flock(fp, File::LOCK_EX | File::LOCK_NB) == false }
        ReentrantFlock.flock(fp, File::LOCK_UN)
      end
      th.join
    end
  end

  sub_test_case '#unlock' do
    test 'should not raise an error when called without a lock' do
      open do |fp|
        assert_nothing_raised { ReentrantFlock.flock(fp, File::LOCK_UN) }
      end
    end

    test 'should not raise an error when locked multiple times' do
      open do |fp|
        ReentrantFlock.flock(fp, File::LOCK_EX)
        open do |fp|
          ReentrantFlock.flock(fp, File::LOCK_EX)
          assert_nothing_raised { ReentrantFlock.flock(fp, File::LOCK_UN) }
        end
        assert_nothing_raised { ReentrantFlock.flock(fp, File::LOCK_UN) }
      end
    end

    test 'unlock' do
      open do |fp|
        ReentrantFlock.flock(fp, File::LOCK_EX)
        ReentrantFlock.flock(fp, File::LOCK_UN)
        assert { ReentrantFlock.self_locked?(fp) == false }
      end
    end
  end
end

class ReentrantFlockInstanceMethodTest < Test::Unit::TestCase
  # ToDo: call fp.flock(LOCK_EX) twice for the same fp object does not lock the file again
  # So, some of test may be meaningless below

  def setup
    @fp = File.open(File.join(TEST_TMP_DIR, 'lock'), File::RDWR | File::CREAT)
    @rflock = ReentrantFlock.new(@fp)
  end

  def teardown
    @fp.close
  end

  def open(&block)
    File.open(File.join(TEST_TMP_DIR, 'lock'), File::RDWR | File::CREAT, &block)
  end

  sub_test_case '#synchronize' do
    test 'raise an error when no block is given' do
      assert_raise { @rflock.synchronize(File::LOCK_EX) }
      assert_raise { @rflock.synchronize(File::LOCK_EX | File::LOCK_NB) }
    end

    test 'should not block when called twice' do
      assert_nothing_raised do
        @rflock.synchronize(File::LOCK_EX) do
          @rflock.synchronize(File::LOCK_EX) do
          end
        end
      end
    end

    test 'return whatever the block returns' do
      assert { @rflock.synchronize(File::LOCK_EX) { 42 } == 42 }
    end

    test 'should leave unlocked' do
      @rflock.synchronize(File::LOCK_EX) {}
      assert { @rflock.self_locked? == false }
    end

    test 'should be locked in the block' do
      @rflock.synchronize(File::LOCK_EX) do
        assert { @rflock.self_locked? == true }
      end
    end

    test 'nonblock should raise AlreadyLocked when called in another thread' do
      assert_raise(ReentrantFlock::AlreadyLocked) do
        th = Thread.new do
          open do |fp|
            rflock = ReentrantFlock.new(fp)
            rflock.synchronize(File::LOCK_EX | File::LOCK_NB) do
              sleep 0.5
            end
          end
        end
        sleep 0.1
        open do |fp|
          rflock = ReentrantFlock.new(fp)
          rflock.synchronize(File::LOCK_EX | File::LOCK_NB) do
            sleep 0.5
          end
        end
        th.join
      end
    end
  end

  sub_test_case '#lock' do
    test 'should not deadlock when called twice' do
      @rflock.flock(File::LOCK_EX)
      assert_nothing_raised { @rflock.flock(File::LOCK_EX) }
    end

    test 'lock' do
      assert { @rflock.flock(File::LOCK_EX) == 0 }
      assert { @rflock.flock(File::LOCK_EX) == 0 }
      assert { @rflock.self_locked? == true }
    end

    test 'nonblock lock' do
      assert { @rflock.flock(File::LOCK_EX | File::LOCK_NB) == 0 }
      assert { @rflock.flock(File::LOCK_EX | File::LOCK_NB) == 0 }
      assert { @rflock.self_locked? == true }
    end

    test 'nonblock lock should return false when called in another thread' do
      th = Thread.new do
        open do |fp|
          rflock = ReentrantFlock.new(fp)
          assert { rflock.flock(File::LOCK_EX | File::LOCK_NB) == 0 }
          sleep 0.5
          rflock.flock(File::LOCK_UN)
        end
      end
      sleep 0.1
      open do |fp|
        rflock = ReentrantFlock.new(fp)
        assert { rflock.flock(File::LOCK_EX | File::LOCK_NB) == false }
        rflock.flock(File::LOCK_UN)
      end
      th.join
    end
  end

  sub_test_case '#unlock' do
    test 'should not raise an error when called without a lock' do
      assert_nothing_raised { @rflock.flock(File::LOCK_UN) }
    end

    test 'should not raise an error when locked multiple times' do
      @rflock.flock(File::LOCK_EX)
      @rflock.flock(File::LOCK_EX)
      assert_nothing_raised { @rflock.flock(File::LOCK_UN) }
      assert_nothing_raised { @rflock.flock(File::LOCK_UN) }
    end

    test 'unlock' do
      @rflock.flock(File::LOCK_EX)
      @rflock.flock(File::LOCK_UN)
      assert { @rflock.self_locked? == false }
    end
  end
end

require "test_helper"

class ReentrantFlockTest < Test::Unit::TestCase
  def setup
    @fp = File.open(File.join(TEST_TMP_DIR, 'lock'), File::RDWR | File::CREAT)
    @rflock = ReentrantFlock.new(@fp)
  end

  def teardown
    @fp.close
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
      assert { @rflock.locked? == false }
    end

    test 'should be locked in the block' do
      @rflock.synchronize(File::LOCK_EX) do
        assert { @rflock.locked? == true }
      end
    end
  end

  sub_test_case '#lock' do
    test 'should not deadlock when called twice' do
      @rflock.lock(File::LOCK_EX)
      assert_nothing_raised { @rflock.lock(File::LOCK_EX) }
    end

    test 'lock' do
      assert { @rflock.lock(File::LOCK_EX) == 0 }
      assert { @rflock.lock(File::LOCK_EX) == 0 }
      assert { @rflock.locked? == true }
    end

    test 'nonblock lock' do
      assert { @rflock.lock(File::LOCK_EX | File::LOCK_NB) == 0 }
      assert { @rflock.lock(File::LOCK_EX | File::LOCK_NB) == false }
      assert { @rflock.locked? == true }
    end
  end

  sub_test_case '#unlock' do
    test 'should not raise an error when called without a lock' do
      assert_nothing_raised { @rflock.unlock }
    end

    test 'should not raise an error when locked multiple times' do
      @rflock.lock(File::LOCK_EX)
      @rflock.lock(File::LOCK_EX)
      assert_nothing_raised { @rflock.unlock }
      assert_nothing_raised { @rflock.unlock }
    end

    test 'unlock' do
      @rflock.lock(File::LOCK_EX)
      @rflock.unlock
      assert { @rflock.locked? == false }
    end
  end
end

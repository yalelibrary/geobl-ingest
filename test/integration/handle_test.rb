require 'test_helper'
require 'handle_methods'
#docker-compose run web rails test test/integration/handle_test.rb
class HandleTest < ActiveSupport::TestCase
  test "the truth" do
    assert true
  end
  test "handle generation" do
    HandleMethods.save_handles("test")
    assert_equal("pass","pass")
  end
  #batch rake task for saving handle, use real

end
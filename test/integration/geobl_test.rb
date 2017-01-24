require 'test_helper'
require 'geobl_methods'
#docker-compose run web rails test test/integration/geobl_test.rb
class GeoblTest < ActiveSupport::TestCase
  test "the truth" do
    assert true
  end
  #commenting out, this will pick up the RAILS_ENV=test db, which we don't want
  #test "ladybird metadata" do
  #  GeoblMethods.process_simple(1)
  #  assert_equal("pass","pass")
  #end

end
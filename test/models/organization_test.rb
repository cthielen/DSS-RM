require 'test_helper'

class OrganizationTest < ActiveSupport::TestCase
  setup do
    CASClient::Frameworks::Rails::Filter.fake("casuser")
  end
  
  test "organization cannot be its own parent" do
    o = organizations(:toplevel)
    
    assert o.valid?, "organization fixture should be valid"
    
    record_invalid_exception = false
    
    begin
    o.parent_organizations << o
    rescue ActiveRecord::RecordInvalid
    # We were expecting this ...
    record_invalid_exception = true
    end
    
    assert record_invalid_exception, "exception should have been thrown by OrganizationParentId to indicate an organization cannot relate to itself"
    assert o.valid? == false, "organization should not be valid due to being its own parent"
  end
  
  test "organization cannot be its own child" do
    o = organizations(:toplevel)
    
    assert o.valid?, "organization fixture should be valid"
    
    record_invalid_exception = false
    
    begin
    o.child_organizations << o
    rescue ActiveRecord::RecordInvalid
    # We were expecting this ...
    record_invalid_exception = true
    end
    
    assert record_invalid_exception, "exception should have been thrown by OrganizationParentId to indicate an organization cannot relate to itself"
    assert o.valid? == false, "organization should not be valid due to being its own parent"
  end
  
  # Test for an invalid loop commonly found in the data
  test "organization cannot be a parent of its parent" do
    o = organizations(:office_of_toplevel)
    o_parent = organizations(:toplevel)
    
    assert o.valid?, "organization fixture should be valid"
    assert o_parent.valid?, "organization fixture should be valid"
    assert o.parent_organizations.include?(o_parent), "organization fixture should indicate this parent"
    
    begin
    o_parent.parent_organizations << o
    rescue ActiveRecord::RecordInvalid
    # This should happen
    end
    
    assert o_parent.valid? == false, "organization should not allow a child as a parent"
  end
end

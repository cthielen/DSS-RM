# Represents the results of calculating GroupRule with ID group_rule_id
# Used as a cache for quickly recalculating groups when not every rule
# has changed.
class GroupRuleResult < ApplicationRecord
  belongs_to :group_rule_set
  belongs_to :entity

  validates_presence_of :entity_id, :group_rule_set_id
end

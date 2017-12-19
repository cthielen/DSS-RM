@EntityTypes =
  unknown : 0
  person  : 1
  group   : 2

# Nested attributes for people are BB collections while groups used
# vanilla attributes. The former is easier to use but requires you stick
# to a strict pattern. This difference should probably be reconciled.
DssRm.Models.Entity = Backbone.Model.extend(
  url: ->
    id = (@get('group_id') || @get('id'))
    if id
      "/entities/#{id}"
    else
      "/entities"

  initialize: ->
    @resetNestedCollections()
    @on "sync", @resetNestedCollections, this

  resetNestedCollections: ->
    @set 'entity_id', @get('group_id') || @get('id') unless @get('entity_id')

    if @type() is EntityTypes.group
      @owners = new DssRm.Collections.Entities if @owners is `undefined`
      @operators = new DssRm.Collections.Entities if @operators is `undefined`
      @memberships = new DssRm.Collections.Entities if @memberships is `undefined`
      @rule_members = new DssRm.Collections.Entities if @rule_members is `undefined`
      @rules = new DssRm.Collections.GroupRules if @rules is `undefined`

      # Reset nested collection data
      @owners.reset @get("owners")
      @operators.reset @get("operators")
      @memberships.reset @get("memberships")
      @rule_members.reset @get("rule_members")
      @rules.reset @get("rules")

    else if @type() is EntityTypes.person
      # Ensure nested collections exist
      @favorites = new DssRm.Collections.Entities if @favorites is `undefined`
      @group_ownerships = new DssRm.Collections.Entities if @group_ownerships is `undefined`
      @group_operatorships = new DssRm.Collections.Entities if @group_operatorships is `undefined`
      @group_memberships = new Backbone.Collection if @group_memberships is `undefined`
      @role_assignments = new DssRm.Collections.RoleAssignments if @role_assignments is `undefined`
      @organizations = new Backbone.Collection if @organizations is `undefined`

      # Reset nested collection data
      @favorites.reset @get("favorites")
      @group_ownerships.reset @get("group_ownerships")
      @group_operatorships.reset @get("group_operatorships")
      @group_memberships.reset @get("group_memberships")
      @role_assignments.reset @get("role_assignments")
      @organizations.reset @get("organizations")

  toJSON: ->
    if @type() is EntityTypes.group
      json = {}
      # Group-specific JSON
      json.name = @get("name")
      json.type = "Group"
      json.description = @get("description")
      json.owner_ids = @owners.map (owner) -> owner.id
      json.operator_ids = @operators.map (operator) -> operator.id

      # Note: We use Rails' nested attributes here
      json.memberships_attributes = @memberships.map (membership) ->
        id: membership.get('id')
        entity_id: membership.get('entity_id')
        _destroy: membership.get('_destroy')
      if @rules.length
        json.rules_attributes = @rules.map (rule) ->
          id: parseInt(rule.get('id'))
          column: rule.get('column')
          condition: rule.get('condition')
          value: rule.get('value')
          _destroy: rule.get('_destroy')

    else if @type() is EntityTypes.person
      json = {}

      # Person-specific JSON
      json.type = "Person"

      json.first = @get("first")
      json.last = @get("last")
      json.address = @get("address")
      json.email = @get("email")
      json.loginid = @get("loginid")
      json.phone = @get("phone")
      json.active = @get("active")

      json.favorite_ids = @favorites.map (favorite) -> favorite.id
      if @group_memberships.length
        json.group_memberships_attributes = @group_memberships.map (membership) ->
          id: membership.get('id')
          calculated: membership.get('calculated')
          entity_id: membership.get('entity_id')
          group_id: membership.get('group_id')
          _destroy: membership.get('_destroy')
      if @group_operatorships.length
        json.group_operatorships_attributes = @group_operatorships.map (operatorship) =>
          id: operatorship.get('id')
          entity_id: @get('id') #operatorship.get('entity_id')
          group_id: operatorship.get('group_id')
          _destroy: operatorship.get('_destroy')
      if @group_ownerships.length
        json.group_ownerships_attributes = @group_ownerships.map (ownership) =>
          id: ownership.get('id')
          entity_id: @get('id') #ownership.get('entity_id')
          group_id: ownership.get('group_id')
          _destroy: ownership.get('_destroy')
      explicit_role_assignments = @role_assignments.filter (role_assignment) ->
        role_assignment.get('calculated') == false
      if explicit_role_assignments.length
        json.role_assignments_attributes = explicit_role_assignments.map (assignment) ->
          id: assignment.get('id')
          role_id: assignment.get('role_id')
          entity_id: assignment.get('entity_id')
          _destroy: assignment.get('_destroy')

    entity: json

  type: ->
    if @get('type')
      result = @get('type').toLowerCase()
    else if @get('group_id')
      result = 'group'

    if result == "person"
      return EntityTypes.person
    else if result == "group"
      return EntityTypes.group

    return EntityTypes.unknown

  # Returns only the "highest" relationship (this order): admin, owner, operator
  # Does not return anything if not admin, owner, or operator on purpose
  # Uses DssRm.current_user as the entity
  # Only applicable to entities of type 'Group', not 'Person'
  relationship: ->
    return 'admin' if DssRm.admin_logged_in()

    if @type() is EntityTypes.group
      current_user_id = DssRm.current_user.get('id')
      return 'owner' if @owners.find( (o) ->
        o.id is current_user_id
      ) isnt `undefined`
      return 'operator' if @operators.find( (o) ->
        o.id is current_user_id
      ) isnt `undefined`

  # Returns true if DssRm.current_user cannot modify this entity
  isReadOnly: ->
    if @relationship() is 'admin' or @relationship() is 'owner' then return false
    true

  # Returns only explicit group memberships (valid only for Person entity, not Group)
  uncalculatedGroupMemberships: ->
    if @type() != EntityTypes.person
      return []

    @group_memberships.filter( (group) ->
      group.get('calculated') == false
    )

  # Returns only calculated group memberships (valid only for Person entity, not Group)
  calculatedGroupMemberships: ->
    if @type() != EntityTypes.person
      return []

    @group_memberships.filter( (group) ->
      group.get('calculated') == true
    )
)

DssRm.Collections.Entities = Backbone.Collection.extend(
  model: DssRm.Models.Entity
  url: "/entities"

  # Two orders of sorting:
  # Calculated entities always come first, then groups
  # So a calculated person (12) comes _before_ a non-calculated group (21),
  # but a calculated group (11) comes before everything. See *_order below.
  comparator: (entity) ->
    calculated_order = (if entity.get('calculated') then '1' else '2')
    if entity.type == undefined
      type_order = (if (entity.get('type') == 'Group') then '1' else '2')
    else
      type_order = (if entity.type() is EntityTypes.group then '1' else '2')

    return calculated_order + type_order + entity.get("name")
)

DssRm.Collections.Owners = Backbone.Collection.extend(model: DssRm.Models.Entity)

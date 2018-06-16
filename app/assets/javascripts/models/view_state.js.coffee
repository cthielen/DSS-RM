DssRm.Models.ViewState = Backbone.Model.extend(
  # 'focus' refers to the search bar
  # 'selected' refers to the highlighting used when a user selects a role
  defaults:
    "selected_application_id" : null
    "selected_role_id"        : null
    "focused_application_id"  : null
    "focused_entity_id"       : null

  initialize: ->
    @bookmarks = new DssRm.Collections.Entities()

    @buildBookmarks()

    # Adjust @bookmarks as needed
    # "sync" allows DssRm.current_user.fetch() to cause a bookmark update (e.g. if a favorited group has a name change)
    DssRm.current_user.on "sync", @buildBookmarks, this
    DssRm.current_user.favorites.on "add remove", @buildBookmarks, this
    DssRm.current_user.group_ownerships.on "add", @buildBookmarks, this
    DssRm.current_user.group_operatorships.on "add", @buildBookmarks, this

    # This little hack is required due to BBJS having no callback on .save() that fires after all other events
    # This hack lets us use .on() for the selected_role even though it may change unexpected.
    # When it does change, we call .off() so we are only tracking one role at a time.
    # This is required for the sidebar to re-render after Role.save() calls 'sync'.
    @old_selected_role = null
    @on 'change:selected_role_id', =>
      @old_selected_role.off('sync', @triggerChangeOnSelectedRoleSync, this) if @old_selected_role
      @old_selected_role = @getSelectedRole()
      @old_selected_role.on('sync', @triggerChangeOnSelectedRoleSync, this) if @old_selected_role

  # We need this to be a proper function so our .off() statement above
  # can turn off _just_ this function and not all 'sync' callbacks!
  triggerChangeOnSelectedRoleSync: ->
    @trigger 'change'

  # Constructs list of current user's ownerships, operatorships, and favorites
  buildBookmarks: ->
    # Bookmarks are the union of favorites, group ownerships and operatorships.
    # Use .uniq() in case these overlap, _.union won't catch the overlap due to the
    # unique ID being .get('entity_id').
    # Bookmarks themselves are { id: entity_id, name: entity_name, type: 'Person' or 'Group' }
    _bookmarks = _.uniq(_.union(
      DssRm.current_user.favorites.models.map( (m) -> { id: m.get('id'), name: m.get('name'), type: m.get('type') } ),
      DssRm.current_user.group_ownerships.models.map( (m) -> { id: m.get('group_id'), name: m.get('name'), type: 'Group' } ),
      DssRm.current_user.group_operatorships.models.map( (m) -> { id: m.get('group_id'), name: m.get('name'), type: 'Group' } )
    )).sort (a, b) ->
      if a.type == 'Group' then -1 else 1
    @bookmarks.reset _bookmarks

  # Return the role model associated with @selected_role_id. Always search, don't store the role model - it may be reset on sync!
  getSelectedRole: ->
    selected_role_id = @get('selected_role_id')
    selected_role = null

    DssRm.applications.find (application) =>
      application.roles.find (role) =>
        selected_role = role if role.id == selected_role_id

    selected_role

  # Return the model associated with @selected_application_id. Always search, don't store the application model - it may be reset on sync!
  getSelectedApplication: ->
    selected_application_id = @get('selected_application_id')
    selected_application = null

    DssRm.applications.find (application) =>
      selected_application = application if application.id == selected_application_id

    selected_application

  # Attempts to set focused_application_id based on search string 'term'
  focusApplicationByTerm: (term) ->
    if app = DssRm.applications.find( (i) -> i.get('name') == term )
      @set focused_application_id: app.id
    else
      @set focused_application_id: null

  # Simple function used during view state debugging
  _debugToStr: ->
    console.log 'Current view_state:'
    console.log "selected_application_id: #{@get('selected_application_id')}"
    console.log "selected_role_id: #{@get('selected_role_id')}"
    console.log "focused_application_id: #{@get('focused_application_id')}"
    console.log "focused_entity_id: #{@get('focused_entity_id')}"
)

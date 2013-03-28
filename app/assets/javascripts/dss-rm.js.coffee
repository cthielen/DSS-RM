window.DssRm =
  Models: {}
  Collections: {}
  Views: {}
  Routers: {}
  
  initialize: (data) ->
    @applications = new DssRm.Collections.Applications(data.applications)
    
    @current_user = new DssRm.Models.Entity(data.current_user);
    @current_user.set('admin', data.current_user_admin)
    
    @router = new DssRm.Routers.Applications()
    
    unless Backbone.history.started
      Backbone.history.start()
      Backbone.history.started = true
    
    # Enable tooltips
    $("body").tooltip selector: "[rel=tooltip]"
    
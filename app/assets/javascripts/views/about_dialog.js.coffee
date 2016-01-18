DssRm.Views.AboutDialog = Backbone.View.extend(
  tagName: "div"
  className: "modal"
  id: "aboutDialogModal"
  events:
    "hidden": "cleanUpModal"

  initialize: ->
    @$el.html JST["templates/application/about_dialog"]()

  render: ->
    @$("span#last_updated").html window.rm_last_updated
    @

  cleanUpModal: ->
    @remove()

    # Need to change URL in case they want to open the same modal again
    Backbone.history.navigate "index"
)

DssRm.Views.EntityShow = Support.CompositeView.extend({
  tagName: "div",

  events: {
    "click a#apply": "save",
    "hidden": "cleanUpModal"
  },

  initialize: function() {
    this.model.bind('change', this.render, this);
  },

  render: function () {
    var resolved = DssRm.DetermineEntityType( this.model.get('id') );

    this.$el.html(JST['entities/show_' + resolved.type ]({ model: this.model }));
    this.renderModalContents(resolved);

    return this;
  },

  renderModalContents: function(resolved) {
    var self = this;

    if(resolved.type == "group") {
      // Summary tab
      self.$('h3').html(this.model.escape('name'));
      self.$('input[name=name]').val(this.model.escape('name'));
      self.$('textarea[name=description]').val(this.model.escape('description'));
      self.$('span#group_member_count').html(this.model.get('members').length);

      var owners_tokeninput = self.$("input[name=owners]");
      owners_tokeninput.tokenInput(Routes.api_people_path(), {
        crossDomain: false,
        defaultText: "",
        theme: "facebook",
        tokenValue: "uid"
      });
      _.each(this.model.get('owners'), function(owner) {
        owners_tokeninput.tokenInput("add", {uid: owner.uid, name: owner.name});
      });

      var operators_tokeninput = self.$("input[name=operators]");
      operators_tokeninput.tokenInput(Routes.api_people_path(), {
        crossDomain: false,
        defaultText: "",
        theme: "facebook",
        tokenValue: "uid"
      });
      _.each(this.model.get('operators'), function(operator) {
        operators_tokeninput.tokenInput("add", {uid: operator.uid, name: operator.name});
      });

      var members_tokeninput = self.$("input[name=members]");
      members_tokeninput.tokenInput(Routes.api_people_path(), {
        crossDomain: false,
        defaultText: "",
        theme: "facebook",
        tokenValue: "uid"
      });
      _.each(this.model.get('members'), function(member) {
        members_tokeninput.tokenInput("add", {uid: member.uid, name: member.name});
      });

      //debugger;
    } else if(resolved.type == "person") {

    }
  },

  save: function() {
    //this.model.set({ name: this.$('input[name=name]').val() });
    //this.model.save();
  },

  cleanUpModal: function() {
    //$("div#applicationShowModal").remove();
    // Need to change URL in case they want to open the same modal again
    Backbone.history.navigate("");
  }
});

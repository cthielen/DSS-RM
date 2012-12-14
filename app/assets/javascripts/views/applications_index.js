DssRm.Views.ApplicationsIndex = Support.CompositeView.extend({
  tagName: "div",
  className: "row-fluid",

  events: {
    "click #cards .card .role" : "selectRole",
    "click #pins li"           : "selectEntity",
    "click #cards"             : "deselectAll"
  },

  initialize: function(options) {
    var self = this;

    // View states
    this.selected = {};
    this.selected.application = null;
    this.selected.role = null;
    this.selected.entities = [];

    this.applications = this.options.applications;
    this.current_user = this.options.current_user;

    this.applications.on('change add destroy sync', this.render, this);
    this.current_user.favorites.on('change add destroy sync', this.render, this);
    this.current_user.group_ownerships.on('change add destroy sync', this.render, this);
    this.current_user.group_operatorships.on('change add destroy sync', this.render, this);

    this.$el.html(JST['applications/index']({ applications: this.applications }));

    this.$("#sidebar_search").typeahead({
      minLength: 2,
      sorter: function(items) { return items; }, // required to keep the order given to process() in 'source'
      highlighter: function (item) {
        var item = item.split('####')[1]; // See: https://gist.github.com/3694758 (FIXME when typeahead supports passing objects)
        var query = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, '\\$&')
        return item.replace(new RegExp('(' + query + ')', 'ig'), function ($1, match) {
          return '<strong>' + match + '</strong>'
        })
      },
      source: self.sidebarSearch,
      updater: function(item) { self.searchResultSelected(item, self); }
    });

    this.$("#search_applications").typeahead({
      minLength: 2,
      sorter: function(items) { return items; }, // required to keep the order given to process() in 'source'
      highlighter: function (item) {
        var item = item.split('####')[1]; // See: https://gist.github.com/3694758 (FIXME when typeahead supports passing objects)
        var query = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, '\\$&')
        return item.replace(new RegExp('(' + query + ')', 'ig'), function ($1, match) {
          return '<strong>' + match + '</strong>'
        })
      },
      source: function(query, process) {
        self.applicationSearch(query, process, self);
      },
      updater: function(item) { self.applicationSearchResultSelected(item, self); }
    });
  },

  render: function () {
    var self = this;

    // We must ensure tooltips are closed before possibly deleting their
    // associated DOM elements
    this.$('[rel=tooltip]').each(function(i, el) {
      if(el != undefined) $(el).tooltip('hide');
    });

    this.$('#cards').empty();
    this.applications.each(function(application) {
      var card = new DssRm.Views.ApplicationItem({
        model: application,
        highlighted_application_id: self.selected.application ? self.selected.application.get('id') : null,
        highlighted_role_id: self.selected.role ? self.selected.role.get('id') : null
      });
      self.renderChild(card);
      self.$('#cards').append(card.el);
    });

    var _sidebar_entities = _.union(
      this.current_user.group_ownerships.models,
      this.current_user.group_operatorships.models,
      this.current_user.favorites.models);
    var _sidebar_entities = _.sortBy(_sidebar_entities, function(e) {
      var prepend = (e.get('type') == "Group") ? '1' : '2';
      var sort_num = parseInt((prepend + e.get('name').charCodeAt(0).toString()));
      return sort_num;
    });

    if(this.sidebar_entities === undefined) this.sidebar_entities = new DssRm.Collections.Entities();
    this.sidebar_entities.reset(_sidebar_entities);

    this.$('#pins').empty();
    this.sidebar_entities.each(function(entity) {
      var pin = new DssRm.Views.EntityItem({
        model: entity,
        highlighted: _.indexOf(self.selected.entities, entity.get('id')) >= 0 // true if in selected.entities
      });
      self.renderChild(pin);
      self.$('#pins').append(pin.el);
    });

    return this;
  },

  // Populates the sidebar search with results via async call to Routes.api_search_path()
  sidebarSearch: function(query, process) {
    $.ajax({ url: Routes.api_search_path(), data: { q: query }, type: 'GET' }).always(function(data) {
      entities = [];
      var exact_match_found = false;
      _.each(data, function(entity) {
        if(query.toLowerCase() == entity.name.toLowerCase()) exact_match_found = true;
        entities.push(entity.id + '####' + entity.name);
      });

      if(exact_match_found == false) {
        // Add the option to create a new one with this query (-1 and -2 are invalid IDs to indicate these choices)
        entities.push(DssRm.Views.ApplicationsIndex.FID_ADD_PERSON + '####Add Person ' + query);
        entities.push(DssRm.Views.ApplicationsIndex.FID_CREATE_GROUP + '####Create Group ' + query);
      }

      process(entities);
    });
  },

  searchResultSelected: function(item, self) {
    var parts = item.split('####');
    var id = parseInt(parts[0]);
    var label = parts[1];

    switch(id) {
      case DssRm.Views.ApplicationsIndex.FID_ADD_PERSON:
        alert("Currently unsupported.");
      break;
      case DssRm.Views.ApplicationsIndex.FID_CREATE_GROUP:
        self.current_user.group_ownerships.create({ name: label.slice(13), type: 'Group' }); // slice(13) is removing the "Create Group " prefix
      break;
      default:
        // Exact result selected. Add this person to their sidebar_entities as needed
        if(self.sidebar_entities.find(function(e) { return e.id === id }) === undefined) {
          // Add this result
          var p = new DssRm.Models.Entity({ id: id, name: label, type: 'Person' });
          self.current_user.favorites.add(p);
          self.current_user.save();

          // If a role is selected, the behavior is to also automatically assign the new
          // favorite to that role
          if(this.selected.role) {
            var updated_favorites = this.selected.role.get('entities');
            updated_favorites.push({ id: id, name: label });

            this.selected.role.set({
              entities: updated_favorites
            });
            this.selected.entities = this.selected.role.get('entities').map(function(e) { return e.id });

            this.selected.application.save();
          }
        }
      break;
    }
  },

  applicationSearch: function(query, process, self) {
    entities = [];
    var exact_match_found = false;

    self.applications.each(function(app) {
      if(app) {
        if(~app.get('name').toLowerCase().indexOf(query.toLowerCase())) {
          if(app.get('name').toLowerCase() == query.toLowerCase()) exact_match_found = true;
          entities.push(app.get('id') + '####' + app.get('name'));
        }
      }
    });
    if(exact_match_found == false) {
      // Add the option to create a new one with this query
      entities.push(DssRm.Views.ApplicationsIndex.FID_CREATE_APPLICATION + '####Create ' + query);
    }

    process(entities);
  },

  applicationSearchResultSelected: function(item, self) {
    var parts = item.split('####');
    var id = parseInt(parts[0]);
    var label = parts[1];

    switch(id) {
      case DssRm.Views.ApplicationsIndex.FID_CREATE_APPLICATION:
        self.applications.create({ name: label.slice(7) }); // slice(7) is removing the "Create " prefix
      break;
    }
  },

  deselectAll: function(e) {
    this.selected.application = null;
    this.selected.role = null;
    this.selected.entities = [];

    this.render();
  },

  selectRole: function(e) {
    e.stopPropagation();

    var application_id = $(e.currentTarget).parent().parent().parent().data('application-id');

    this.selected.application = this.applications.get(application_id);
    this.selected.role = this.selected.application.roles.get($(e.currentTarget).data('role-id'));
    this.selected.entities = this.selected.role.get('entities').map(function(e) { return e.id });

    this.render();
  },

  selectEntity: function(e) {
    var clicked_entity_id = $(e.currentTarget).data('entity-id');
    var clicked_entity_name = $(e.currentTarget).data('entity-name');

    e.stopPropagation();

    // Behavior of selecting an entity changes depending on whether an application/role
    // is selected or not.
    // If an application/role is selected, toggling an entity associates or disassociates
    // that entity from that application/role.
    // If no application/role is selected, clicking an entity merely filters the application/role
    // list to display their current assignments.

    if(this.selected.role) {
      // toggle on or off?
      var matched = this.selected.role.get('entities').filter(function(e) { return e.id == clicked_entity_id });
      var updated_favorites = null;
      if(matched.length > 0) {
        // toggling off
        updated_favorites = _.without(this.selected.role.get('entities'), matched[0]);
      } else {
        // toggling on
        updated_favorites = this.selected.role.get('entities');
        updated_favorites.push({ id: clicked_entity_id, name: clicked_entity_name });
      }

      this.selected.role.set({
        entities: updated_favorites
      });
      this.selected.entities = this.selected.role.get('entities').map(function(e) { return e.id });

      this.selected.application.save();
    } else {
      //this.selected_entities.push($(e.currentTarget).data('entity-id'));
      //this.selected_entities = _.uniq(this.selected_entities);
    }

    this.render();
  }
}, {
  // Constants used in this view
  FID_ADD_PERSON: -1,
  FID_CREATE_GROUP: -2,
  FID_CREATE_APPLICATION: -3
});

// Functions to interact on any page utilizing 'cards' (Manage & Template pages, namely)

$(function() {
  cards.initialize();
});

(function (cards, $, undefined) {
  cards.cards = null; // will be filled in using the view
  cards.selected_card = null;
  cards.template = null;
  
  cards.initialize = function() {
    // Set up the virtual card preferences
    $("div#left").on("mouseenter mouseleave", "div#cards div.card div.card-title", function(e) {
      if(e.type == "mouseenter") {
        $(this).children("i").css("display", "block");
      } else {
        // hover out
        $(this).children("i").css("display", "none");
      }
    });
    
    // Establish hover for card details
    $("div#left").on("click", "div#cards div.card div.card-title i", function() {
      applications.entity_details('4' + $(this).parent().parent().data("application-id"));
    });
    
    // Allow clicking on cards to trigger their adherents
    $("div#left").on("click", "div#cards div.card", function() {
      // Unhighlight other cards
      $("div.card").css("box-shadow", "").css("border", "");
    
      // Highlight this card
      $(this).css("box-shadow", "#333 0 0 10px").css("border", "1px solid #777");
    
      // Re-sort the sidebar to show the associated people and groups
      cards.populate_sidebar($(this).data("uids"));
    
      // Record it
      cards.selected_card = $(this);
    });
    
    // Render the application cards
    cards.template = $("#tmpl-card").html();
    _.each(applications.applications, function(app) {
      var compiledTmpl = _.template(cards.template, { app: app });
      $("div#cards").append(compiledTmpl);
    });
    
    // Delete/info button(s) appear on hover for the sidebar pins
    $("div#right").on("mouseenter mouseleave", "ul.pins li", function(e) {
      if(e.type == "mouseenter") {
        if($(this).data("uid").toString()[0] == "2") {
          // only show a delete item if this is a group (you cannot delete users through this interface)
          $(this).children("i.icon-remove").css("display", "block");
        }
        $(this).children("i.icon-search").css("display", "block");
      } else {
        // hover out
        $(this).children("i").css("display", "none");
      }
    });
    
    // Enable the details button for sidebar pins
    $("div#right").on("click", "ul.pins>li>i.icon-search", function() {
      cards.entity_details($(this).parent().data("uid"));
    });
  }
  
  // Shows and hides the div.card elements based on 'query' matching each .card-title>h3
  cards.visual_filter = function(query) {
    // Also filter the application cards themselves
    if(query.length > 0) {
      var re = new RegExp(query, "i");
      
      // Search the card titles
      var matched_cards = $("div.card").map(function(o, i) {
        var card_title = $(this).find(".card-title h3:first").html();
            
        if(card_title.search(re) != -1) {
          return $(this);
        }
        
        return null;
      });
      
      // Show only the matching cards
      $("div.card").hide();
      $(matched_cards).each(function() {
        $(this).show();
      });
    } else {
      $("div.card").show();
    }
  }
  
  // Graphically sorts the right-hand availability list based on terms in 'str'
  cards.populate_sidebar = function(uids) {
    // Clear out the existing list (fade out li elements and destroy since they are clones)
    $("#entity_list>li").animate({
      opacity: 0
    }, 200, function() {
      $(this).remove(); // it is a cloned element and safe to delete
    });
    
    if(typeof uids == "undefined") return;
    
    // Generate a list of matching li elements
    $.ajax({ url: Routes.api_resolve_path(), data: { uids: uids }, type: 'GET'}).always(function(entities) {
      pin_template = $("#tmpl-pin").html();
      _.each(entities, function(entity) {
        var compiledTmpl = _.template(pin_template, { entity: entity });
        $("#entity_list").append(compiledTmpl);
      });
    });
  }
  
  cards.entity_details = function(uid) {
    var entity_type = uid.toString()[0];
    var id = uid.toString().substr(1);
    var details_url = null;
    
    if(entity_type == '1') {
      // person
      details_url = Routes.people_path() + "/" + id;
    } else if(entity_type == '2') {
      // group
      details_url = Routes.groups_path() + "/" + id;
    } else {
      // application
      details_url = Routes.applications_path() + "/" + id;
    }
    
    template.status_text("Fetching details...");
    
    $.get(details_url, function(response) {
      template.hide_status();
      $("#modal_container").empty();
      $("#modal_container").append(response);
      $("#person_modal").modal();
      details_modal.init();
    });
  }
} (window.cards = window.cards || {}, jQuery));

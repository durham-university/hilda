function moduleDataChanged(input){
  var container = $(input).closest('.module_container');
  container.addClass('dirty_data');
}

function init_modules_ajax() {
  var ajax_manager = (function(){
    var requests = [];
    var waiting_for_response = 0;
    var timeout_id = 0;
    var poll_action = $("#modules_poll_form").attr('action');
    
    var refresh_classes = function(old_elem, new_elem, filter) {
      var classes = (old_elem.attr('class') || '').split(' ').filter(function(c){return !filter(c);});
      classes = classes.concat( (new_elem.attr('class') || '').split(' ').filter(filter) );
      old_elem.attr('class',classes.join(' '));      
    };
    
    return {
      isGraphRunning: function(){
        if(!this.isOnGraphPage()) return false;
        return $('.module_graph').hasClass('graph_running') || $('.module_graph').hasClass('graph_queued');
      },
      isOnGraphPage: function(){
        return $('.module_graph').length>0;
      },
      updateModule: function(new_module_container){        
        //console.log("updating module");
        var old_module_container = $('#'+new_module_container.attr('id'))
        var alert_container = old_module_container.find('ul.list-group>li:first');
        
        var change_time = parseInt(new_module_container.find('.module_timestamp').text());
        var old_change_time = parseInt(old_module_container.find('.module_timestamp').text());
        if(change_time<=old_change_time) {
          var alerts = new_module_container.find('div.alert')
          if(alerts.length>0) {
            alerts.detach();
            alert_container.append(alerts);
          }
          return;
        }
        
        if(old_module_container.hasClass('dirty_data')) {
          if(!old_module_container.hasClass('concurrent_edit')){
            old_module_container.addClass('concurrent_edit');
            alert_container.append('<div class="alert alert-warning alert-dismissable"><button name="button" type="button" class="close" data-dismiss="alert">x</button>Warning: concurrent module edit detected.</div>');
          }
        }
        else {
          old_module_container.replaceWith(new_module_container);
          new_module_container.trigger("hilda:module_replaced",[new_module_container]);
        }
      },
      updateGroupStatus: function(tab){
        var href = tab.find('a').attr('href');
        var old_tab = $("a[href='"+href+"']").closest('li');
        refresh_classes(old_tab, tab, function(c){return c.startsWith('group_');});
      },
      updateGraphButtons: function(graph){
        $('.module_graph .graph_controls button').each(function(){
          var old_button = $(this);
          var new_button = graph.find("button[data-url='"+old_button.attr('data-url')+"']");
          refresh_classes(old_button, new_button, function(c){return c=='disabled';});
        });
      },
      updateApplicationFlashes: function(resp){
        $('.module_graph').parent().prepend( resp.find('.application_flashes .alert').detach() );
      },
      handleResponse: function(resp){
        //console.log("got response");
        resp = $('<div>'+resp+'</div>');
        var _this = this;

        refresh_classes($('.module_graph'), resp.find('.module_graph'), function(c){return c.startsWith('graph_');});

        resp.find('.module_container').each(function(){
          _this.updateModule($(this));
        });
        
        resp.find('.nav-tabs>li').each(function(){
          _this.updateGroupStatus($(this));
        });
        this.updateGraphButtons(resp.find('.module_graph'));
        
        this.updateApplicationFlashes(resp);

        waiting_for_response--;

        if(requests.length>0 && waiting_for_response==0) this.sendNow();

        if(this.isGraphRunning() && !this.isRunning()) this.run();
      },
      handleFail: function(resp){
        alert("Error!  Status: " + resp.status);
        waiting_for_response--;
        if(requests.length>0 && waiting_for_response==0) this.sendNow();
      },
      sendForm: function(form){
        var req = {
            url: form.attr("action"),
            type: form.attr("method").toUpperCase(),
            data: new FormData(form[0]),
            processData: false,
            contentType: false,
            cache: false
        };
        if(form.attr('enctype')) req['enctype'] = form.attr('enctype');
        requests.push(req);
        if(!waiting_for_response) this.sendNow();
      },
      sendControlAction: function(button_or_url,action){
        var req = {
          url: typeof(button_or_url)=='string'? button_or_url : button_or_url.attr('data-url'),
          type: 'POST',
          data: { no_layout: 'true' }
        }
        if(typeof(button_or_url)!='string') button_or_url.addClass('disabled');
        requests.push(req);
        if(!waiting_for_response) this.sendNow();
      },
      confirmControlAction: function(title,message,checkbox,buttonLabel,url,action){
        var dialog = $('#generic_confirm_modal');
        dialog.find('.modal-title').text(title)
        if(message) dialog.find('.modal-message').show().text(message);
        else dialog.find('.modal-message').hide();
        dialog.find('input[type="checkbox"][name="confirm_deletion"]').prop('checked',false);
        dialog.find('label[for="confirm_deletion"]').text(checkbox);
        dialog.find('input[type="submit"]').val(buttonLabel);
        var _this = this;
        dialog.find('form').data('actionCallback',function(){
          dialog.modal('hide');
          _this.sendControlAction(url,action);
        });
        dialog.modal();
      },
      sendNow: function(){
        //console.log("sending form");
        waiting_for_response++;
        var req = requests.shift();
        var _this = this;
        req['success'] = function (resp) { _this.handleResponse(resp); };
        req['fail'] = function (resp) { _this.handleFail(resp); };
        $.ajax(req);
      },
      poll: function(){
        //console.log("polling");
        waiting_for_response++;
        var _this = this;
        $.ajax({
          url: poll_action,
          type: "GET",
          data: { no_layout: 'true' },
          success: function(resp) { _this.handleResponse(resp); },
          fail: function(resp) { _this.handleFail(resp); }
        });
      },
      run: function(){
        if(waiting_for_response == 0) this.poll();
        var _this = this;
        if(this.isGraphRunning()) {
          timeout_id = setTimeout(function(){ _this.run() }, 5000)
        }
        else {
          timeout_id = 0;
        }
      },
      isRunning: function(){
        return timeout_id>0;
      },
      stop: function(){
        clearTimeout(timeout_id);
        timeout_id=0;
      },
      start: function(){
        var _this = this;
        $(document).on('page:change', function(){ _this.pageChanged(); });
        this.pageChanged();
      },
      pageChanged: function(){
        this.setSubmitHandlers();
        if(this.isGraphRunning() && !this.isRunning()) this.run();
      },
      setSubmitHandlers: function(){
        if(!this.isOnGraphPage()) return;
        var graph_elem = $(".module_graph");
        if(graph_elem.data('submit_handlers_set')) return;
        graph_elem.data('submit_handlers_set',true);
        var _this = this;

        var submitForm = function(event){
          event.preventDefault();
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          var form = button.closest('form');
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          form.addClass('sending_data');
          form.closest('.module_container').removeClass('dirty_data');

          _this.sendForm(form);

          form.find('input').attr('disabled','true');

          return false;
        };

        $(".module_graph").on('click',".module_container .module input[type='submit']", submitForm );
        $(".module_graph").on('click',".module_container .module button[type='submit']", submitForm );

        $(".module_graph").on('click',".module_container .module button.rollback_module_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          _this.confirmControlAction(
              "Rollback modules back to ",
              "Rolling back these modules will also delete files in other services that were ingested there by any of these modules",
              "Yes, I really want to rollback these modules","Rollback",button,'reset');
        });

        $(".module_graph").on('click',".module_container .module button.reset_module_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'reset');
        });

        $(".module_graph").on('click',".module_container .module button.start_module_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'start');
        });
        
        $(".module_graph").on('click',".graph_controls button.reset_graph_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'reset');
        });

        $(".module_graph").on('click',".graph_controls button.start_graph_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'start');
        });
        
      }
    };
  })();
  ajax_manager.start();

  hilda_modules_poll_change = function(){ ajax_manager.poll(); }

  dajax_manager = ajax_manager; // expose ajax_manager for debugging
}

$(function(){ init_modules_ajax() });

$(function(){
  $('.module_graph').on('change','.file_selector .file_node .ingestion_process_select_files .checkbox input[type="checkbox"]',function(event) {
    var input = $(this);
    var children = input.closest('.file_node').find('>.file_children>.file_node>.ingestion_process_select_files input[type="checkbox"]');
    var checked = input.prop('checked');
    for(var i=0;i<children.length;i++){
      $(children[i]).prop('checked', checked);
    }
  });  
});
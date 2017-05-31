$(function(){
  $('.module_graph').on('change','.library_linker .ingestion_process_library_record_fragment select',function(event) {
    var select = $(this);
    var form = select.closest('form');
    var typeSelect = form.find('.ingestion_process_library_record_type select');
    if(typeSelect.val()!="Millennium") return;
    form.find('input.btn-primary').click();
  });  
});
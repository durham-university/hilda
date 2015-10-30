$(function(){
  var get_dropzone = function(elem){
    var uploader = elem.closest('.file_uploader')
    var dropzone = uploader.data('dropzone');
    if(!dropzone) return init_dropzone(uploader);
    return dropzone;
  };
  var init_dropzone = function(uploader){
    var formTemplate = uploader.find('.form_template')

    var previewNode = uploader.find('.file_uploader_preview_template');
    previewNode.removeClass('file_uploader_preview_template');
    var previewTemplate = previewNode.parent().html();
    previewNode.detach();
    var actionButtons = uploader.find('.upload_action_buttons');
    if(actionButtons.length==0) return null;

    var dropzone = new Dropzone(actionButtons[0], {
      url: formTemplate.attr('action'),
      sending: function(event, xhr, formData){
        formData.append('authenticity_token', formTemplate.find("input[name='authenticity_token']").val());
        formData.append('ingestion_process[no_layout]','true');
      },
      method: "put",
      paramName: "ingestion_process[files]",
      parallelUploads: 1,
      uploadMultiple: true,
      previewTemplate: previewTemplate,
      autoQueue: false,
      previewsContainer: uploader.find('.file_uploader_previews_container')[0],
      clickable: ".fileinput-button"
    });

    dropzone.on("queuecomplete", function(progress) {
      hilda_modules_poll_change();
    });

    uploader.data('dropzone',dropzone);
    return dropzone;
  };

  $('.module_graph').on('click','.file_uploader .upload_action_buttons .start',function(event) {
    var dropzone=get_dropzone($(this));
    dropzone.enqueueFiles(dropzone.getFilesWithStatus(Dropzone.ADDED));
    event.preventDefault();
    return false;
  });
  $('.module_graph').on('click','.file_uploader .upload_action_buttons .cancel',function(event) {
    get_dropzone($(this)).removeAllFiles(true);
  });
  $('.module_graph').on('hilda:init_file_uploader','.file_uploader',function(event){
    get_dropzone($(this));
  });
  $('.module_graph').on('hilda:module_replaced','.module_container',function(event){
    $(this).find('.file_uploader').trigger("hilda:init_file_uploader")
  });
  $('.file_uploader').trigger("hilda:init_file_uploader");
});

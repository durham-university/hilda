# Can't use the default ActiveFedora::Noid.config translator since it depends on the
# system-wide Noid.config which may use a different template. This implementation
# is based on that but assuming a minimum template length of 8 characters, which
# gives treeparts = 4
ActiveFedora::Base.translate_uri_to_id = lambda do |uri|
  baseurl = "#{ActiveFedora.fedora.host}#{ActiveFedora.fedora.base_path}"
  treeparts = 4
  baseparts = baseurl.count('/') + treeparts
  URI(uri).path.split('/', baseparts).last
end

# This one doesn't actually depend on system-wide ActiveFedora::Noid.config so
# can use the default translator.
ActiveFedora::Base.translate_id_to_uri = ActiveFedora::Noid.config.translate_id_to_uri

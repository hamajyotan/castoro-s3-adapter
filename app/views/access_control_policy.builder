xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.AccessControlPolicy :xmlns => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.Owner do
    xml.ID @owner_id
    xml.DisplayName @display_name if @display_name
  end
  xml.AccessControlList do
    grant_to_xml xml, @grant
  end
end


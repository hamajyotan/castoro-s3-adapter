xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.ListAllMyBucketsResult :xmlns => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.Owner do
    xml.ID @owner_id
    xml.DisplayName @display_name
  end
  @buckets.each { |bucket|
    xml.Buckets do
      xml.Bucket do
        xml.Name bucket[:name]
        xml.CreationDate bucket[:creation_date]
      end
    end
  }
end

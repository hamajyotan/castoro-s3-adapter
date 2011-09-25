xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.ListBucketResult :xmlns => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.Name @bucket
  xml.Prefix @prefix
  xml.Marker @marker
  xml.MaxKeys @max_keys
  xml.NextMarker @next_marker if @next_marker
  xml.Delimiter @delimiter if @delimiter
  xml.IsTruncated @truncated

  @contents.to_a.each { |content|
    xml.Contents do
      xml.Key           content[:key]
      xml.LastModified  content[:last_modified]
      xml.ETag          """#{content[:etag]}"""
      xml.Size          content[:size]
      xml.Owner do
        xml.ID          content[:owner][:id]
        xml.DisplayName content[:owner][:display_name] if content[:owner][:display_name]
      end if content[:owner]
      xml.StorageClass  content[:storage_class]
    end
  }
  @common_prefixes.to_a.each { |common_prefix|
    xml.CommonPrefixes do
      xml.Prefix common_prefix[:prefix]
    end
  }
end

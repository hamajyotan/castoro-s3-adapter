
module S3Adapter
  module Helper
    module AclHelper
      def grant_to_xml xml, grant
        grant.each { |g|
          xml.Grant do
            case g[:grantee_type]
            when :group
              xml.Grantee 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:type' => 'Group' do
                xml.URI g[:uri]
              end
            when :user
              xml.Grantee 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:type' => 'CanonicalUser' do
                xml.ID g[:id]
                xml.DisplayName g[:display_name]
              end
            end
            xml.Permission g[:permission]
          end
        }
      end
    end
  end
end


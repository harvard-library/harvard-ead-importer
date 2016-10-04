class HarvardEADConverter < EADConverter
  def self.configure
    super

    with 'daogrp' do
      title = att('title')

      unless title
        title = ''
        ancestor(:resource, :archival_object ) { |ao| title << ao.title + ' Digital Object' }
      end

      make :digital_object, {
        :digital_object_id => SecureRandom.uuid,
        :title => title,
       } do |obj|
         ancestor(:resource, :archival_object) do |ao|
          ao.instances.push({'instance_type' => 'digital_object', 'digital_object' => {'ref' => obj.uri}})
         end

         # Actuate and Show values applicable to <daoloc>s can come from <arc> elements,
         # so daogrp contents need to be handled together
         dg_contents = Nokogiri::XML::DocumentFragment.parse(inner_xml)

         # Hashify arc attrs keyed by xlink:to
         arc_by_to_val = dg_contents.xpath('arc').map {|arc|
           if arc['xlink:to']
             [arc['xlink:to'], arc]
           else
             nil
           end
         }.reject(&:nil?).reduce({}) {|hsh, (k, v)| hsh[k] = v;hsh}


         dg_contents.xpath('daoloc').each do |daoloc|
           arc = arc_by_to_val[daoloc['xlink:label']] || {}

           fv_attrs = {}

           # attrs on <arc>
           fv_attrs[:xlink_show_attribute] = arc['xlink:show'] if arc['xlink:show']
           fv_attrs[:xlink_actuate_attribute] = arc['xlink:actuate'] if arc['xlink:actuate']

           # attrs on <daoloc>
           fv_attrs[:file_uri] = daoloc['xlink:href'] if daoloc['xlink:href']
           fv_attrs[:use_statement] = daoloc['xlink:role'] if daoloc['xlink:role']

           obj.file_versions << fv_attrs
         end
         obj
      end
    end

    with :daoloc do
      # nothing! this is here to override super's implementation to prevent duplicate daoloc processing
    end
  end # END configure

end # END class

::EADConverter
::EADConverter = HarvardEADConverter

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
           fv_attrs[:publish] = daoloc['audience'] != 'internal'

           obj.file_versions << fv_attrs
         end
         obj
      end
    end

    with 'daoloc' do
      # nothing! this is here to override super's implementation to prevent duplicate daoloc processing
    end
  end # END configure

  ### Publish/Audience fixes for various note fields and methods ###

  def make_nested_note(note_name, tag)
      content = tag.inner_text

      make :note_multipart, {
        :type => note_name,
        :persistent_id => att('id'),
		    :publish => att('audience') != 'internal',
        :subnotes => {
          'jsonmodel_type' => 'note_text',
          'content' => format_content( content ),
          'publish' => att('audience') != 'internal' # HAX:DAVE This is wrong, but only used in dimensions handling,
        }
      } do |note|
        set ancestor(:resource, :archival_object), :notes, note
      end
  end


  with 'bibliography' do
    make :note_bibliography
    set :persistent_id, att('id')
    set :publish, att('audience') != 'internal'
    set ancestor(:resource, :archival_object), :notes, proxy
  end

  with 'index' do
    make :note_index
    set :persistent_id, att('id')
    set :publish, att('audience') != 'internal'
    set ancestor(:resource, :archival_object), :notes, proxy
  end

  with 'chronlist' do
    if  ancestor(:note_multipart)
      left_overs = insert_into_subnotes
    else
      left_overs = nil
      make :note_multipart, {
             :type => node.name,
             :persistent_id => att('id'),
             :publish => att('audience') != 'internal'
      } do |note|
        set ancestor(:resource, :archival_object), :notes, note
      end
    end

    make :note_chronology, {
           :publish => att('audience') != 'internal'
    } do |note|
      set ancestor(:note_multipart), :subnotes, note
    end

    # and finally put the leftovers back in the list of subnotes...
    if ( !left_overs.nil? && left_overs["content"] && left_overs["content"].length > 0 )
      set ancestor(:note_multipart), :subnotes, left_overs
    end
  end

  with 'dao' do
    make :instance, {
           :instance_type => 'digital_object'
    } do |instance|
      set ancestor(:resource, :archival_object), :instances, instance
    end


    make :digital_object, {
           :digital_object_id => SecureRandom.uuid,
           :publish => att('audience') != 'internal',
           :title => att('title')
         } do |obj|
      obj.file_versions <<  {
        :use_statement => att('role'),
        :file_uri => att('href'),
        :xlink_actuate_attribute => att('actuate'),
        :xlink_show_attribute => att('show')
      }
      set ancestor(:instance), :digital_object, obj
    end

  end

  with 'daodesc' do
    make :note_digital_object, {
           :type => 'note',
           :persistent_id => att('id'),
           :publish => att('audience') != 'internal',
           :content => inner_xml.strip
    } do |note|
      set ancestor(:digital_object), :notes, note
    end
  end

end # END class

::EADConverter
::EADConverter = HarvardEADConverter

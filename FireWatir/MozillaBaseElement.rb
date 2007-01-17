=begin
  license
  ---------------------------------------------------------------------------
  Copyright (c) 2006-2007, Angrez Singh
  
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
  
  1. Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.
  
  2. Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
  
  3. Neither the names Angrez Singh nor the names of contributors to
  this software may be used to endorse or promote products derived from this
  software without specific prior written permission.
  
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS
  IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  --------------------------------------------------------------------------
  (based on BSD Open Source License)
=end

# Base class for html elements.
# This is not a class that users would normally access.
    class Element
        include Container
        # Number of spaces that separate the property from the value in the to_s method
        TO_S_SIZE = 14

        # How to get the nodes using XPath in mozilla.
        ORDERED_NODE_ITERATOR_TYPE = 5
        # To get the number of nodes returned by the xpath expression
        NUMBER_TYPE = 1
        # To get single node value
        FIRST_ORDERED_NODE_TYPE = 9
        # This stores the name of the variable which stores the current element in JSSH  
        @@current_element_object = ""
        # This stores the level to which we have gone finding element inside another element.
        # This is just to make sure that every element has unique name in JSSH.
        @@current_level = 0
        # This stores the name of the element that is about to trigger an Javascript pop up.
        @@current_js_object = nil
        # This stores the name of the variable which stores the current frame.
        @@current_frame_name = ""
        # Has the elements array changed.
        @@has_changed = false 

        attr_accessor :element_name
        attr_accessor :element_type
        #
        # Description:
        #    Creates new instance of element. If argument is not nil and is of type string this
        #    sets the element_name and element_type property of the object. These properties can
        #   be accessed using element_object and element_type methods respectively.
        #
        #   Used internally by Firewatir.
        # 
        # Input:
        #   element - Name of the variable with which the element is referenced in JSSh.
        #
        def initialize(element)
            if(element != nil && element.class == String)
                @element_name = element
                # Get the type of the element.
                $jssh_socket.send("#{element};\n", 0)
                temp = read_socket()
                #puts "#{element} and type is #{temp}"
                temp =~ /\[object\s(.*)\]/
                if $1
                    @element_type = $1
                else
                    # This is done because in JSSh if you write element name of anchor type
                    # then it displays the link to which it navigates instead of displaying 
                    # object type. So above regex match will return nil
                    @element_type = "HTMLAnchorElement"
                end
            elsif(element != nil && element.class == Element)
                @o = element
            end
            
            #puts "@element_name is #{@element_name}"
            #puts "@element_type is #{@element_type}"
        end
                
        private
        def self.def_wrap(ruby_method_name, ole_method_name = nil)
        ole_method_name = ruby_method_name unless ole_method_name
        class_eval "def #{ruby_method_name}
                        assert_exists
                        # Every element has its name starting from element. If yes then
                        # use element_name to send the command to jssh. Else its a number
                        # and we are still searching for element, in this case use doc.all
                        # array with element_name as index to send command to jssh
                        #puts element_object.to_s
                        #if(element_type == 'HTMLDivElement')
                        #    ole_method_name = 'innerHTML'
                        #end
                        $jssh_socket.send('typeof(' + element_object + '.#{ole_method_name});\n', 0)
                        return_type = read_socket()
                        $jssh_socket.send(element_object + '.#{ole_method_name};\n', 0)
                        return_value = read_socket()
                        
                        if(return_type == \"boolean\")
                            return_value = false if return_value == \"false\"
                            return_value = true if return_value == \"true\"
                        end
                        @@current_element_object = ''
                        @@current_frame_name = ''
                        @@current_level = 0
                        return return_value
                    end"
        end
        
        def self.def_wrap_guard(method_name)
            class_eval "def #{method_name}
                        assert_exists
                        # Every element has its name starting from element. If yes then
                        # use element_name to send the command to jssh. Else its a number
                        # and we are still searching for element, in this case use doc.all
                        # array with element_name as index to send command to jssh.
                        begin
                            $jssh_socket.send('typeof(' + element_object + '.#{method_name});\n', 0)
                            return_type = read_socket()
                            $jssh_socket.send('' + element_object + '.#{method_name};\n', 0)
                            return_value = read_socket()
                            if(return_type == \"boolean\")
                                return_value = false if return_value == \"false\"
                                return_value = true if return_value == \"true\"
                            end    
                        
                            @@current_element_object = ''
                            @@current_frame_name = ''
                            @@current_level = 0
                            return return_value
                        rescue
                            return ''
                        end
                        
                    end"
        end
       
        #
        # Description:
        #   Returns an array of the properties of an element, in a format to be used by the to_s method
        #   Currently only following properties are returned.
        #   name, type, id, value, disabled.
        #   Used internally by to_s method.
        # 
        # Output:
        #   Array with values of the following properties:
        #   name, type, id, value, disabled.
        #
        # TODO: Add support for specific properties for specific elements like href for anchor element.
        #
        def string_creator
            n = []
            $jssh_socket.send("#{element_object}.name; \n", 0)
            n << "name:".ljust(TO_S_SIZE) +  read_socket()
            $jssh_socket.send("#{element_object}.type; \n", 0)
            n << "type:".ljust(TO_S_SIZE) + read_socket()
            $jssh_socket.send("#{element_object}.id; \n", 0)
            n << "id:".ljust(TO_S_SIZE) + read_socket()
            $jssh_socket.send("#{element_object}.value; \n", 0)
            n << "value:".ljust(TO_S_SIZE) + read_socket()
            $jssh_socket.send("#{element_object}.disabled; \n", 0)
            n << "disabled:".ljust(TO_S_SIZE) + read_socket()
            return n
        end
        
        #
        # Description:
        #   Sets and clears the colored highlighting on the currently active element.
        #
        # Input:
        #   set_or_clear - this can have following two values 
        #   :set - To set the color of the element.
        #   :clear - To clear the color of the element.
        #
        def highlight(set_or_clear)
            if set_or_clear == :set
                #puts "element_name is : #{element_object}"
                jssh_command = " var original_color = #{element_object}.style.background;"
                jssh_command += " #{element_object}.style.background = \"#{DEFAULT_HIGHLIGHT_COLOR}\"; original_color;"
                
                # TODO: Need to change this so that it would work if user sets any other color.
                #puts "color is : #{DEFAULT_HIGHLIGHT_COLOR}"
                $jssh_socket.send("#{jssh_command}\n", 0)
                @original_color = read_socket()
                
            else # BUG: assumes is :clear, but could actually be anything
                begin 
                    $jssh_socket.send("#{element_object}.style.background = \"#{@original_color}\";\n", 0)
                    read_socket()
                rescue
                    # we could be here for a number of reasons...
                    # e.g. page may have reloaded and the reference is no longer valid
                ensure
                    @original_color = nil
                end
            end
        end
        protected :highlight

        #
        # Description:
        #   Returns array of rows for a given table. Returns nil if calling element is not of table type.
        #
        # Output:
        #   Array of row elements in an table or nil
        #
        def get_rows()
            #puts "#{element_object} and #{element_type}"
            if(element_type == "HTMLTableElement")
                $jssh_socket.send("#{element_object}.rows.length;\n", 0)
                length = read_socket().to_i
                #puts "The number of rows in the table are : #{no_of_rows}"
                return_array = Array.new
                for i in 0..length - 1 do
                    return_array << Element.new("#{element_object}.rows[#{i}]")
                end
                return return_array
            else
                puts "Trying to access rows for Element of type #{element_type}. Element must be of table type to execute this function."
                return nil
            end
        end
        protected :get_rows
       
        #
        # Description:
        #   Locates the element on the page depending upon the parameters passed. Logic for locating the element is written 
        #   in JavaScript and then send to JSSh; so that we don't make small round-trips via socket to JSSh. This is done to 
        #   improve the performance for locating the element.
        #
        # Input:
        #   tag - Tag name of the element to be located like "input", "a" etc. This is case insensitive.
        #   how - The attribute by which you want to locate the element like id, name etc. You can use any attribute-value pair
        #         that uniquely identifies that element on the page. If there are more that one element that have identical
        #         attribute-value pair then first element that is found while traversing the DOM will be returned.
        #   what - The value of the attribute specified by how.
        #   types - Used if that HTML element to be located has different type like input can be of type image, button etc.
        #           Default value is nil
        #   value - This is used only in case of radio buttons where they have same name but different value.
        #
        # Output:
        #   Returns nil if unable to locate the element, else return the element.
        #
        def locate_tagged_element(tag, how, what, types = nil, value = nil)
            #puts caller(0)
            jssh_command = ""
            how = :value if how == :caption 
            how = :href if how == :url
            #puts "current element is : #{@@current_element_object} and tag is #{tag}"
            # If there is no current element i.e. element in current context we are searching the whole DOM tree.
            # So get all the elements.
            if(@@current_element_object == "")
                jssh_command += "var elements_#{tag} = null; elements_#{tag} = #{DOCUMENT_VAR}.getElementsByTagName(\"#{tag}\");"
                if(types != nil and types.include?("textarea"))
                    jssh_command += "var elements2 = null; elements2 = #{DOCUMENT_VAR}.getElementsByTagName(\"textarea\");
                                     var length = elements_#{tag}.length + elements2.length;
                                     var arr = new Array(length);
                                     for(var i = 0; i < elements_#{tag}.length; ++i)
                                     {
                                        arr[i] = elements_#{tag}[i];
                                     }
                                     for(var i = elements_#{tag}.length, j = 0; j < elements2.length; ++j,++i)
                                     {
                                        arr[i] = elements2[j];
                                     }
                                     elements_#{tag} = arr;"
                        
                end                    
                @@has_changed = true
            else
                jssh_command += "var elements_#{@@current_level}_#{tag} = #{@@current_element_object}.getElementsByTagName(\"#{tag}\");" 
                if(types != nil and types.include?("textarea"))
                    jssh_command += "var elements2_#{@@current_level} = #{@@current_element_object}.getElementsByTagName(\"textarea\");
                                     var length = elements_#{@@current_level}_#{tag}.length + elements2_#{@@current_level}.length;
                                     var arr = new Array(length);
                                     for(var i = 0; i < elements_#{@@current_level}_#{tag}.length; ++i)
                                     {
                                        arr[i] = elements_#{@@current_level}_#{tag}[i];
                                     }
                                     for(var i = elements_#{@@current_level}_#{tag}.length, j = 0; j < elements2_#{@@current_level}.length; ++j,++i)
                                     {
                                        arr[i] = elements2_#{@@current_level}[j];
                                     }
                                     elements_#{@@current_level}_#{tag} = arr;"
                end
                @@has_changed = false
            end

            if(types != nil)
                jssh_command += "var types = new Array("
                count = 0
                types.each do |type|
                    if count == 0
                        jssh_command += "\"#{type}\""
                        count += 1
                    else
                        jssh_command += ",\"#{type}\""
                    end
                end
                jssh_command += ");"
            else
                jssh_command += "var types = null;"
            end    
            #jssh_command += "var elements = #{element_object}.getElementsByTagName('*');"
            jssh_command += "var object_index = 1; var o = null; var element_name = '';"
            
            if(value == nil)
                jssh_command += "var value = null;"
            else
                jssh_command += "var value = \"#{value}\";"
            end
            #jssh_command += "elements.length;"
            if(@@current_element_object == "")

                jssh_command += "for(var i=0; i<elements_#{tag}.length; i++)
                                 {
                                    if(element_name != \"\") break;
                                    var element = elements_#{tag}[i];"
            else
                jssh_command += "for(var i=0; i<elements_#{@@current_level}_#{tag}.length; i++)
                                 {
                                    if(element_name != \"\") break;
                                    var element = elements_#{@@current_level}_#{tag}[i];"
            end

            jssh_command += "   var attribute = '';
                                var same_type = false;
                                if(types) 
                                {
                                    for(var j=0; j<types.length; j++)
                                    {
                                        if(types[j] == element.type)
                                        {
                                            same_type = true;
                                            break;
                                        }
                                    }
                                }
                                else
                                {
                                    same_type = true;
                                }
                                if(same_type == true)
                                {
                                    if(\"index\" == \"#{how}\")
                                    {
                                        attribute = object_index; object_index += 1; 
                                    }     
                                    else
                                    {
                                        attribute = element.getAttribute(\"#{how}\");
                                        if(attribute == \"\" || attribute == null)
                                        {
                                            attribute = element.#{how};
                                        }
                                    }
                                    if(attribute == \"\") o = 'NoMethodError';
                                    var found = false;"

            if(what.class == Regexp)
                # Construct the regular expression because we can't use it directly by converting it to string.
                # If reg ex is /Google/i then its string conversion will be (?i-mx:Google) so we can't use it.
                # Construct the regular expression again from the string conversion.
                oldRegExp = what.to_s
                newRegExp = "/" + what.source + "/"
                flags = oldRegExp.slice(2, oldRegExp.index(':') - 2)

                for i in 0..flags.length do
                    flag = flags[i, 1]
                    if(flag == '-')
                        break;
                    else
                        newRegExp << flag
                    end
                end
                #puts "old reg ex is #{what} new reg ex is #{newRegExp}"
                jssh_command += "   var regExp = new RegExp(#{newRegExp});
                                    found = regExp.test(attribute);"
            elsif(how == :index)
                jssh_command += "   found = (attribute == #{what});"
            else                        
                jssh_command += "   found = (attribute == \"#{what}\");"
            end
            #jssh_command += "    found;"
            if(@@current_element_object == "")
                jssh_command += "   if(found) 
                                    { 
                                        if(value)
                                        {
                                            if(element.value == \"#{value}\")
                                            {
                                                o = element;
                                                element_name = \"elements_#{tag}[\" + i + \"]\";
                                                break;
                                            }
                                        } 
                                        else
                                        {
                                            o = element;
                                            element_name = \"elements_#{tag}[\" + i + \"]\";
                                            break;
                                        }
                                    }"
            else
                jssh_command += "   if(found) 
                                    { 
                                        if(value)
                                        {
                                            if(element.value == \"#{value}\")
                                            {
                                                o = element;
                                                element_name = \"elements_#{@@current_level}_#{tag}[\" + i + \"]\";
                                                break;
                                            }
                                        } 
                                        else
                                        {
                                            o = element;
                                            element_name = \"elements_#{@@current_level}_#{tag}[\" + i + \"]\";
                                            break;
                                        }
                                    }"
            end                        
            jssh_command +="     }
                             }
                            element_name;"
            # Remove \n that are there in the string as a result of pressing enter while formatting.                
            jssh_command.gsub!(/\n/, "")                
            #puts jssh_command 
            $jssh_socket.send("#{jssh_command};\n", 0)
            @@current_element_object = element_name = read_socket();          
            @@current_frame_name = ""
            #puts "element name in find control is : #{element_name}"
            @@current_level = @@current_level + 1
            if(element_name != "")
                return Element.new(element_name)
            else
                return nil
            end
        end
        protected :locate_tagged_element
        
        #
        # Description:
        #   Locates frame element. Logic for locating the frame is written in JavaScript so that we don't make small
        #   round trips to JSSh using socket. This is done to improve the performance for locating the element.
        #
        # Input:
        #   how - The attribute for locating the frame. You can use any attribute-value pair that uniquely identifies
        #         the frame on the page. If there are more than one frames that have identical attribute-value pair
        #         then first frame that is found while traversing the DOM will be returned.
        #   what - Value of the attribute specified by how
        #
        # Output:
        #   Nil if unable to locate frame, else return the Frame element.
        #
        def locate_frame(how, what)
            # Get all the frames the are there on the page.
            jssh_command = ""
            if(@@current_frame_name == "")
                jssh_command = "var frameset = #{WINDOW_VAR}.frames;
                                var elements_frames = new Array();
                                for(var i = 0; i < frameset.length; i++)
                                {
                                    var frames = frameset[i].frames;
                                    for(var j = 0; j < frames.length; j++)
                                    {
                                        elements_frames.push(frames[j].frameElement);    
                                    }
                                }"
            else
                jssh_command = "var frames = #{@@current_frame_name}.contentWindow.frames;
                                var elements_frames_#{@@current_level} = new Array();
                                for(var i = 0; i < frames.length; i++)
                                {
                                    elements_frames_#{@@current_level}.push(frames[i].frameElement);
                                }"
            end
                            
            jssh_command +="    var element_name = ''; var object_index = 1;var attribute = '';
                                var element = '';"
            if(@@current_frame_name == "")
                jssh_command += "for(var i = 0; i < elements_frames.length; i++)
                                 {
                                    element = elements_frames[i];"
            else
                jssh_command += "for(var i = 0; i < elements_frames_#{@@current_level}.length; i++)
                                 {
                                    element = elements_frames_#{@@current_level}[i];"
            end
            jssh_command += "       if(\"index\" == \"#{how}\")
                                    {
                                        attribute = object_index; object_index += 1;
                                    }
                                    else
                                    {
                                        attribute = element.getAttribute(\"#{how}\");
                                        if(attribute == \"\" || attribute == null)
                                        {
                                            attribute = element.#{how};
                                        }
                                    }
                                    var found = false;"
            if(what.class == Regexp)                        
                # Construct the regular expression because we can't use it directly by converting it to string.
                # If reg ex is /Google/i then its string conversion will be (?i-mx:Google) so we can't use it.
                # Construct the regular expression again from the string conversion.
                oldRegExp = what.to_s
                newRegExp = "/" + what.source + "/"
                flags = oldRegExp.slice(2, oldRegExp.index(':') - 2)

                for i in 0..flags.length do
                    flag = flags[i, 1]
                    if(flag == '-')
                        break;
                    else
                        newRegExp << flag
                    end
                end
                #puts "old reg ex is #{what} new reg ex is #{newRegExp}"
                jssh_command += "   var regExp = new RegExp(#{newRegExp});
                                    found = regExp.test(attribute);"
            elsif(how == :index)
                jssh_command += "   found = (attribute == #{what});"
            else                        
                jssh_command += "   found = (attribute == \"#{what}\");"
            end

            jssh_command +=     "   if(found)
                                    {"
            if(@@current_frame_name == "")
                jssh_command += "       element_name = \"elements_frames[\" + i + \"]\";
                                        #{DOCUMENT_VAR} = elements_frames[i].contentDocument; "
            else
                jssh_command += "       element_name = \"elements_frames_#{@@current_level}[\" + i + \"]\";
                                        #{DOCUMENT_VAR} = elements_frames_#{@@current_level}[i].contentDocument; "
            end
            jssh_command += "           break;
                                    }
                                }
                                element_name;"
            
            jssh_command.gsub!("\n", "")
            #puts "jssh_command for finding frame is : #{jssh_command}"
            
            $jssh_socket.send("#{jssh_command};\n", 0)
            @@current_frame_name = element_name = read_socket()
            @@current_level = @@current_level + 1
            #puts "element_name for frame is : #{element_name}"

            if(element_name != "")
                return Element.new(element_name)
            else
                return nil
            end    
        end
        protected :locate_frame

        public

        # 
        # Description:
        #   Returns array of elements that matches a given XPath query.
        #   Mozilla browser directly supports XPath query on its DOM. So no need to create the DOM tree as WATiR does for IE.
        #   Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
        #
        # Input:
        #   xpath - The xpath expression or query.
        #
        # Output:
        #   Array of elements that matched the xpath expression provided as parameter.
        #
        def elements_by_xpath(xpath)
            rand_no = random(1000)
            jssh_command = "var xpathResult = #{DOCUMENT_VAR}.evaluate(\"count(#{xpath})\", #{DOCUMENT_VAR}, null, #{NUMBER_TYPE}, null); xpathResult.numberValue;"
            $jssh_socket.send("#{jssh_command}\n", 0);
            node_count = read_socket()
            #puts "value of count is : #{node_count}"

            jssh_command = "var element_xpath_#{rand_no} = new Array(" + node_count + ");"

            jssh_command += "var result = #{DOCUMENT_VAR}.evaluate(\"#{xpath}\", #{DOCUMENT_VAR}, null, #{ORDERED_NODE_ITERATOR_TYPE}, null); 
                             var iterate = result.iterateNext();
                             var count = 0;
                             while(iterate)
                             {
                                element_xpath_#{rand_no}[count] = iterate;
                                iterate = result.iterateNext();
                                count++;
                             }"
                             
            # Remove \n that are there in the string as a result of pressing enter while formatting.                
            jssh_command.gsub!(/\n/, "")                
            #puts jssh_command
            $jssh_socket.send("#{jssh_command};\n", 0)             
            result = read_socket()

            elements = Array.new(node_count.to_i)

            for i in 0..elements.length - 1 do
                elements[i] = Element.new("element_xpath_#{rand_no}[#{i}]")
            end

            return elements;
        end

        #
        # Description:
        #   Returns first element found while traversing the DOM; that matches an given XPath query.
        #   Mozilla browser directly supports XPath query on its DOM. So no need to create the DOM tree as WATiR does for IE.
        #   Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
        #
        # Input:
        #   xpath - The xpath expression or query.
        #
        # Output:
        #   First element in DOM that matched the XPath expression or query.
        #
        def element_by_xpath(xpath)
            rand_no = rand(1000)
            $jssh_socket.send("var element_xpath_#{rand_no} = null; element_xpath_#{rand_no} = #{DOCUMENT_VAR}.evaluate(\"#{xpath}\", #{DOCUMENT_VAR}, null, #{FIRST_ORDERED_NODE_TYPE}, null).singleNodeValue; element_xpath_#{rand_no};\n", 0)             
            result = read_socket()
            #puts "result is : #{result}"
            if(result == "null" || result == "" || result.include?("exception"))
                return nil
            else
                @@current_element_object = "element_xpath_#{rand_no}"
                @@current_level += 1
                return Element.new("element_xpath_#{rand_no}")
            end
        end

        #
        # Description:
        #   Returns the name of the element with which we can access it in JSSh.
        #   Used internally by Firewatir to execute methods, set properties or return property value for the element.
        #
        # Output:
        #   Name of the variable with which element is referenced in JSSh
        #
        def element_object
            #puts caller.join("\n")
            #puts "In element_object element name is : #{element_name}"
            return @element_name if @element_name != nil
            return @o.element_name if @o != nil
        end
        private :element_object

        #
        # Description:
        #   Returns the type of element. For e.g.: HTMLAnchorElement. used internally by Firewatir
        #
        # Output:
        #   Type of the element.
        #
        def element_type
            return @o.element_type if @o != nil
            return @element_type
        end
        protected :element_type # Because it is used by get_rows which is protected we can't have private accessor here.
        
        #
        # Description:
        #   Fires the provided event for an element and by default waits for the action to get completed.
        #
        # Input:
        #   event - Event to be fired like "onclick", "onchange" etc.
        #   wait - Whether to wait for the action to get completed or not. By default its true.
        #
        def fireEvent(event, wait = true)
            #puts "here in fire event function. Event is : #{event}"
            #puts "typeof(#{element_object}.#{event.downcase}); \n"
            $jssh_socket.send("typeof(#{element_object}.#{event.downcase});\n", 0)
            isDefined = read_socket()
            #puts "is method there : #{isDefined}"
            if(isDefined != "undefined")
                if(element_type == "HTMLSelectElement")
                    jssh_command = "var event = #{DOCUMENT_VAR}.createEvent(\"HTMLEvents\");
                                    event.initEvent(\"change\", true, true);
                                    #{element_object}.dispatchEvent(event);"
                    jssh_command.gsub!(/\n/, "")
                    $jssh_socket.send("#{jssh_command}\n", 0)
                    read_socket() if wait
                    wait() if wait
                else
                    $jssh_socket.send("#{element_object}.#{event.downcase}();\n", 0)
                    value = read_socket() if wait
                end    
            end
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
        end
        
        # 
        # Description:
        #   Returns the value of the specified attribute of an element.
        #
        def attribute_value(attribute_name)
            
            #puts attribute_name
            assert_exists()
            $jssh_socket.send("#{element_object}.getAttribute(\"#{attribute_name}\");\n" , 0)
            return_value = read_socket()
            # Try once again to get the value of the attribute using property syntax
            if(return_value == "" || return_value == "null")
                $jssh_socket.send("#{element_object}.#{attribute_name};\n", 0)
                return_value = read_socket()
            end
            
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
            return return_value
        end
        
        #
        # Description:
        #   Checks if element exists or not. Raises UnknownObjectException if element doesn't exists.
        #
        def assert_exists
            unless exists?
                raise UnknownObjectException.new("Unable to locate object, using #{@how} and #{@what}")
            end
        end
        
        #
        # Description:
        #   Checks if element is enabled or not. Raises ObjectDisabledException if object is disabled and 
        #   you are trying to use the object.
        #
        def assert_enabled
            unless enabled?
                raise ObjectDisabledException, "object #{@how} and #{@what} is disabled"
            end                
        end
       
        #
        # Description:
        #   First checks if element exists or not. Then checks if element is enabled or not.
        #
        # Output:
        #   Returns true if element exists and is enabled, else returns false.
        #
        def enabled?
            assert_exists
            $jssh_socket.send("#{element_object}.disabled;\n", 0)
            value = read_socket()
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
            return true if(value == "false") 
            return false if(value == "true") 
            return value
        end
       
        #
        # Description:
        #   Checks if element exists or not. If element is not located yet then first locates the element.
        #
        # Output:
        #   True if element exists, false otherwise.
        #
        def exists?
            #puts "element is : #{element_object}"
            # If elements array has changed locate the element again. So that the element name points to correct element.
            if(element_object == nil || element_object == "" || @@has_changed)
                #puts "locating element"
                locate if defined?(locate)
            else
                #puts "not locating the element again"
                return true
            end    
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
            if(element_object == nil || element_object == "")
                return false
            else
                return true
            end    
        end
        
        #
        # Description:
        #   Returns the text of the element.
        #
        # Output:
        #   Text of the element.
        #
        def text()
            assert_exists
           
            if(element_type == "HTMLOptionElement")
                jssh_command = "#{element_object}.text.replace(/^\s*|\s*$/g,'');"
            else
                # Get the text for the element by iterating over its nodes. If node is of the
                # type text, then return that value.
                jssh_command = "var nodes = #{element_object}.childNodes; var str = \"\";"
                jssh_command += "for(var i=0; i<nodes.length; i++)"
                jssh_command += "  if(nodes[i].nodeName == \"#text\") "
                jssh_command += "    str += nodes[i].nodeValue;"
            end
            
            #puts jssh_command
            $jssh_socket.send("#{jssh_command}\n", 0)
            return_value = read_socket()
            #puts "return value is : #{returnValue}"
            
            #if(returnType == "boolean")
            #    return_value = false if returnValue == "false"
            #    return_value = true if returnValue == "true"
            #end
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
            return return_value
        end
        alias innerText text
        
        # Returns the name of the element (as defined in html)
        def_wrap :name
        # Returns the id of the element
        def_wrap :id
        # Returns whether the element is disabled
        def_wrap :disabled 
        alias disabled? disabled
        # Returns the state of the element
        def_wrap :checked
        # Returns the value of the element
        def_wrap :value
        # Returns the title of the element
        def_wrap :title
        # Returns the value of 'alt' attribute in case of Image element.
        def_wrap :alt
        # Returns the value of 'href' attribute in case of Anchor element.
        def_wrap :src
        # Returns the type of the element. Use in case of Input element only.
        def_wrap :type         
        # Returns the url the Anchor element points to. 
        def_wrap :href
        # Return the ID of the control that this label is associated with
        def_wrap :for, :htmlFor 
        # Returns the class name of the element
        def_wrap :class_name, :className
        # Return the html of the object
        def_wrap :html, :innerHTML
        
        #
        # Description:
        #   Display basic details about the object. Sample output for a button is shown.
        #   Raises UnknownObjectException if the object is not found.
        #      name      b4
        #      type      button
        #      id         b5
        #      value      Disabled Button
        #      disabled   true
        #
        # Output:
        #   Array with value of properties shown above.
        #
        def to_s
            #puts "here in to_s"
            assert_exists
            if(element_type == "HTMLTableCellElement")
                return text()
            else
                result = string_creator #.join("\n")
                @@current_element_object = ''
                @@current_frame_name = ''
                @@current_level = 0
                return result
            end    
        end
        
        #
        # Description:
        #   Function to fire click event on elements.  
        #
        def click
            assert_exists
            assert_enabled

            highlight(:set)
            #puts "#{element_object} and #{element_type}" 
            case element_type
                
                when "HTMLAnchorElement", "HTMLImageElement"
                    # Special check for link or anchor tag. Because click() doesn't work on links.
                    # More info: http://www.w3.org/TR/DOM-Level-2-HTML/html.html#ID-48250443
                    # https://bugzilla.mozilla.org/show_bug.cgi?id=148585

                    jssh_command = "var event = #{DOCUMENT_VAR}.createEvent(\"MouseEvents\");"
                    
                    # Info about initMouseEvent at: http://www.xulplanet.com/references/objref/MouseEvent.html        
                    jssh_command += "event.initMouseEvent('click',true,true,null,1,0,0,0,0,false,false,false,false,0,null);"
                    jssh_command += "#{element_object}.dispatchEvent(event);\n"
                   
                    #puts "jssh_command is: #{jssh_command}"
                    $jssh_socket.send("#{jssh_command}", 0)
                    read_socket()
                when "HTMLDivElement", "HTMLSpanElement"
                    fireEvent("onclick")
                else
                    $jssh_socket.send("#{element_object}.click();\n" , 0)
                    read_socket()
            end
           
            highlight(:clear)
            # Wait for firefox to reload.
            wait()
        end
       
        #
        # Description:
        #   Wait for the browser to get loaded, after the event is being fired.
        #
        def wait
            ff = FireWatir::Firefox.new
            ff.wait()
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
        end

        #
        # Description:
        #   Function is used for click events that generates javascript pop up.
        #   Doesn't fires the click event immediately instead, it stores the state of the object. User then tells which button
        #   is to be clicked in case a javascript pop up comes after clicking the element. Depending upon the button to be clicked
        #   the functions 'alert' and 'confirm' are re-defined in JavaScript to return appropriate values either true or false. Then the
        #   re-defined functions are send to jssh which then fires the click event of the element using the state
        #   stored above. So the click event is fired in the second statement. Therefore, if you are using this function you
        #   need to call 'click_js_popup_button()' function in the next statement to actually trigger the click event.
        #   
        #   Typical Usage:
        #       ff.button(:id, "button").click_no_wait()
        #       ff.click_js_popup_button("OK")
        #
        def click_no_wait
            assert_exists
            assert_enabled

            highlight(:set)
            @@current_js_object = Element.new("#{element_object}")
        end
     
        #
        # Description:
        #   Function to click specified button on the javascript pop up. Currently you can only click
        #   either OK or Cancel button.
        #   Functions alert and confirm are redefined so that it doesn't causes the JSSH to get blocked. Also this 
        #   will make Firewatir cross platform.
        #
        # Input:
        #   button to be clicked
        #
        def click_js_popup(button = "OK")
            jssh_command = "var win = #{BROWSER_VAR}.contentWindow;"
            if(button =~ /ok/i)
                jssh_command += "win.alert = function(param) { return true; };
                                 win.confirm = function(param) { return true; };"
            elsif(button =~ /cancel/i)
                jssh_command += "win.alert = function(param) { return false; };
                                 win.confirm = function(param) { return false; };"
            end
            jssh_command.gsub!("\n", "")
            $jssh_socket.send("#{jssh_command}\n", 0)
            read_socket()
            click_js_popup_creator_button()
            $jssh_socket.send("\n", 0)
            read_socket()
        end

        #
        # Description:
        #   Clicks on button or link or any element that triggers a javascript pop up.
        #   Used internally by function click_js_popup.
        #
        def click_js_popup_creator_button
            #puts @@current_js_object.element_name
            #puts @@current_js_object.element_type
            case @@current_js_object.element_type
                when "HTMLAnchorElement", "HTMLImageElement"
                    jssh_command = "var event = #{DOCUMENT_VAR}.createEvent(\"MouseEvents\");"
                    # Info about initMouseEvent at: http://www.xulplanet.com/references/objref/MouseEvent.html        
                    jssh_command += "event.initMouseEvent('click',true,true,null,1,0,0,0,0,false,false,false,false,0,null);"
                    jssh_command += "#{@@current_js_object.element_name}.dispatchEvent(event);\n"

                    $jssh_socket.send("#{jssh_command}", 0)
                    read_socket()
                when "HTMLDivElement", "HTMLSpanElement"
                    $jssh_socket.send("typeof(#{element_object}.#{event.downcase});\n", 0)
                    isDefined = read_socket()
                    #puts "is method there : #{isDefined}"
                    if(isDefined != "undefined")
                        if(element_type == "HTMLSelectElement")
                            jssh_command = "var event = #{DOCUMENT_VAR}.createEvent(\"HTMLEvents\");
                                            event.initEvent(\"change\", true, true);
                                            #{element_object}.dispatchEvent(event);"
                            jssh_command.gsub!(/\n/, "")
                            $jssh_socket.send("#{jssh_command}\n", 0)
                            read_socket()
                        else
                            $jssh_socket.send("#{element_object}.#{event.downcase}();\n", 0)
                            read_socket()
                        end    
                    end
                else
                    jssh_command = "#{@@current_js_object.element_name}.click();\n";
                    $jssh_socket.send("#{jssh_command}", 0)
                    read_socket()
            end
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
            @@current_js_object = nil
        end
        private :click_js_popup_creator_button
        
        #
        # Description:
        #   Iterate over options if element is of Select type.
        #   Iterate over rows if element is of Table type.
        #   Iterate over cells if element is of TableRow type.
        #
        def each
            if(element_type == "HTMLSelectElement")
                $jssh_socket.send("#{element_object}.options.length;\n", 0)
                length = read_socket().to_i

                for i in 0..length - 1
                    yield Element.new("#{element_object}.options[#{i}]")
                end
            elsif(element_type == "HTMLTableElement")
                $jssh_socket.send("#{element_object}.rows.length;\n", 0)
                length = read_socket().to_i

                for i in 0..length - 1
                    yield Element.new("#{element_object}.rows[#{i}]")
                end    
            elsif(element_type == "HTMLTableRowElement")
                $jssh_socket.send("#{element_object}.cells.length;\n", 0)
                length = read_socket().to_i

                for i in 0..length - 1
                    yield Element.new("#{element_object}.cells[#{i}]")
                end    
            end
        end

        # 
        # Description:
        #   Gets all the options of the select list element.
        #
        # Output:
        #   Array of option elements.
        #
        def options
            assert_exists
            #puts "element name in options is : #{element_object}"
            if(element_type == "HTMLSelectElement")
                $jssh_socket.send("#{element_object}.options.length;\n", 0)
                length = read_socket.to_i
                return_array = Array.new
                for i in 0..length - 1
                    return_array << Element.new("#{element_object}.options[#{i}]")
                end
                return return_array
            else
                puts "The element must be of select type to execute this function."
            end    
        end

        #
        # Description:
        #   Gets all the cells of the row of a table.
        #
        # Output:
        #   Array of table cell elements.
        #
        def cells
            assert_exists
            #puts "element name in cells is : #{element_object}"
            if(element_type == "HTMLTableRowElement")
                $jssh_socket.send("#{element_object}.cells.length;\n", 0)
                length = read_socket.to_i
                return_array = Array.new
                for i in 0..length - 1
                    return_array << Element.new("#{element_object}.cells[#{i}]")
                end
                return return_array
            else
                puts "The element must be of table row type to execute this function."
                return nil
            end
        end

        # 
        # Description:
        #   This method returns the number of columns in a row of the table.
        #   If the element is of type tablerow then, cell count of that row element is returned.
        #   else if element is of type table then, cell count of the row specified by the index 
        #   is returned. By default index is 1.
        # 
        # Input:
        #   index - the index of the row. By default value of index is 1. 
        #
        # Output:
        #   Cell count.
        #
        def column_count(index=1) 
            assert_exists
            if(element_type == "HTMLTableRowElement")
                $jssh_socket.send("#{element_object}.cells.length;\n", 0)
                return read_socket().to_i
            elsif(element_type == "HTMLTableElement")
                # Return the number of columns in first row.
                $jssh_socket.send("#{element_object}.rows[#{index-1}].cells.length;\n", 0)
                return read_socket().to_i
            else
                puts "Element must be of table or table row type to execute this function"
            end
        end
        
        #
        # Description:
        #   Depending on the element type, it returns the value of the element at the specified index i.e. key.
        #   If element is of type select then,the  option element at the specified index is returned. 
        #   If element is of type table then, the row element at the specified index is returned. 
        #   If element is of type tablerow then, the table cell element at the specified index is returned. 
        # 
        # Input:
        #   key - the index of the element to be returned.
        #
        # Output:
        #   Element at the specified index.
        #
        def [](key)
            assert_exists
            #puts "element object is : #{element_object}"
            #puts "#{element_type}"
            #puts "key is #{key}"
            key = key.to_i - 1
            if(element_type == "HTMLSelectElement")
                @@current_element_object = "#{element_object}.options[#{key}]"
                @@current_level += 1
                return Element.new("#{element_object}.options[#{key}]")
            elsif(element_type == "HTMLTableElement")
                @@current_element_object = "#{element_object}.rows[#{key}]"
                @@current_level += 1
                return Element.new("#{element_object}.rows[#{key}]")
            elsif(element_type == "HTMLTableRowElement")
                @@current_element_object = "#{element_object}.cells[#{key}]"
                @@current_level += 1
                return Element.new("#{element_object}.cells[#{key}]")
            end
        end
        
        #
        # Description:
        #   Sets the value of file in HTMLInput file field control.
        #
        # Input:
        #   setPath - location of the file to be uploaded.
        #
        def setFileFieldValue(setPath)
            jssh_command = "var textBox = #{DOCUMENT_VAR}.getBoxObjectFor(#{element_object}).firstChild;"
            jssh_command += "textBox.value = \"#{setPath}\";\n";
            
            #puts jssh_command
            $jssh_socket.send("#{jssh_command}", 0)
            read_socket()
            @@current_element_object = ''
            @@current_frame_name = ''
            @@current_level = 0
        end
        protected :setFileFieldValue

        #
        # Description:
        #   Traps all the function calls for an element that is not defined and fires them again
        #   as it is to the jssh. This can be used in case the element supports properties or methods
        #   that are not defined in the corresponding element class or in the base class(Element).
        #
        # Input:
        #   methodId - Id of the method that is called.
        #   *args - arguments sent to the methods.
        #
	    def method_missing(methId, *args)
	        methodName = methId.id2name
	        #puts "method name is : #{methodName}"
	        methodName = "colSpan" if methodName == "colspan"   
	        if(methodName =~ /invoke/)
	            jssh_command = "#{element_object}."
	            for i in args do
	                jssh_command += i;
	            end
                #puts "#{jssh_command}"
	            $jssh_socket.send("#{jssh_command};\n", 0)
	            return_value = read_socket()
                #puts "return value is : #{return_value}"
                return return_value
	        else
	            #assert_exists
	            #puts "element name is #{element_object}"
    	        
    	        # We get method name with trailing '=' when we try to assign a value to a 
    	        # property. So just remove the '=' to get the type 
                temp = ""
                assingning_value = false
	            if(methodName =~ /(.*)=$/)
	                temp  = "#{element_object}.#{$1}" 
                    assingning_value = true
                else
                    temp = "#{element_object}.#{methodName}"
                end    
	            #puts "temp is : #{temp}"
                
                $jssh_socket.send("typeof(#{temp});\n", 0)
                method_type = read_socket()
                #puts "method_type is : #{method_type}"

                if(assingning_value)
                    if(method_type != "boolean")
                        jssh_command = "#{element_object}.#{methodName}\"#{args[0]}\""
                    else
                        jssh_command = "#{element_object}.#{methodName}#{args[0]}"
                    end    
                    #puts "jssh_command is : #{jssh_command}"
                    $jssh_socket.send("#{jssh_command};\n", 0)
                    read_socket()
                    return
                end

                methodName = "#{element_object}.#{methodName}"
                if(args.length == 0)
                    #puts "In if loop #{methodName}"
                    if(method_type == "function")	        
	                    jssh_command =  "#{methodName}();\n"
	                else
	                    jssh_command =  "#{methodName};\n"
	                end
	            else
	                #puts "In else loop : #{methodName}"
		            jssh_command =  "#{methodName}(" 

		            count = 0
		            if args != nil 
			            for i in args
			                jssh_command += "," if count != 0
				            if i.kind_of? Numeric  
				                jssh_command += i.to_s
				            else
					            jssh_command += "\"#{i.to_s.gsub(/"/,"\\\"")}\""
				            end
				            count = count + 1   
			            end 
		            end

		            jssh_command += ");\n"
	            end

                if(method_type == "boolean")
                    jssh_command = jssh_command.gsub("\"false\"", "false")
                    jssh_command = jssh_command.gsub("\"true\"", "true")
                end
                #puts "jssh_command is #{jssh_command}"
		        $jssh_socket.send("#{jssh_command}", 0)
		        returnValue = read_socket()
		        #puts "return value is : #{returnValue}"
		        
                @@current_element_object = ''
                @@current_frame_name = ''
                @@current_level = 0

		        if(method_type == "boolean")
		            return false if(returnValue == "false")
		            return true if(returnValue == "true")
		        elsif(method_type == "number")
                    return returnValue.to_i
                else    
		            return returnValue
		        end
		    end
	    end
    end

    #
    # Description:
    #   Class for returning the document element.
    #
    class Document < Element
        def initialize(document_name)
            Element.new(document_name)
        end
    end

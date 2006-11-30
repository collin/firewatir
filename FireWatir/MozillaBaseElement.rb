=begin
  license
  ---------------------------------------------------------------------------
  Copyright (c) 2005-2006, Angrez Singh, Abhishek Goliya
  
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
  
  1. Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.
  
  2. Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
  
  3. Neither the names Angrez Singh, Abhishek Goliya nor the names of contributors to
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
        @@current_element_object = ""
        @@current_level = 0 
        # Has the elements array changed.
        @@has_changed = false 
        attr_accessor :element_name
        attr_accessor :element_type
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
                            @@current_level = 0
                            return return_value
                        rescue
                            return ''
                        end
                        
                    end"
        end
        
        # Return an array with many of the properties, in a format to be used by the to_s method
        def string_creator
            n = []
            n <<   "name:".ljust(TO_S_SIZE) +       self.name.to_s
            n <<   "type:".ljust(TO_S_SIZE) + self.type
            n <<   "id:".ljust(TO_S_SIZE) +         self.id.to_s
            n <<   "value:".ljust(TO_S_SIZE) +      self.value.to_s
            n <<   "disabled:".ljust(TO_S_SIZE) +   self.disabled.to_s
            return n
        end
        
        # This method is responsible for setting and clearing the colored highlighting on the currently active element.
        # use :set   to set the highlight
        #   :clear  to clear the highlight
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
       
        public
        
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
                puts "Element must be of table type to execute this function."
            end
        end
        
        # Function to locate the element. Re-implemented here so that we don't have to 
        # make small round-trips via socket to JSSh. Instead write the logic for locating
        # the element in JavaScript and send it to JSSh.
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
                jssh_command += "var value = #{value};"
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
                                        attribute = element.#{how};
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
            #puts "element name in find control is : #{element_name}"
            @@current_level = @@current_level + 1
            if(element_name != "")
                return Element.new(element_name)
            else
                return nil
            end
        end
        
        # Mozilla browser directly supports XPath query on its DOM. So need need to create
        # the DOM tree as we did with IE.
        # Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
        def elements_by_xpath(xpath)
            jssh_command = "var xpathResult = #{DOCUMENT_VAR}.evaluate(\"count(#{xpath})\", #{DOCUMENT_VAR}, null, #{NUMBER_TYPE}, null); xpathResult.numberValue;"
            $jssh_socket.send("#{jssh_command}\n", 0);
            node_count = read_socket()
            #puts "value of count is : #{node_count}"

            jssh_command = "var element_xpath = new Array(" + node_count + ");"

            jssh_command += "var result = #{DOCUMENT_VAR}.evaluate(\"#{xpath}\", #{DOCUMENT_VAR}, null, #{ORDERED_NODE_ITERATOR_TYPE}, null); 
                             var iterate = result.iterateNext();
                             var count = 0;
                             while(iterate)
                             {
                                element_xpath[count] = iterate;
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
                elements[i] = Element.new("element_xpath[#{i}]")
            end

            return elements;
        end

        def element_by_xpath(xpath)
            $jssh_socket.send("var element_xpath = null; element_xpath = #{DOCUMENT_VAR}.evaluate(\"#{xpath}\", #{DOCUMENT_VAR}, null, #{FIRST_ORDERED_NODE_TYPE}, null).singleNodeValue; element_xpath;\n", 0)             
            result = read_socket()
            #puts "result is : #{result}"
            if(result == "null" || result == "" || result.include?("exception"))
                return nil
            else
                @@current_element_object = "element_xpath"
                @@current_level += 1
                return Element.new("element_xpath")
            end
        end

        # This function returns the name of the element with which we can access it in JSSh.
        def element_object
            #puts caller.join("\n")
            #puts "In element_object element name is : #{element_name}"
            return @element_name if @element_name != nil
            return @o.element_name if @o != nil
        end
        
        # This function returns the type of element. For e.g.: HTMLAnchorElement
        def element_type
            return @o.element_type if @o != nil
            return @element_type
        end
        
        # This function returns all the elements that are there in the page document.
        def all
            #puts "Element name in all : #{element_object}"
            if(element_object == BODY_VAR)
                # Standard way of accessing all elements is getElementsByTagName('*'). document.all is IE specific. 
                $jssh_socket.send("var elements = #{element_object}.ownerDocument.getElementsByTagName('*'); \n", 0) #elements.length;\n", 0)
                #length = read_socket().to_i
                
                # Make use of correct document while getting the elements.
                #$jssh_socket.send("doc = #{element_object}.ownerDocument; \n", 0);
                read_socket();
                #puts "length returned by JSSh is : #{length}"
                # Return a array of numbers equal to length.
                #returnArray = Array.new
                #for i in 0..length-1
                #    returnArray.push(Element.new("elements[#{i}]"))
                #end
                #returnArray
                Element.new("elements")
            end
        end
        
        # This function fires event on an element.
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
            @@current_level = 0
        end
        
        # This function returns the value of any attribute of an element.
        def attribute_value(attribute_name)
            
            #puts attribute_name
            assert_exists()
            $jssh_socket.send("#{element_object}.getAttribute(\"#{attribute_name}\");\n" , 0)
            return_value = read_socket()
            @@current_element_object = ''
            @@current_level = 0
            return return_value
        end
        
        # This function checks if element exists or not.
        def assert_exists
            unless exists?
                raise UnknownObjectException.new("Unable to locate object, using #{@how} and #{@what}")
            end
        end
        
        # This function checks if element is enabled or not.
        def assert_enabled
            unless enabled?
                raise ObjectDisabledException, "object #{@how} and #{@what} is disabled"
            end                
        end
        
        def enabled?
            assert_exists
            $jssh_socket.send("#{element_object}.disabled;\n", 0)
            value = read_socket()
            @@current_element_object = '' 
            @@current_level = 0
            return true if(value == "false") 
            return false if(value == "true") 
            return value
        end
        
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
            @@current_level = 0
            if(element_object == nil || element_object == "")
                return false
            else
                return true
            end    
        end
        
        def text(reset = true)
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
            @@current_element_object = '' if reset
            @@current_level = 0 if reset
            return return_value
        end
        alias innerText text
        
        def ole_inner_elements
            assert_exists
            $jssh_socket.send("var inner_elements = #{element_object}.getElementsByTagName('*'); inner_elements.length;\n", 0)
            length = read_socket().to_i;
            
            returnArray = Array.new
            for i in 0..length - 1
                returnArray.push(Element.new("inner_elements[#{i}]"))
            end
            returnArray
        end
        private :ole_inner_elements

        def document
            assert_exists
            return element_object
        end
        
        # returns the name of the element (as defined in html)
        def_wrap :name
        # returns the id of the element
        def_wrap :id
        # returns whether the element is disabled
        def_wrap :disabled 
        alias disabled? disabled
        # returns the state of the element
        def_wrap :checked
        #alias checked? checked
        # returns the value of the element
        def_wrap :value
        # returns the title of the element
        def_wrap :title
        
        def_wrap :alt
        def_wrap :src
        
        # returns the type of the element
        def_wrap :type # input elements only        

        # returns the url the link points to
        def_wrap :href # link only

        # return the ID of the control that this label is associated with
        def_wrap :for, :htmlFor # label only
        
        # returns the class name of the element
        # raises an ObjectNotFound exception if the object cannot be found
        def_wrap :class_name, :className

        # Return the outer html of the object - see http://msdn.microsoft.com/workshop/author/dhtml/reference/properties/outerhtml.asp?frame=true
        def_wrap :html, :outerHTML
        
        #return the inner text of the object
        #def_wrap :text
        
        
        # Display basic details about the object. Sample output for a button is shown.
        # Raises UnknownObjectException if the object is not found.
        #      name      b4
        #      type      button
        #      id         b5
        #      value      Disabled Button
        #      disabled   true
        def to_s
            #puts "here in to_s"
            assert_exists
            if(element_type == "HTMLTableCellElement")
                return text(false)
            end
            @@current_element_object = '' 
            @@current_level = 0
            return string_creator #.join("\n")
        end
        
        # Function to fire click events on elements.  
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
       
        def wait
            ff = FireWatir::Firefox.new
            ff.wait()
            @@current_element_object = ''
            @@current_level = 0
        end

        # Function that doesn't wait after clicking. Useful when click function opens a new
        # javascript pop up. Creates a new socket and then clicks the button. Old socket remains
        # as it is. So that processing can be continued.
        def click_no_wait
            assert_exists
            assert_enabled

            highlight(:set)
            
            case element_type
                when "HTMLAnchorElement", "HTMLImageElement"
                    jssh_command = "var event = document.createEvent(\"MouseEvents\");"
                    # Info about initMouseEvent at: http://www.xulplanet.com/references/objref/MouseEvent.html        
                    jssh_command += "event.initMouseEvent('click',true,true,null,1,0,0,0,0,false,false,false,false,0,null);"
                    jssh_command += "#{element_object}.dispatchEvent(event);\n"

                    $jssh_socket.send("#{jssh_command}", 0)
                    #read_socket()
                when "HTMLDivElement", "HTMLSpanElement"
                    fireEvent("onclick", false)
                else
                    jssh_command = "#{element_object}.click();\n";
                    $jssh_socket.send("#{jssh_command}", 0)
                    #read_socket()
            end
            @@current_element_object = ''
            @@current_level = 0
        end
       
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

        # Used by select list object. 
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

        # Used by Table row object.
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
            end
        end

        # This method returns the number of columns in a row of the table.
        # Raises an UnknownObjectException if the table doesn't exist.
        #   * index         - the index of the row
        def column_count(index=1) 
            assert_exists
            if(element_type == "HTMLTableRowElement")
                $jssh_socket.send("#{element_object}.cells.length;\n", 0)
                return read_socket().to_i
            elsif(element_type == "HTMLTableElement")
                # Return the number of columns in first row.
                $jssh_socket.send("#{element_object}.rows[0].cells.length;\n", 0)
                return read_socket().to_i
            else
                puts "Element must be of table or table row type to execute this function"
            end
        end
        
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
        
        # Function to set the value of file in HTMLInput file control.
        def setFileFieldValue(setPath)
            jssh_command = "textBox = #{DOCUMENT_VAR}.getBoxObjectFor(#{element_object}).firstChild;"
            jssh_command += "textBox.value = \"#{setPath}\";\n";
            
            #puts jssh_command
            $jssh_socket.send("#{jssh_command}", 0)
            read_socket()
            @@current_element_object = ''
            @@current_level = 0
        end
        
        # This method will trap all the function calls for an element & fires them again 
        # through JSSh & element name.
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
    
    # Class for body element.
    class Body < Element
    end
    
    # Class for page document.
    class Document < Element
        def getElementsByTagName(tag)
            jssh_command = "var elements = #{DOCUMENT_VAR}.getElementsByTagName('#{tag}');"
            #puts "helrlej"
            jssh_command += "elements.length;\n"
            
            $jssh_socket.send("#{jssh_command}", 0)
            length = read_socket().to_i
            
            #puts "JSSh command is : #{jssh_command}"
            #puts "Number of elements with #{tag} tag is : #{length}"
            # Return a array of numbers equal to length.
            returnArray = Array.new
            for i in 0..length - 1
                returnArray.push(Element.new("elements[#{i}]"))
            end
            returnArray
                
        end
        
        def body
            Body.new("#{BODY_VAR}")
        end
    end
    

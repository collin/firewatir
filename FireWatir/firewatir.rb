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

=begin rdoc
   This is FireWatir, Web Application Testing In Ruby using Firefox browser
   The home page for this project is http://code.google.com/p/firewatir

   Typical usage:
    # include the controller
    require "firewatir"

    # go to the page you want to test
    ff = FireWatir::Firefox.start("http://myserver/mypage")

    # enter "Angrez" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ff.button(:value, "Cancel").click

   FireWatir allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that FireWatir can identify
   include:

   Type         Description
   ===========  ===============================================================
   button       <input> tags, with the type="button" attribute
   check_box    <input> tags, with the type="checkbox" attribute
   div          <div> tags
   form
   frame
   hidden       hidden <input> tags
   image        <img> tags
   label
   link         <a> (anchor) tags
   p            <p> (paragraph) tags
   radio        radio buttons; <input> tags, with the type="radio" attribute
   select_list  <select> tags, known informally as drop-down boxes
   span         <span> tags
   table        <table> tags
   text_field   <input> tags with the type="text" attribute (a single-line
                text field), the type="text_area" attribute (a multi-line
                text field), and the type="password" attribute (a
                single-line field in which the input is replaced with asterisks)

   In general, there are several ways to identify a specific object.  FireWatir's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that FireWatir will seek, as shown in the examples above.  Available "how"
   options depend upon the type of object, but here are a few examples:

   How           Description
   ============  ===============================================================
   :id           Used to find an object that has an "id=" attribute. Since each
                 id should be unique, according to the XHTML specification,
                 this is recommended as the most reliable method to find an
                 object.
   :name         Used to find an object that has a "name=" attribute.  This is
                 useful for older versions of HTML, but "name" is deprecated
                 in XHTML.
   :value        Used to find a text field with a given default value, or a
                 button with a given caption
   :index        Used to find the nth object of the specified type on a page.
                 For example, button(:index, 2) finds the second button.
                 Current versions of WATIR use 1-based indexing, but future
                 versions will use 0-based indexing.
   :xpath	     The xpath expression for identifying the element.
   
   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  FireWatir doesn't enforce this; FireWatir will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   FireWatir uses JSSh for interacting with the browser.  For further information on 
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/
   
=end

require 'firewatir/exceptions'
require 'container'
require 'MozillaBaseElement.rb'
require 'htmlelements.rb'
require 'socket'

class String
    def matches (x)
        return self == x
    end
end

class Regexp
    def matches (x)
        return self.match(x) 
    end
end

class Integer
    def matches (x)
        return self == x
    end
end

module FireWatir
    include FireWatir::Exception
    
    class Firefox
       
        include Container
        
        # XPath Result type. Return only first node that matches the xpath expression.
        # More details: "http://developer.mozilla.org/en/docs/DOM:document.evaluate"
        FIRST_ORDERED_NODE_TYPE = 9

        # variable to check if firefox browser has been started or not. Currently this is
        # used only while starting firefox on windows. For other platforms you need to start
        # firefox manually.
        @@firefox_started = false

        # variable to check if connection has been established or not.
        @@connection_established = false

        # This allows us to identify the window uniquely and close them accordingly.
        @window_title = nil 
        @window_url = nil 
                                                
        #
        # Description: 
        #   Starts the firefox browser. Currently this only works for Windows Platform.
        #   For others, you need to start Firefox manually using -jssh option.
        #   On windows this starts the first version listed in the registry.
        # 
        # Input:
        #   waitTime - Time to wait for Firefox to start. By default it waits for 2 seconds.
        #              This is done because if Firefox is not started and we try to connect
        #              to jssh on port 9997 an exception is thrown.

        # TODO: Start the firefox version given by user. For example 
        #       ff = FireWatir::Firefox.new("1.5.0.4")
        #
        def initialize(waitTime = 2)
            if(RUBY_PLATFORM =~ /.*mswin.*/)
                if( ! @@firefox_started )

                    #puts "plaftorm is windows"
                    # Get the path to Firefox.exe using Registry.
                    require 'win32/registry.rb'
                    path_to_exe = ""
                    Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\Mozilla\Mozilla Firefox') do |reg|
                        keys = reg.keys
                        reg1 = Win32::Registry::HKEY_LOCAL_MACHINE.open("SOFTWARE\\Mozilla\\Mozilla Firefox\\#{keys[0]}\\Main")
                        reg1.each do |subkey, type, data|
                            if(subkey =~ /pathtoexe/i)
                                path_to_exe = data
                            end
                        end
                    end

                    puts "Starting Firefox using the executable : #{path_to_exe}"
                    puts "Waiting for #{waitTime} seconds for Firefox to get started."
                    Thread.new { system("\"#{path_to_exe}\" -jssh") }
                    sleep waitTime
                    @@firefox_started = true
                end
            end       
            
            if(@@connection_established == false)
                set_defaults()
            end
            #get_window_number()
            #set_browser_document()
        end

        #
        # Description:
        # Creates a new instance of Firefox. Loads the URL and return the instance.
        #
        # Input:
        #   url - url of the page to be loaded.
        #
        # Output:
        #   New instance of firefox browser with the given url loaded.
        #
        def self.start(url)
            ff = Firefox.new
            ff.goto(url)
            return ff
        end

        #
        # Description:
        #   Gets the window number opened. Used internally by Firewatir.
        #
        def get_window_number()
            $jssh_socket.send("getWindows().length;\n", 0)
            @@current_window = read_socket().to_i - 1
            # This will store the information about the window.
            @@window_stack = Array.new
            #@@window_stack.push(@@current_window)
            #puts "here in get_window_number window number is #{@@current_window}"
            return @@current_window
        end
        private :get_window_number

        #
        # Description:
        #   Loads the given url in the browser. Waits for the page to get loaded.
        #
        # Input:
        #   url - url to be loaded.
        #
        def goto(url)
            #set_defaults()
            get_window_number()
            set_browser_document()
            # Load the given url.
            $jssh_socket.send("#{BROWSER_VAR}.loadURI(\"#{url}\");\n" , 0)
            read_socket()

            wait()
        end
        
        #
        # Description: 
        #   Loads the previous page (if there is any) in the browser. Waits for the page to get loaded.
        #
        def back()
            #set_browser_document()
            $jssh_socket.send("if(#{BROWSER_VAR}.canGoBack) #{BROWSER_VAR}.goBack();\n", 0)
            read_socket();
            wait()
        end

        #
        # Description:
        #   Loads the next page (if there is any) in the browser. Waits for the page to get loaded.
        #
        def forward()
            #set_browser_document()
            $jssh_socket.send("if(#{BROWSER_VAR}.canGoForward) #{BROWSER_VAR}.goForward();\n", 0)
            read_socket();
            wait()
        end
        
        #
        # Description:
        #   Reloads the current page in the browser. Waits for the page to get loaded.
        #
        def refresh()
            #set_browser_document()
            $jssh_socket.send("#{BROWSER_VAR}.reload();\n", 0)
            read_socket();
            wait()
        end
        
        #
        # Description:
        #   This function creates a new socket at port 9997 and sets the default values for instance and class variables.
        #   Generates error message if cannot connect to jssh and exits the current process.
        #
        def set_defaults
            # JSSH listens on port 9997. Create a new socket to connect to port 9997.
            begin
                $jssh_socket = TCPSocket::new(MACHINE_IP, "9997")
                $jssh_socket.sync = true
                read_socket()
                @@connection_established = true
            rescue
                puts "Unable to connect to machine : #{MACHINE_IP} on port 9997. Make sure that JSSh is properly installed and Firefox is running with '-jssh' option"
                exit
            end
        end
        private :set_defaults
 
        def set_slow_speed
            @typingspeed = DEFAULT_TYPING_SPEED
            @defaultSleepTime = DEFAULT_SLEEP_TIME
        end
        private :set_slow_speed
        
        #
        # Description:
        #   Sets the document, window and browser variables to point to correct object in JSSh.
        #
        def set_browser_document
            # Get the window in variable WINDOW_VAR.
            # Get the browser in variable BROWSER_VAR.
            jssh_command = "var #{WINDOW_VAR} = getWindows()[#{@@current_window}];"
            jssh_command += " var #{BROWSER_VAR} = #{WINDOW_VAR}.getBrowser();"
            # Get the document and body in variable DOCUMENT_VAR and BODY_VAR respectively.
            jssh_command += "var #{DOCUMENT_VAR} = #{BROWSER_VAR}.contentDocument;"
            jssh_command += "var #{BODY_VAR} = #{DOCUMENT_VAR}.body;"

            $jssh_socket.send("#{jssh_command}\n", 0)
            read_socket()

            # Get window and window's parent title and url
            $jssh_socket.send("#{DOCUMENT_VAR}.title;\n", 0)
            @window_title = read_socket()
            $jssh_socket.send("#{DOCUMENT_VAR}.URL;\n", 0)
            @window_url = read_socket()
        end
        private :set_browser_document
        
        #
        # Description:
        #   Closes the window.
        #
        def close()
            #puts "current window number is : #{@@current_window}"
            if @@current_window == 0
                $jssh_socket.send(" getWindows()[0].close(); \n", 0)
            else
                # Check if window exists, because there may be the case that it has been closed by click event on some element.
                # For e.g: Close Button, Close this Window link etc.
                window_number = find_window("url", @window_url)

                # If matching window found. Close the window.
                if(window_number > 0)
                    $jssh_socket.send(" getWindows()[#{window_number}].close();\n", 0)
                    read_socket();
                end    
                
                #Get the parent window url from the stack and return that window.
                #@@current_window = @@window_stack.pop()
                @window_url = @@window_stack.pop()
                @window_title = @@window_stack.pop()
                # Find window with this url.
                window_number = find_window("url", @window_url)
                @@current_window = window_number
                set_browser_document()
            end
        end
       
        #
        # Description:
        #   Used for attaching pop up window to an existing Firefox window, either by url or title.
        #   ff.attach(:url, 'http://www.google.com')
        #   ff.attach(:title, 'Google') 
        #
        # Output:
        #   Instance of newly attached window.
        #
        def attach(how, what)
            window_number = find_window(how, what)

            if(window_number == 0)
               raise NoMatchingWindowFoundException.new("Unable to locate window, using #{how} and #{what}")  
            elsif(window_number > 0)
                # Push the window_title and window_url of parent window. So that when we close the child window
                # appropriate handle of parent window is returned back.
                @@window_stack.push(@window_title)
                @@window_stack.push(@window_url)

                @@current_window = window_number.to_i
                set_browser_document()
            end    
            self
        end

        #
        # Description:
        #   Finds a Firefox browser window with a given title or url.
        #
        def find_window(how, what)
            jssh_command = "getWindows().length;";
            $jssh_socket.send("#{jssh_command}\n", 0)
            @@total_windows = read_socket()
            #puts "total windows are : " + @@total_windows.to_s

            jssh_command =  "var windows = getWindows(); var window_number = 0;var found = false;
                             for(var i = 0; i < windows.length; i++)
                             {
                                var attribute = '';
                                if(\"#{how}\" == \"url\")
                                {
                                    attribute = windows[i].getBrowser().contentDocument.URL;
                                }
                                if(\"#{how}\" == \"title\")
                                {
                                    attribute = windows[i].getBrowser().contentDocument.title;
                                }"
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
                
                jssh_command += "var regExp = new RegExp(#{newRegExp});
                                 found = regExp.test(attribute);"
            else
                jssh_command += "found = (attribute == \"#{what}\");"
            end
            
            jssh_command +=     "if(found)
                                {
                                    window_number = i;
                                    break;
                                }
                            }
                            window_number;"
                            
            jssh_command.gsub!(/\n/, "")
            #puts "jssh_command is : #{jssh_command}"
            $jssh_socket.send("#{jssh_command}\n", 0)
            window_number = read_socket()
            #puts "window number is : " + window_number.to_s

            return window_number.to_i
        end
        private :find_window
        
        #
        # Description:
        #   Matches the given text with the current text shown in the browser.
        #
        def contains_text(match_text)
            #puts "Text to match is : #{match_text}"
            #puts "Html is : #{self.text}"
            #puts match_text.matches(self.text)
            #puts caller(0)
            if(match_text.matches(self.text) == nil || match_text.matches(self.text) == false)
                return false
            else
                return true
            end    
            #return match_text.matches(self.text) # == nil) ? false : true
        end

        #
        # Description:
        #   Returns the url of the page currently loaded in the browser.
        #
        # Output:
        #   URL of the page.
        #
        def url()
            @window_url
        end 

        #
        # Description:
        #   Returns the title of the page currently loaded in the browser.
        #
        # Output:
        #   Title of the page.
        #
        def title()
            @window_title
        end

        #
        # Description:
        #   Returns the html of the page currently loaded in the browser.
        #
        # Output:
        #   HTML shown on the page.
        #
        def html()
            $jssh_socket.send("var htmlelem = #{DOCUMENT_VAR}.getElementsByTagName('html')[0]; htmlelem.innerHTML;\n", 0)
            #$jssh_socket.send("#{BODY_VAR}.innerHTML;\n", 0)
            return read_socket()
        end

        #
        # Description:
        #   Returns the text of the page currently loaded in the browser.
        #
        # Output:
        #   Text shown on the page.
        #
        def text()
            $jssh_socket.send("#{BODY_VAR}.textContent;\n", 0)
            return read_socket().strip
        end
        
        #
        # Description:
        #   Maximize the current browser window.
        #
        def maximize()
            $jssh_socket.send("#{WINDOW_VAR}.maximize();\n", 0)
            read_socket()
        end

        #
        # Description:
        #   Minimize the current browser window.
        #
        def minimize()
            $jssh_socket.send("#{WINDOW_VAR}.minimize();\n", 0)
            read_socket()
        end

        #
        # Description:
        #   Waits for the page to get loaded.
        #
        def wait()
            #puts "In wait function "
            isLoadingDocument = ""
            while isLoadingDocument != "false"
                $jssh_socket.send("#{BROWSER_VAR}=#{WINDOW_VAR}.getBrowser(); #{BROWSER_VAR}.webProgress.isLoadingDocument;\n" , 0)
                isLoadingDocument = read_socket()
                #puts "Is browser still loading page: #{isLoadingDocument}"
            end

            # Check for Javascript redirect. As we are connected to Firefox via JSSh. JSSh
            # doesn't detect any javascript redirects so check it here.
            # If page redirects to itself that this code will enter in infinite loop.
            # So we currently don't wait for such a page.
            # wait variable in JSSh tells if we should wait more for the page to get loaded
            # or continue. -1 means page is not redirected. Anyother positive values means wait.
            jssh_command = "var wait = -1; var meta = null; meta = #{BROWSER_VAR}.contentDocument.getElementsByTagName('meta');
                            if(meta != null)
                            {
                                var doc_url = #{BROWSER_VAR}.contentDocument.URL;
                                for(var i=0; i< meta.length;++i)
                                {
									var content = meta[i].content;
									var regex = new RegExp(\"^refresh$\", \"i\");
									if(regex.test(meta[i].httpEquiv))
									{
										var arrContent = content.split(';');
										var redirect_url = null;
										if(arrContent.length > 0)
										{
											if(arrContent.length > 1)
												redirect_url = arrContent[1];
	                                        
											if(redirect_url != null)
											{
												regex = new RegExp(\"^.*\" + redirect_url + \"$\");
												if(!regex.test(doc_url))
												{
													wait = arrContent[0];
												}
											}
											break;
										}
									}
								}
                            }
                            wait;"
            #puts "command in wait is : #{jssh_command}"                
            jssh_command = jssh_command.gsub(/\n/, "")
            $jssh_socket.send("#{jssh_command}; \n", 0)
            wait_time = read_socket();
            #puts "wait time is : #{wait_time}"
            begin
                wait_time = wait_time.to_i
                if(wait_time != -1)
                    sleep(wait_time)
                    # Call wait again. In case there are multiple redirects.
                    $jssh_socket.send("#{BROWSER_VAR} = #{WINDOW_VAR}.getBrowser(); \n",0)
                    read_socket()
                    wait()
                end    
            rescue
            end
            set_browser_document()
        end
      
        #def jspopup_appeared(popupText = "", wait = 2)
        #    winHelper = WindowHelper.new()
        #    return winHelper.hasPopupAppeared(popupText, wait)
        #end
 
        #
        # Description:
        #   Redefines the alert and confirm methods on the basis of button to be clicked.
        #   This is done so that JSSh doesn't get blocked. You should use click_no_wait method before calling this function.
        #
        #   Typical Usage:
        #   ff.button(:id, "button").click_no_wait
        #   ff.click_jspopup_button("OK")
        #
        # Input:
        #   button - JavaScript button to be clicked. Values can be OK or Cancel
        #
        def click_jspopup_button(button)
            button = button.downcase
            element = Element.new(nil)
            element.click_js_popup(button)
        end

        #
        # Description:
        #   Returns the document element of the page currently loaded in the browser.
        #
        # Output:
        #   Document element.
        #
        def document
             Document.new("#{DOCUMENT_VAR}")
        end
       
        #
        # Description:
        #   Returns the first element that matches the xpath query.
        #
        # Input:
        #   Xpath expression or query.
        #
        # Output:
        #   Element matching the xpath query.
        #
        def element_by_xpath(xpath)
            element = Element.new(nil, self)
            return element.element_by_xpath(self, xpath)
        end

        #
        # Description:
        #   Returns the array of elements that matches the xpath query.
        #
        # Input:
        #   Xpath expression or query.
        #
        # Output:
        #   Array of elements matching xpath query.
        #
        def elements_by_xpath(xpath)
            element = Element.new(nil, self)
            return element.elements_by_xpath(self, xpath)
        end

    end # Class Firefox

    # 
    # Module for handling the Javascript pop-ups. Not in use currently. Will be available in future.    
    # Use ff.click_jspopup_button(button) for clicking javascript pop ups
    # POPUP object
    module Dialog
        class JSPopUp
            include Container
            
            def has_appeared(text)
                require 'socket' 
                sleep 4 
                shell = TCPSocket.new("localhost", 9997)
                read_socket(shell)
                #jssh_command =  "var url = #{DOCUMENT_VAR}.URL;"
                jssh_command = "var length = getWindows().length; var win;length;\n"
                #jssh_command += "for(var i = 0; i < length; i++)"
                #jssh_command += "{"
                #jssh_command += "   win = getWindows()[i];"
                #jssh_command += "   if(win.opener != null && "
                #jssh_command += "      win.title == \"[JavaScript Application]\" &&"
                #jssh_command += "      win.opener.document.URL == url)"
                #jssh_command += "   {"
                #jssh_command += "       break;"
                #jssh_command += "   }"
                #jssh_command += "}"
                
                #jssh_command += " win.title;\n";
                #jssh_command += "var dialog = win.document.childNodes[0];"
                #jssh_command += "vbox = dialog.childNodes[1].childNodes[1];"
                #jssh_command += "vbox.childNodes[1].childNodes[0].childNodes[0].textContent;\n"
                puts jssh_command 
                shell.send("#{jssh_command}", 0)
                jstext = read_socket(shell)
                puts jstext
                return jstext == text
            end
        end
    end       

end

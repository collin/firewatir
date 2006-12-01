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

=begin rdoc
   This is FireWatir, Web Application Testing In Ruby for Firefox browser
   The home page for this project is is http://code.google.com/p/firewatir

   Typical usage:
    # include the controller
    require "firewatir"

    # go to the page you want to test
    ff = FireWatir::Firefox.start("http://myserver/mypage")

    # enter "Paul" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ie.button(:value, "Cancel").click

   FireWATIR allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that FireWATIR can identify
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

   In general, there are several ways to identify a specific object.  FireWATIR's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that FireWATIR will seek, as shown in the examples above.  Available "how"
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
   :xpath	The xpath expression for identifying the element.
   
   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  FireWATIR doesn't enforce this; FireWATIR will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   FireWATIR uses JSSh for interacting with the browser element.  For further information on 
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/
   
=end

# Use our modified win32ole library
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), 'watir', 'win32ole')

require 'logger'
require 'firewatir/winClicker'
require 'firewatir/WindowHelper'
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

# ARGV needs to be deleted to enable the Test::Unit functionality that grabs
# the remaining ARGV as a filter on what tests to run.
# Note: this means that watir must be require'd BEFORE test/unit.
def command_line_flag(switch)
    setting = ARGV.include?(switch) 
    ARGV.delete(switch)
    return setting
end            

# Constant to make Internet explorer minimise. -b stands for background
$HIDE_IE = command_line_flag('-b') 

# Constant to enable/disable the spinner
$ENABLE_SPINNER = command_line_flag('-x') 

# Constant to set fast speed
$FAST_SPEED = command_line_flag('-f')

# Eat the -s command line switch (deprecated)
command_line_flag('-s')

module FireWatir
    include FireWatir::Exception
    
    @@dir = File.expand_path(File.dirname(__FILE__))

    def self.until_with_timeout(timeout) # block
        start_time = Time.now
        until yield or Time.now - start_time > timeout do
            sleep 0.05
        end
    end

    def self.avoids_error(error) # block
        begin
            yield
            true
        rescue error
            false
        end
    end
    
    # BUG: this won't work right until the null objects are pulled out
    def exists?
        begin
            yield
            true
        rescue
            false
        end
    end

    class FireWatirLogger < Logger
        def initialize(  filName , logsToKeep, maxLogSize )
            super( filName , logsToKeep, maxLogSize )
            self.level = Logger::DEBUG
            self.datetime_format = "%d-%b-%Y %H:%M:%S"
            self.debug("FireWatir starting")
        end
    end
    
    class DefaultLogger < Logger
        def initialize()
            super(STDERR)
            self.level = Logger::WARN
            self.datetime_format = "%d-%b-%Y %H:%M:%S"
            self.info "Log started"
        end
    end
    
    # Displays the spinner object that appears in the console when a page is being loaded
    class Spinner
        def initialize(enabled = true)
            @s = [ "\b/" , "\b|" , "\b\\" , "\b-"]
            @i=0
            @enabled = enabled
        end
        
        # reverse the direction of spinning
        def reverse
            @s.reverse!
        end
        
        def spin
            print self.next if @enabled
        end

        # get the next character to display
        def next
            @i=@i+1
            @i=0 if @i>@s.length-1
            return @s[@i]
        end
    end

    class Firefox
       
        include Container
        
        # XPath Result type. Return only first node that matches the xpath expression.
        # More details: "http://developer.mozilla.org/en/docs/DOM:document.evaluate"
        FIRST_ORDERED_NODE_TYPE = 9
        
        def initialize(requireSocket = true)
        end

        def goto(url)

            set_defaults()
            set_browser_document()
            # Load the given url.
            $jssh_socket.send("#{BROWSER_VAR}.loadURI(\"#{url}\");\n" , 0)
            read_socket()

            wait()
        end
      
        def back()
            set_browser_document()
            $jssh_socket.send("if(#{BROWSER_VAR}.canGoBack) #{BROWSER_VAR}.goBack()\n", 0)
            read_socket();
            wait()
            
            set_browser_document()
            set_browser_document()
        end

        def forward()
            set_browser_document()
            $jssh_socket.send("if(#{BROWSER_VAR}.canGoForward) #{BROWSER_VAR}.goForward()\n", 0)
            read_socket();
            wait()

            set_browser_document()
        end
        

        def reload()
            set_browser_document()
            $jssh_socket.send("#{BROWSER_VAR}.relaod();\n", 0)
            read_socket();
            wait()

            set_browser_document()
        end
        
        def set_defaults
            
            # JSSH listens on port 9997. Create a new socket to connect to port 9997.
            $jssh_socket = TCPSocket::new(MACHINE_IP, "9997")
            $jssh_socket.sync = true
            read_socket()
            @@current_window = 0
            @@already_closed = false
            @@total_windows = 1
            # This will store the information about the window.
            @@window_stack = Array.new
            @@window_stack.push(0)
            @jspopup_handle = nil
            
        end
 
        def set_slow_speed
            @typingspeed = DEFAULT_TYPING_SPEED
            @defaultSleepTime = DEFAULT_SLEEP_TIME
        end
        
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
        end
        
        def close()
            # This is the case if some click event has closed the window. Click() function sets the variable
            # alread_closed as true. So in that case just return.
            if @@already_closed
                @@already_closed = false
                return
            end
            
            if @@current_window == 0
                #$jssh_socket.send(" getWindows()[0].close(); \n", 0)
            else
                $jssh_socket.send(" getWindows()[#{@@current_window}].close();\n", 0)
                read_socket();
                @@current_window = @@window_stack.pop()
                set_browser_document()
            end
        end
       
        # Attach to an existing IE window, either by url or title.
        # Firefox.attach(:url, 'http://www.google.com')
        # Firefox.attach(:title, 'Google') 
        # TODO: Add support to attach using url. Currently only Title is supported.
        def attach(how, what)
            find_window(what)
        end

        def find_window(title)
            jssh_command = "getWindows().length;";
            $jssh_socket.send("#{jssh_command}\n", 0)
            @@total_windows = read_socket()
            #puts "total windows are : " + @@total_windows.to_s

            jssh_command =  "var windows = getWindows(); var window_number = 0;"
            jssh_command += "for(var i = 0; i < windows.length; i++)"
            jssh_command += "{"
            jssh_command += "   var title = windows[i].getBrowser().contentDocument.title;"
            jssh_command += "   if(title == \"#{title}\")"
            jssh_command += "   {"
            jssh_command += "       window_number = i;"
            jssh_command += "       break;"
            jssh_command += "   }"
            jssh_command += "}"
            jssh_command += "window_number;"

            $jssh_socket.send("#{jssh_command}\n", 0)
            window_number = read_socket()
            #puts "window number is : " + window_number.to_s

            if(window_number.to_i > 0)
                @@window_stack.push(@@current_window)
                @@current_window = window_number.to_i
                set_browser_document()
            end    
            self
        end
        private :find_window
        
        def contains_text(match_text)
            #puts "Text to match is : #{match_text}"
            #puts "Html is : #{self.text}"
            return (match_text.match(self.text) == nil) ? false : true
        end

        def url()
            $jssh_socket.send("#{DOCUMENT_VAR}.URL;\n", 0)
            return read_socket()
        end 

        def title()
            $jssh_socket.send("#{DOCUMENT_VAR}.title;\n", 0)
            return read_socket()
        end

        def text()
            $jssh_socket.send("#{BODY_VAR}.innerHTML;\n", 0)
            return read_socket()
        end

        def maximize()
            $jssh_socket.send("#{WINDOW_VAR}.maximize();\n", 0)
            read_socket()
        end

        def minimize()
            $jssh_socket.send("#{WINDOW_VAR}.minimize();\n", 0)
            read_socket()
        end

        def wait(no_sleep = false)
            #puts "In wait function "
            isLoadingDocument = ""
            while isLoadingDocument != "false"
                $jssh_socket.send("#{BROWSER_VAR}.webProgress.isLoadingDocument;\n" , 0)
                isLoadingDocument = read_socket()
                #puts "Is browser still loading page: #{isLoadingDocument}"
            end
            set_browser_document()
        end
      
        def jspopup_appeared(popupText = "", wait = 2)
            winHelper = WindowHelper.new()
            return winHelper.hasPopupAppeared(popupText, wait)
        end
 
        def click_jspopup_button(button)
            #winclicker = WinClicker.new

            #if button =~ /ok/i
            #    winclicker.clickWindowsButton_hwnd(@jspopup_handle, "OK")
            #elsif button =~ /cancel/i
            #    winclicker.clickWindowsButton_hwnd(@jspopup_handle, "Cancel")
            #end
            winHelper = WindowHelper.new()
            if button =~ /ok/i
                puts "ok: clicking button #{button}"
                winHelper.push_confirm_button_ok()
            elsif button =~ /cancel/i
                puts "cancel: clicking button #{button}"
                winHelper.push_confirm_button_cancel()
            end
            read_socket()
        end 
               
        def document
             Document.new("#{DOCUMENT_VAR}")
        end
       
        def element_by_xpath(xpath)
            element = Element.new(nil)
            return element.element_by_xpath(xpath)
        end

    end # Class Firefox

    # 
    # Module for handling the Javascript pop-ups. Not is use currently. Will be available in future.    
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

require 'win32ole'

class WindowHelper
    def initialize( )
        @autoit = WIN32OLE.new('AutoItX3.Control')
    end
    
    def push_alert_button()
        @autoit.WinWait "[JavaScript Application]", ""
        
        #text = @autoit.WinGetText("[JavaScript Application]")
        @autoit.WinActivate("[JavaScript Application]")
        #@autoit.WinSetState("[JavaScript Application]", text, @SW_MAXIMIZE)
        
        @autoit.Send "{ENTER}"
    end
    
    def push_confirm_button_ok()
        @autoit.WinWait "[JavaScript Application]" , ""
        
        @autoit.WinActivate("[JavaScript Application]")
        @autoit.sleep(10)
        #sleep 0.5
        @autoit.Send "{ENTER}"
    end
    
    def push_confirm_button_cancel()
        @autoit.WinWait "[JavaScript Application]", ""
        
        @autoit.WinActivate("[JavaScript Application]")
        
        @autoit.sleep(10)
        #sleep 0.5
        @autoit.Send "{ESCAPE}"
    end
    
    def push_security_alert_yes()
        @autoit.WinWait "Security Alert", ""
        
        text = @autoit.WinGetText("[JavaScript Application]")
        @autoit.WinSetState("[JavaScript Application]", text, @SW_RESTORE)
        @autoit.Send "{TAB}"
        @autoit.Send "{TAB}"
        @autoit.Send "{SPACE}"
    end
        
    def logon(title,name = 'john doe',password = 'john doe')
        @autoit.WinWait title, ""
        @autoit.Send name
        @autoit.Send "{TAB}"
        @autoit.Send password
        @autoit.Send "{ENTER}"
    end
    
    def hasPopupAppeared(text = "" , wait = "")
        return @autoit.WinWait("JavaScript Application",text, wait)
    end
    
    def WindowHelper.check_autoit_installed
        begin
            WIN32OLE.new('AutoItX3.Control')
        rescue
            raise Watir::Exception::WatirException, "The AutoIt dll must be correctly registered for this feature to work properly"
        end
    end
end



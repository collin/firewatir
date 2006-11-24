$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') if $0 == __FILE__
require 'unittests/setup'

class TC_JavaScript_Test < Test::Unit::TestCase
    include FireWatir
    include FireWatir::Dialog
    
    def setup
        $ff.goto($htmlRoot  + 'JavascriptClick.html')
    end
    
    def test_alert
        $ff.button(:id, "btnAlert").click_no_wait()

        if($ff.jspopup_appeared("Press OK"))
            puts "Javascript alert appeared"
            $ff.click_jspopup_button("OK")
            assert_equal($ff.text_field(:id, "testResult").value , "You pressed the Alert button!")
        end
    end
    
    def test_confirm_ok
        $ff.button(:id, "btnConfirm").click_no_wait()
        
        if($ff.jspopup_appeared("Press a button"))
            puts "Javascript confirm dialog appeared"
            $ff.click_jspopup_button("OK")
            assert_equal($ff.text_field(:id, "testResult").value , "You pressed the Confirm and OK button!")
        else
            puts "No Javascript confirm dialog appeared"
        end
    end
    
    def test_confirm_cancel
        $ff.button(:id, "btnConfirm").click_no_wait()
        
        if($ff.jspopup_appeared("Press a button"))
            puts "Javascript confirm dialog appeared"
            $ff.click_jspopup_button("Cancel")
            assert_equal($ff.text_field(:id, "testResult").value, "You pressed the Confirm and Cancel button!")
        else
            puts "No Javascript confirm dialog appeared"
        end
    end
end

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

        $ff.click_jspopup_button("OK")
        assert_equal($ff.text_field(:id, "testResult").value , "You pressed the Alert button!")
    end
    
    def test_confirm_ok
        $ff.button(:id, "btnConfirm").click_no_wait()
        
        $ff.click_jspopup_button("OK")
        assert_equal($ff.text_field(:id, "testResult").value , "You pressed the Confirm and OK button!")
    end
    
    def test_confirm_cancel
        $ff.button(:id, "btnConfirm").click_no_wait()
        
        $ff.click_jspopup_button("Cancel")
        assert_equal($ff.text_field(:id, "testResult").value, "You pressed the Confirm and Cancel button!")
    end
end

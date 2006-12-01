# feature tests for attaching to new Firefox windows
# revision: $Revision: 1.0 $

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') if $0 == __FILE__
require 'unittests/setup'

class TC_NewWindow < Test::Unit::TestCase
    include FireWatir

    def setup
      $ff.goto($htmlRoot + "new_browser.html")
    end

    def test_simply_attach_to_new_window
        $ff.link(:text, 'New Window').click
        ff_new = $ff.attach(:title, 'Pass Page')
        assert(ff_new.text.include?('PASS'))
        ff_new.close
        #$ff.link(:text, 'New Window').click
    end
    
    def aatest_attach_to_new_window_using_separate_process
        $ff.eval_in_spawned_process "link(:text, 'New Window').click"
        IE.attach_timeout = 1.0
        ie_new = IE.attach(:title, 'Pass Page')
        assert(ie_new.text.include?('PASS'))
        ie_new.close
    end
    
    def aatest_attach_to_new_window_using_click_no_wait
        $ff.link(:text, 'New Window').click_no_wait
        IE.attach_timeout = 1.0
        ie_new = IE.attach(:title, 'Pass Page')
        assert(ie_new.text.include?('PASS'))
        ie_new.close
    end

    def aatest_attach_to_slow_window_works_with_delay
        $ff.span(:text, 'New Window Slowly').click
        sleep 0.8
        ie_new = IE.attach(:title, 'Test page for buttons')
        assert(ie_new.text.include?('Blank page to fill in the frames'))
        ie_new.close
    end    

    def aatest_attach_to_slow_window_works_without_waiting
        $ff.span(:text, 'New Window Slowly').click
        IE.attach_timeout = 0.8
        ie_new = IE.attach(:title, 'Test page for buttons')
        assert(ie_new.text.include?('Blank page to fill in the frames'))
        ie_new.close
    end    

    def aatest_attach_timesout_when_window_takes_too_long
        $ff.text_field(:name, 'delay').set('2')
        $ff.span(:text, 'New Window Slowly').click
        assert_raise(Watir::Exception::NoMatchingWindowFoundException) do
            IE.attach(:title, 'Test page for buttons')
        end
        sleep 2 # clean up
        IE.attach(:title, 'Test page for buttons').close
    end        

end

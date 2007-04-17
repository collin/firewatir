$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') if $0 == __FILE__
require 'unittests/setup'

class TC_Bugs< Test::Unit::TestCase
  include FireWatir
  
    def setup
        $ff.goto($htmlRoot + "frame_buttons.html")
    end
  
    def test_frame_objects
        frame = $ff.frame("buttonFrame")
        button = frame.button(:name, "b1")
        assert_equal("buttonFrame", frame.name)
        assert_equal("b2", button.id)
        text1 = frame.text_field(:id, "text_id")
        text1.set("NewValue")
        assert("NewValue",frame.text_field(:id, "text_id").value)
    end
        
    def test_link_object
        $ff.goto($htmlRoot + "links1.html")
        link =  $ff.link(:text, "nameDelet")
        assert_equal("test_link", link.name)
    end
    
    def test_elements_by_xpath
        $ff.goto($htmlRoot + "links1.html")
        elements = $ff.elements_by_xpath("//a")
        assert_equal(11, elements.length)
        assert_equal("links2.html", elements[0].href)
        assert_equal("link_class_1", elements[1].className)
        assert_equal("link_id", elements[5].id)
        assert_equal("Link Using an ID", elements[5].text)
    end

    def test_button_by_value
        $ff.goto($htmlRoot + "buttons1.html")
        assert_equal("Sign In", $ff.button(:value,"Sign In").value)
    end
       
    def test_html
        $ff.goto($htmlRoot + "links1.html")
        html = $ff.html
        assert(html =~ /.*<a id="linktos" *>*/)
    end
end 

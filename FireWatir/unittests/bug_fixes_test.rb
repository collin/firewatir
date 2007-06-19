$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') if $0 == __FILE__
require 'unittests/setup'

class TC_Bugs< Test::Unit::TestCase
  include FireWatir
  
    def setup
        $ff.goto($htmlRoot + "frame_buttons.html")
    end
  
    def test_frame_objects_bug3
        frame = $ff.frame("buttonFrame")
        button = frame.button(:name, "b1")
        assert_equal("buttonFrame", frame.name)
        assert_equal("b2", button.id)
        text1 = frame.text_field(:id, "text_id")
        text1.set("NewValue")
        assert("NewValue",frame.text_field(:id, "text_id").value)
    end
        
    def test_link_object_bug9
        $ff.goto($htmlRoot + "links1.html")
        link =  $ff.link(:text, "nameDelet")
        assert_equal("test_link", link.name)
    end
    
    def test_elements_by_xpath_bug10
        $ff.goto($htmlRoot + "links1.html")
        elements = $ff.elements_by_xpath("//a")
        assert_equal(11, elements.length)
        assert_equal("links2.html", elements[0].href)
        assert_equal("link_class_1", elements[1].className)
        assert_equal("link_id", elements[5].id)
        assert_equal("Link Using an ID", elements[5].text)
    end

    def test_button_by_value_bug8
        $ff.goto($htmlRoot + "buttons1.html")
        assert_equal("Sign In", $ff.button(:value,"Sign In").value)
    end
       
    def test_html_bug7
        $ff.goto($htmlRoot + "links1.html")
        html = $ff.html
        assert(html =~ /.*<a id="linktos" *>*/)
    end

    def test_span_onclick_bug14
        $ff.goto($htmlRoot + "div.html")
        $ff.span(:id, "span1").fireEvent("onclick")
        assert($ff.text.include?("PASS") )
    end

    def test_file_field_value_bug20
        actual_file_name = "c:\\Program Files\\TestFile.html"
        $ff.goto($htmlRoot + "fileupload.html")
        $ff.file_field(:name, "file3").set(actual_file_name)
        set_file_name = $ff.file_field(:name, "file3").value
        # make sure correct value for upload file is posted.
        assert(actual_file_name, set_file_name)
    end    

    def test_attribute_value_bug22
        $ff.goto($htmlRoot + "div.html")
        assert("Test1", $ff.element_by_xpath("//div[@id='div1']").attribute_value("title"))
    end
    
    def test_url_value_bug23
        $ff.goto($htmlRoot + "buttons1.html")
        $ff.button(:id, "b2").click
        assert($htmlRoot + "pass.html", $ff.url)
    end

    def test_contains_text_bug28
        $ff.goto($htmlRoot + "buttons1.html")
        $ff.button(:id, "b2").click
        assert_false($ff.contains_text("passed"))
        assert($ff.contains_text("PASS"))
        assert($ff.contains_text(/PASS/))
        assert($ff.contains_text(/pass/i))
        assert_false($ff.contains_text(/pass/))
    end

    def test_frame_bug_21
        $ff.goto($htmlRoot + "frame_buttons.html")
        frame1 = $ff.frame(:name, "buttonFrame")
        frame2 = $ff.frame(:name, "buttonFrame2")
        assert_equal("buttons1.html", frame1.src)
        assert_equal("blankpage.html", frame2.src)
    end
    
    def test_quotes_bug_11
        $ff.goto($htmlRoot + "textfields1.html")
        $ff.text_field(:name, "text1").set("value with quote (\")")
        assert_equal("value with quote (\")", $ff.text_field(:name, "text1").value)
        $ff.text_field(:name, "text1").set("value with backslash (\\)")
        assert_equal("value with backslash (\\)", $ff.text_field(:name, "text1").value)
    end

    def test_close_bug_26
        $ff.close()
        $ff = Firefox.new
    end
end 

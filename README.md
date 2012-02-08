# pdf-toolkit - A ruby interface to pdftk

pdf-toolkit allows you to access pdf metadata in read-write in a very simple 
way, through the [`pdftk` commandline tool](http://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/).

A typical usecase is as follows:

    my_pdf = PDF::Toolkit.open("somefile.pdf")
    my_pdf.updated_at = Time.now # ModDate
    my_pdf["SomeAttribute"] = "Some value"
    my_pdf.save!
    
    class MyDocument < PDF::Toolkit
      info_accessor :some_attribute
      def before_save
        self.updated_at = Time.now
      end
    end
    my_pdf = MyDocument.open("somefile.pdf")
    my_pdf.some_attribute = "Some value"
    my_pdf.save!

## Note about this version

This is a prerelease 1.0.0.rc1 version on an almost abandonned project. The main
difference (broken API) with the 0.5.0 branch is that support for ActiveRecord 
has been entirely removed (mostly because the implementation was ugly so far).
If you use pdf-toolkit and would like activerecord to be included in 1.0.0, 
please just tell us and we'll add it. If you upgrade from 0.5.0 to 1.0.0.rc1 and 
something else goes wrong, please report the issue on github.

## Contributors

* Tim Pope is the original author of pdf-toolkit
* Preston Marshall ported the project to github
* Bernard Lambeau is the current maintainer

Please report issues on [github](https://github.com/blambeau/pdf-toolkit/issues)

## Licence

pdf-toolkit is released under a MIT licence. See LICENCE.md

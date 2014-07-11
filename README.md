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

Starting with version 1.1.0, PDFTK version 2.0 is strongly recommended. Feel free to report problems on earlier versions if you think it's worth it, though.

## Contributors

* Tim Pope is the original author of pdf-toolkit
* Preston Marshall ported the project to github
* Bernard Lambeau is the current maintainer
* James Prior made small changes for PDFtk Server 2.0

Please report issues on [github](https://github.com/blambeau/pdf-toolkit/issues)

## Licence

pdf-toolkit is released under a MIT licence. See LICENCE.md

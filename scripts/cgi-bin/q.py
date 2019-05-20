#!/usr/local/bin/python2.4
# -*- coding: utf-8 -*-
# vim:set termencoding=iso-8859-2 encoding=utf-8:
#
# Internet Survey Engine
# Copyright (C) 2004 Maciej Bliziński <m.blizinski@wsisiz.edu.pl>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
# USA.


### copied from wizard.py ###

import libxml2, shelve
import libxslt
import xml.dom.minidom
from xml import xpath
from ConfigParser import SafeConfigParser
##from ConfigParser import ConfigParser as SafeConfigParser

import cgi
import cgitb; cgitb.enable()
import sys
import os
import locale
import time
import string

## mnj (1) conf_dir added, to keep ancillary files separate from cgi-bin
conf_dir = "/var/www/ipccddc_site/config/query/"
## debug = True prints extra info on some screens
debug = False
## end mnj ##

def XSLTTrans(xmldoc, xsldoc, params = None):
    """Transforms the xmldoc with xsldoc, and returns the string."""
    # print "params: %s" % params
    styledoc = libxml2.parseDoc(xsldoc)
    style = libxslt.parseStylesheetDoc(styledoc)
    doc2t = libxml2.parseDoc(xmldoc)
    result = style.applyStylesheet(doc2t, params)
    stringresult = style.saveResultToString(result)
    style.freeStylesheet()
    doc2t.freeDoc()
    result.freeDoc()
    return stringresult

class WebSurvey:
    def __init__(self, form, surveyFileName):
        self.oo = open( '/tmp/mnj_websurvey.txt', 'w' )
        self.oo.write( 'Initialsiing websurvey\n' )
        self.form = form
        self.doc = xml.dom.minidom.parse(surveyFileName)
        self.wizard = self.doc.documentElement
        for dataField in xpath.Evaluate("//dataField",
                self.doc.documentElement):
          widgets = dataField.getElementsByTagName('widget')
          if len(widgets) > 0:
            name = widgets[0].getAttribute("name")
            self.oo.write( '%s\n' % str(name) )
            attrs =  widgets[0].attributes
            for i in attrs.keys():
                 if attrs[i].name:
                   self.oo.write( str( attrs[i].name ) + "->" + attrs[i].value + '\n' )
                 else:
                   self.oo.write(   " no %s ->\n" % i  )
          else:
            raise 'invalid datafield'
        self.config = SafeConfigParser()
        self.config.read(conf_dir + "ddc_query.conf")
        # determine, which page was submitted, if any
        if self.form.has_key("screen_no"):
            self.oo.write( 'found a screen no\n')
            try:
                self.sentscreen = int(form["screen_no"].value)
                # self.nextscreen = self.sentscreen + 1
                # print '<pre>got screen_no: %s</pre>' % self.sentscreen
            except:
                self.sentscreen = None
                # self.nextscreen = 0
                # print '<pre>got screen_no but no luck in conversion to integer: %s</pre>' % form["screen_no"].value
            try:
                self.referer = form["http_referer"].value
            except:
                self.referer = 'not found in form'
        else:
            self.oo.write( 'no screen no\n')
            self.sentscreen = None
            self.referer = os.getenv('HTTP_REFERER' )
            if self.referer == None:
              self.referer = 'no referer in env'
            # self.nextscreen = 0
            # print '<pre>didn\'t get screen_no: %s</pre>' % self.sentscreen
        return
    def processSurvey(self):
        # if not self.form.has_key("survey_data"):
        #     return
# process all fields
        ##  self.doc.documentElement is the xml document describing the survey ##
        for dataField in xpath.Evaluate("//dataField",
                self.doc.documentElement):
            df = WebSurveyDataField(dataField)
            df.obtainValue(self.form)
        # if user pressed back button, we shouldn't validate what he/she
        # had entered. We can pass entered values, but we can validate
        # them later.
        if form.has_key("backbutton"):
            self.sentscreen -= 1
        if form.has_key("survey_data"):
            for dataField in xpath.Evaluate("//dataField[count(parent::dataFields/parent::wizardScreen/preceding::wizardScreen) <= %s]" % self.sentscreen,
                    self.doc.documentElement):
                df = WebSurveyDataField(dataField)
                df.validateValue()
# if all the filled fields are ok, advance to the next screen of the
            # wizard
        if self.sentscreen is None:
            self.nextscreen = 0
        elif self.form.has_key("backbutton"):
            self.nextscreen = self.sentscreen
        else:
            if len(xpath.Evaluate("//dataField[@valid = 'no']",
                self.doc.documentElement)) == 0:
                self.nextscreen = self.sentscreen + 1
            else:
                self.nextscreen = self.sentscreen
# if the response is valid, act
        if len(xpath.Evaluate("//dataField", self.doc.documentElement)) \
                == len(xpath.Evaluate("//dataField[@valid = 'yes']", self.doc.documentElement)): 
             oo = os.popen( '/usr/sbin/sendmail -t', 'w' )
             oo.write( "To: m.n.juckes@rl.ac.uk\n" )
             oo.write( "From: %s <%s>\n" % (self.form['name'].value, self.form['email'].value) )
             oo.write("Subject: [ddc_query] %s\n" % self.form['title'].value)
             oo.write("\n") # blank line separating headers from body
             oo.write("%s\n\nFrom: %s\nEmail: %s\n" % (self.form['user_comment'].value, self.form['name'].value, self.form['email'].value) )
             oo.write("Category:%s\n" % self.form['suggtype'].value )
             sts = oo.close()
             if sts:
               oo = open( '/tmp/mnj_oo.txt', 'w' )
               oo.write( sts )
               oo.close()
        return
    def getXML(self):
        return self.doc.toxml().encode("utf-8")
    def getHTML(self):
        # return "Content-type: text/html; charset=utf-8\n\n" \
        #         + XSLTTrans(self.getXML(), open("ddc_query.xsl").read())
        self.processSurvey()
        ee = { "screen_no": "'%s'" % self.nextscreen, # gotcha!  apostrophes needed
               "http_referer": "'%s'" % self.referer, 
               }
        ##if (len(self.form.keys() ) > 0) and (self.nextscreen == 1):
        if self.nextscreen == 1:
          draft = '<table class="check" rules="rows">\n'
          oo = open( '/tmp/mnj_form.txt', 'w' )
          tags = { 'name':'Name', 'title':'Subject', 'user_comment':'Your query', 'email':'Your address'}
          for k in ['name','email','title','user_comment']:
             
             val = string.replace( self.form[k].value, '\n', '<br/>' )
             draft += '<tr class="checkRow"> <td class="odd-ctable-column" valign="top">%s </td><td class="even-ctable-column" valign="top">%s</td></tr>\n' % ( tags[k],  val )
             oo.write( k )
             oo.write( val )
          oo.close()
          draft += '</table>\n'
          ee['draft_email'] = "'==draft_marker=='"
          ss = XSLTTrans(self.getXML(), open(conf_dir + "ddc_query.xsl").read(), ee )
          
          return string.replace( ss, "==draft_marker==", draft )
        elif (len(self.form.keys() ) > 0) and (self.nextscreen == 2):
          ss = XSLTTrans(self.getXML(), open(conf_dir + "ddc_query.xsl").read(), ee )
          links = '<a href="http://www.ipcc-data.org">IPCC DDC Home</a> '
          if self.referer not in [None,'no referer in env','xsl default','not found in form']:
            links += '<br/> <a href="%s">Back to referring page</a>' % self.referer
          ##+
                 ##'<br/> <a href="%s">Referring page</a>' % os.getenv('HTTP_REFERER' )
          return string.replace( ss, "---linkslot---", links )
        else:
          ss = XSLTTrans(self.getXML(), open(conf_dir + "ddc_query.xsl").read(), ee )
          sh = shelve.open( '/tmp/mnj_shelve2', 'n' )
          sh['xml'] = self.getXML()
          sh['xsl'] = open(conf_dir + "ddc_query.xsl").read()
          sh['ee'] = ee
          sh['ss'] = ss
          sh['comment'] = 'here 01'
          sh.close()
          return XSLTTrans(self.getXML(), open(conf_dir + "ddc_query.xsl").read(), ee )

class WebSurveyDataField:
    def __init__(self, domElement, eltype='widget'):
        self.domElement = domElement
        # self.widget = self.domElement.getElementsByTagName("widget")[0]
        if eltype == 'widget':
          widgets = self.domElement.getElementsByTagName("widget")
          if len(widgets) > 0:
            self.widgetType = widgets[0].getAttribute("type")
            if self.widgetType in ["text", "features", "area", "chooser", "radio", "hidden-java"]:
                self.w = TextWidget(widgets[0])
            else:
                raise "unxepected widget"
                pass # shouldn't happen
        else:
          inputs = self.domElement.getElementsByTagName("input")
          self.widgetType = inputs[0].getAttribute("type")
          if self.widgetType == "hidden":
              self.w = TextWidget(inputs[0])
          else:
              raise "unxepected widget"
              pass # shouldn't happen
        return
    def getXML(self):
        return self.dataDoc.toxml()
    def validateValue(self):
        if self.w.validateValue():
            self.markValid()
        else:
            self.markInvalid()
    def markInvalid(self):
        self.domElement.setAttribute("valid", "no")
        return
    def markValid(self):
        self.domElement.setAttribute("valid", "yes")
        return
    def setValue(self, value):
        self.w.setValue(value)
        return
    def obtainValue(self, form):
        self.w.obtainValue(form)
        return
    def isMandatory(self):
        if self.domElement.getAttribute("mandatory") == "yes":
            return True
        else:
            return False

class GeneralWidget:
    """This would be an abstract class if only abstract classes
    were implemented in Python"""
    def __init__(self, domElement):
        self.domElement = domElement
        self.doc = xml.dom.minidom.Document()
        return 
    def obtainValue(self, form):
        if form.has_key(self.domElement.getAttribute("name")):
            if type(form[self.domElement.getAttribute("name")]) == type([]):
                # print "<pre>%s is a list: %s</pre>" \
                #         % (self.domElement.getAttribute("name"), repr(form[self.domElement.getAttribute("name")]))
                pass
            elif form[self.domElement.getAttribute("name")].value:
                #
                # do not insert value of automatically collected data in the xml document.
                #
                if self.domElement.getAttribute("name") != "appname":
                  self.setValue(form[self.domElement.getAttribute("name")].value.decode('utf-8'))

    def setValue(self, value):
        # self.domElement.setAttribute("value", value)
        # print "<pre>setValue(%s)</pre>" % value
# check if we have value
        if self.domElement.getElementsByTagName("value") == []:
            valueElement = self.doc.createElement("value")
            valueElement.appendChild(self.doc.createTextNode(value))
            self.domElement.appendChild(valueElement)
        else:
            oldvalue = self.domElement.getElementsByTagName("value")[0]
            newvalue = self.doc.createElement("value")
            newvalue.appendChild(self.doc.createTextNode(value))
            self.domElement.replaceChild(newvalue, oldvalue)
        return
    def getValue(self):
        try:
            return self.domElement.getElementsByTagName("value")[0].childNodes[0].data
        except:
            return None
    def validateValue(self):
        if not self.getValue() and self.isMandatory():
            # print "<p>%s: missing Mandatory field</p>" \
            #     % self.domElement.getAttribute("name")
            return False
        if self.domElement.getAttribute("name") == 'email':
           em = self.getValue()
           res = string.find( em, '@' )
           if res == -1:
             return False
           bits = string.split( em, '@' )
           res = string.find( bits[-1], '.' )
           if res == -1:
             return False
        if self.domElement.parentNode.getAttribute("datatype") == "integer":
            if self.getValue():
                try:
                    checkInt = int(self.getValue())
                    return True
                except:
                    return False
        elif self.domElement.parentNode.getAttribute("datatype") == "confirm":
            if self.getValue():
               return self.getValue() in ['1','y','Y','yes','YES']
        return True
    def isMandatory(self):
        # print "<pre>mandatory: %s</pre>" % self.domElement.parentNode.getAttribute("mandatory")
        if self.domElement.parentNode.getAttribute("mandatory") == "yes":
            return True
        else:
            return False


class TextWidget(GeneralWidget):
    """TextWiget inherits everything from GeneralWidget"""
    pass

class AreaWidget(GeneralWidget):
    """TextWiget inherits everything from GeneralWidget"""
    pass

class FeaturesWidget(GeneralWidget):
    def obtainValue(self, form):
        name = string.lower( self.domElement.getAttribute("name") )
        
        if form.has_key(name):
            # print "<p>there is something: %s</p>" % repr(form[self.domElement.getAttribute("name")])
            if type(form[name]) == type([]):
                # print "<p>it's a list</p>"
                fieldlist = form[name]
            else:
                # print "<p>it's singleton</p>"
                fieldlist = [form[name]]
            for field in fieldlist:
                # print "<p>field: %s, value: %s</p>" % (repr(field), field.value)
                dictionaryEntry = xpath.Evaluate("widgetDictionary/dictionaryEntry[code = '%s']" \
                        % field.value, self.domElement)[0]
                dictionaryEntry.setAttribute("selected", "yes")
        else:
            # print "<p>no key: %s</p>" % self.domElement.getAttribute("name")
            pass
        # for entry in xpath.Evaluate("//dictionaryEntry", self.domElement):
    def setValue(self, value):
        print "<p>FIXME: FeaturesWidget: setValue</p>"
    def getValue(self):
        print "<p>FIXME: FeaturesWidget: getValue</p>"
    def validateValue(self):
        # print "<p>FIXME: FeaturesWidget: validateValue</p>"
        return True


#######################################################################
## Main Part
#######################################################################

form = cgi.FieldStorage()
oo = open( '/tmp/mnj_ddc_query_form.txt', 'w' )
for k in form.keys():
  oo.write( '%s::%s\n' % (k,form[k]) )
oo.close()
dict = cgi.UserDict.UserDict()
oo = open( '/tmp/mnj_ddc_query_dict.txt', 'w' )
for k in dict.keys():
   oo.write( '%s::%s\n' % (k,dict[k]) )
oo.close()

print "Content-type: text/html; charset=utf-8\n"
ws = WebSurvey(form, conf_dir + "ddc_query.xml")
ws.oo.close()
# print "<code>%s</code>" % repr(form)
print ws.getHTML()
# print ws.getXML()
###### mnj ########
##oo = open( '/research/home/tmp/test.html', 'w' )
##oo.write( ws.getHTML() )
##oo.close()

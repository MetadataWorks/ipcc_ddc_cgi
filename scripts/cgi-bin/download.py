#!/usr/bin/python
import Cookie, os, cgi, string, sys

class classRequest:

    def __init__(self):

        self.env            = os.environ

        self.fields         = cgi.FieldStorage()
        self.path_info      = self.env.get("PATH_INFO", "/")
        self.relative_path  = self.path_info.strip("/")
        self.method         = self.env.get("REQUEST_METHOD", "")
        self.query          = self.env.get("QUERY_STRING", "")
        self.remote_address = self.env.get("REMOTE_ADDR", "")
        self.cookie         = self.env.get("HTTP_COOKIE", None)

        self.if_modified_since = self.env.get("HTTP_IF_MODIFIED_SINCE", None)
        self.if_none_match     = self.env.get("HTTP_IF_NONE_MATCH", None)


class pparse:
  
   def __init__(self,p):
      self.d = {}
      self.u = []
      bits = string.split(p, '/')
      for b in bits:
        if ( len(b) > 0 ) and ( type(b) == type('x') ):
          kv = string.split(b, '=')
          if len(kv) == 2:
            self.d[kv[0]] = kv[1]
          else:
            self.u.append( b )
        else:
          self.u.append( type(b) )
        
rq = classRequest()

kv = pparse( rq.path_info )

content_type = 'binary'
content_type = 'application/nc'
##sys.stdout.write( "Content-type: %s\n" % content_type )

sys.stdout.write( "\n" )
sys.stdout.write( "method" )
sys.stdout.write( rq.method )
sys.stdout.write( "\n" )
sys.stdout.write( rq.path_info )
for k in kv.d.keys():
   sys.stdout.write( "\n %s::%s" % (k, kv.d[k] ) )
for u in kv.u:
   sys.stdout.write( "\n %s;;" % (u) )
##print "alert('hello (1)');\n"

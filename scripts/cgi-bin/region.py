#!/usr/bin/python
import Cookie, os, cgi, string, sys
import utils

email = 'anon'
 
rq = utils.classRequest()

def iget(rq,id,default):
  if rq.fields.has_key( id ):
    return int( rq.fields[id].value ) - 1
  else:
    return default

typ = rq.prep()

data_dir = '/usr/local/data/ipcc-ddc/data/netcdf/ar4_v2/'
user_accnt_dir = '/var/www/ipccddc_devel/user_accnt/'
user_hist_dir = '/var/www/ipccddc_devel/user_hist/'
base_dir = '/usr/local/data/ipcc-ddc/data/'
    
o1 = open( '/tmp/region_l1.txt', 'w' )
o1.write( 'nav:: \n' )

header = """<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<title>%(title)s</title>
<link rel="stylesheet" media="screen" type="text/css" href="/css/download.css" />
<style type="text/css">
td.set {background: #aaffaa;}
th.set {background: #bbffbb;}
td.unset {background: #aaaaff;}
th.unset {background: #bbbbff;}
</style>
</head>
<body>"""



title = 'Region search (place-holder)'
requiredKeys = ['leftlon','rightlon','toplat','botlat']
for k in requiredKeys:
  assert rq.fields.has_key( k ), 'Required key %s not found in request' % k

west = rq.fields['leftlon'].value
east = rq.fields['rightlon'].value
north = rq.fields['toplat'].value
south = rq.fields['botlat'].value

sys.stdout.write( "Content-type: %s\n\n" % 'text/html' )
sys.stdout.write( header % locals() )

sys.stdout.write( '<h1>Search place-holder</h1>\n\n' )
sys.stdout.write( '<ul>\n' )
for k in rq.fields.keys():
   sys.stdout.write( '<li>%s=%s</li>\n' % (k,rq.fields[k].value) )
sys.stdout.write( '</ul>\n' )

def sll(v,d):
   if d == 'ns':
     if v > 0:
       return '%sN' % v
     else:
       return '%sS' % abs( v )
   else:
     if v > 0:
       return '%sE' % v
     else:
       return '%sW' % abs( v )

w = sll( west, 'ew' )
e = sll( east, 'ew' )
n = sll( north, 'ns' )
s = sll( south, 'ns' )

sys.stdout.write( '<p>Search for data in region [%s,%s,%s,%s].</p>\n' % (w,e,s,n) )
sys.stdout.write( '<p>Search not yet implemented.</p>\n'  )

sys.stdout.write( '\n</body>\n</html>\n' )

o1.close()

#!/usr/bin/python
import os, cgi, string, sys, stat

email = 'anon'

base_dir = '/usr/local/data/ipcc-ddc/data/'
base_dir = '/badc/ipcc-ddc/data/'
if not os.path.isdir( base_dir):
 base_dir = './'
user_hist_dir = '/var/www/ipccddc_devel/user_hist/'

def crack_tunits( units ):
  ub1 = string.split( units )
  if ub1[1] != 'since':
    raise 'bad units'
  if ub1[0] != 'days':
    raise 'cannot deal with data with time units not set to days'
  startYear, startMonth, startDay = map( lambda x: int(x), string.split( ub1[2], '-' ) )

  return startYear, startMonth, startDay

def cf_time_info( nc, tax,bounds=None ):
  message = ' '
  if hasattr( tax, 'climatology'):
    message += '<br/>' + str( tax.climatology )
    cb = nc.variables[ tax.climatology ]
    startYear, startMonth, startDay = crack_tunits( cb.units )
    message += '<br/>' + str( dir(cb) )
    ny = int( (cb[0,1] - cb[0,0])/365.25 ) + 1
  elif bounds != None and nc.variables.has_key( bounds ):   
    cb = nc.variables[ bounds ]
    startYear, startMonth, startDay = crack_tunits( cb.units )
    message += '<br/>' + str( dir(cb) )
    ny = int( (cb[0,1] - cb[0,0])/365.25 ) + 1
  else:   
    startYear, startMonth, startDay = crack_tunits( tax.units )
    ny = int( (tax[-1] - tax[0] )/365.25 ) + 1
  endYear = startYear + ny - 1

  return startYear, startMonth, startDay, endYear


def slice2table_1b(title,yname,yvals,cname, cvals, tlist, slist, v,fmt,factor,mime='html'):
  mess = 'starting --- '
  data_display = 'slice2table_1b;; line 2<br/>'
  try:
    if mime == 'html':
      data_display = '<h2>%s</h2>\n' % title
      mess += 'xx'

      data_display += '<table border="2">\n'
      data_display += '<tr><th rowspan="2"><i>%s</i></th><td rowspan="2"><i>%s</i></td>' % (yname,cname)
      mess += 'xx'
      for t in tlist:
         data_display += '<td colspan="%s"><b>%s</b></td>' % (len(slist),t)
      data_display += '</tr>\n<tr>\n'
      mess += 'xx'
      for t in tlist:
        for s in slist:
          data_display += '<td><i>%s</i></td>\n' % s
      data_display += '\n</tr>\n'
      mess += '<br/>xx'
    else:
##
## NB spaces between delimeters ',' and quotes cause openoffice cal to ignore the quotes.
##
      mess += 'xx'

      data_display = '<DATA>\n'
      data_display += '%s,%s,' % (yname,cname)
      mess += 'xx'
      for t in tlist:
         data_display += '"%s",' % t
         for i in range( len(slist)-1):
           data_display += ','
      data_display += '\n'
      mess += 'xx'
      if len(slist) > 1:
        data_display += ',,'
        for t in tlist:
          for s in slist:
            data_display += '%s,' % s
        data_display += '\n'

      
    llist = range(len(yvals))

    for j in llist:
      mess += '<br/>xx'
      if mime == 'html':
        data_display += '<tr>\n'
        data_display += '<th><i>%i</i></th><td>%s</td>' % (yvals[j],cvals[j])
      else:
        data_display += '%6.2f, %s, ' % (yvals[j],cvals[j])

      for i in range(len(slist)*len(tlist)):
          if abs(v[j,i] +999. ) < .1:
            dv = 'na'
          else:
            dv = fmt % (v[j,i]*factor)
          if mime == 'html':
            data_display += '<td>%s</td>' % dv 
          else:
            data_display += '%s, ' % dv 
      if mime == 'html':
          data_display += '\n</tr>\n'
      else:
          data_display += '\n'

    if mime == 'html':
        mess += '<br/>zz'
        data_display += '</table>\n'
    return (1,data_display)
  except:
    mess += 'failed<br/><br/>' + data_display
    return (0,mess)

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
        self.cookie_dir = {}

        self.if_modified_since = self.env.get("HTTP_IF_MODIFIED_SINCE", None)
        self.if_none_match     = self.env.get("HTTP_IF_NONE_MATCH", None)
        self.email = ""
        self.referer = ""
        self.name = ""

    def prep(self):
      typ = 'first'

      if self.fields.has_key( 'ddc-data-downl' ):
        if self.fields['ddc-data-downl'].value == 'sending':
          typ = 'self'

## look for referer for 'back to referer' link
      if self.fields.has_key("http-referer"):
        self.referer = self.fields["http-referer"].value
      else:
        try:
          self.referer = os.getenv('HTTP_REFERER' )
        except:
          self.referer = '/'
      return typ

    def ingest_cookie( self, key ):
      if self.cookie != None:
       cks = string.split( self.cookie, ';' )
       for c in cks:
         bbb = string.split( c, '=', maxsplit=1 )
         cook_name = string.strip(bbb[0] )
         if cook_name == key:
           this_cook_val = string.strip(bbb[-1], '"')
           bits = string.split( this_cook_val, ':' )
           for b in bits:
             b2 = string.split( b, '=' )
             if len(b2) == 2:
               self.cookie_dir[b2[0]] = b2[1]

class ddc_file:

  def __init__(self,identifier, narg=0,rptFile='/tmp/downl_report.txt'):
    self.extrPtTmpl = 'templates/extractPoint_html.template'

    dsdd = {'ar4_nc':['netcdf/ar4_v2/','ar4_gcm'],
            'sres':['netcdf/sres/','tar_gcm'],
       'ar4_tif':['geotiff/ar4_v2/','ar4_gcm'],
       'cru10_nc': ['netcdf/obs/cru_ts2_1/clim_10/','cru21'],
       'cru10_zip':['geotiff/obs/cru_ts2_1/clim_10/','cru21'],
       'cru30_nc': ['netcdf/obs/cru_ts2_1/clim_30/','cru21'],
       'cru30_zip':['geotiff/obs/cru_ts2_1/clim_30/','cru21']
        }

    oo = open( rptFile, 'w' )
    bits = string.split( identifier, '/' )
    data_id = bits[-1-narg]
    if narg > 0:
      self.args = bits[-narg:]
      oo.write( 'args found \n' )
      oo.write( string.join( self.args ) + '\n' )

    if data_id[-3:] == '.nc':
      self.filetype = 'nc'
    elif data_id[-4:] == '.tar':
      self.filetype = 'tar'
    else:
      self.filetype = 'other'

    dataset_id = bits[0]
    oo.write( 'downl2: ddc_file:init: \n' )
    oo.write( identifier + '\n' )

    self.message = ''

    oo.write( dataset_id + '\n' )
    if dataset_id not in dsdd.keys():
      oo.write( 'bad dataset_id: %s\n' % dataset_id )
      oo.close()
      raise 'bad dataset_id'

    self.dsdir =base_dir + dsdd[ dataset_id ][0]
    self.datasetid = dsdd[ dataset_id ][1]

    oo.write( data_id + '\n' )
    dbits = string.split( data_id, '.' )
    if len(dbits) == 3:
      if dbits[1] in ['cyto180','extractPoint']:
        self.action = dbits[1]
      else:
        raise 'action not recognised'
      self.file_name = dbits[0] + '.' + dbits[2]
      oo.write( 'xxx\n' )
    elif len(dbits) == 2:
      self.action = None
      self.file_name = data_id
      oo.write( 'yyy\n' )
    else:
      oo.write( 'zzz\n' )
      raise 'bad file name'
## ar4, gcm projections

    oo.write( self.file_name + '\n' )
    if dataset_id in ['ar4_nc','ar4_tif']:
      self.data_dir = self.dsdir  +  string.split(bits[-2-narg],'-')[0]
    elif dataset_id in ['sres']:
      fbits = string.split(bits[-1],'_')
      oo.write( '%s,  %s\n' % (str(fbits), str(bits) ) )
      self.data_dir = '%s%s_%s' % (self.dsdir, string.lower(fbits[0]), string.lower( fbits[1] ) )
    else:
      self.data_dir = self.dsdir + string.split( data_id, '_')[1]
    oo.write( self.data_dir + '\n' )
    oo.close()

  def check_file(self):
    self.this_file = self.data_dir + '/' + self.file_name
## check that file exists
    if os.path.isfile( self.this_file ):
       self.message += '-->%s  %s<br/>\n' % (self.this_file,  os.stat(self.this_file)[stat.ST_SIZE] )
       if os.stat(self.this_file)[stat.ST_SIZE] < 128:
          self.file_not_found = True
          self.message += 'file too small:%s -- %s<br/>\n' % (self.this_file,  os.stat(self.this_file)[stat.ST_SIZE])
       else:
          self.file_not_found = False
    else:
          self.file_not_found = True
          self.message += 'file not found:%s<br/>\n' % self.this_file

  def deliver( self, cook=None, user=None ):
    import time
    if user != None:
      oo = open( '%s%s' % (user_hist_dir, user.email), 'a' )
      oo.write( '%s::%s\n' % (time.asctime(), self.this_file) )
      oo.write( 'size:: %s\n' % os.path.getsize( self.this_file ) )
    sys.stdout.write( "Content-type: %s\n" % 'application/tar' )
    if cook != None:
      sys.stdout.write( cook.output() )
      sys.stdout.write( '\n' )
      if user != None:
        oo.write( 'setting cookie\n' )
        oo.write( cook.output() )
    if user != None:
      oo.close()
    sys.stdout.write( '\n' )
    if ddd.action == None:
      file_handle = open( self.this_file, 'r' )
      data = file_handle.read()
    elif self.action == 'cyto180':
      sys.path.insert(0,'grid_aps')
      import cyto180 as u
      u.nc_lon_cyc( self.this_file, '/tmp/tmp.nc' )
      file_handle = open( '/tmp/tmp.nc', 'r' )
      data = file_handle.read()
    elif self.action == 'extractPoint':
      ll = open( self.extrPtTmpl, 'r').readlines()
      ll1 = string.join( ll )
      sys.stdout.write( ll1 % { 'fileName':self.file_name } )
      
    else:
      raise 'bad action'
    file_handle.close()
    sys.stdout.write( data )

class dlsort:
   def __init__(self):
      self.ee = {}
   def cmp(self,x,y):
      if x not in self.ee.keys():
        bs = string.split( x, '-')
        self.ee[x] = int(bs[1]) - int(bs[0])
      if y not in self.ee.keys():
        bs = string.split( y, '-')
        self.ee[y] = int(bs[1]) - int(bs[0])
      if self.ee[x] == self.ee[y]:
        return cmp( x,y )
      else:
        return cmp( self.ee[x], self.ee[y] )
        return -1

ar4_mdict = {}
inFileModels = '/var/www/ipccddc_devel/wrk/models.txt'
if not os.path.isfile( inFileModels ):
  inFileModels = 'data/models.txt'
  
try:
  ii = open( inFileModels ).readlines()
  for l in ii[1:]:
    bs = string.split(string.strip(l), ';' )
    ar4_mdict[string.strip(bs[-1])] = string.strip(bs[0])
except:
  print 'models.txt not found'

fdict = {'Model':'m','Expt':'E','Ens':'e','Variable':'v','Slice':'s' } 
fdict_inv = {}
for k in fdict.keys():
  fdict_inv[ fdict[k] ] = k


cru_vdict = {'cld':'Cloud Cover', \
'dtr':'Diurnal Temperature Range', \
'frs':'Ground-frost Frequency', \
'pre':'Precipitation', \
'rad':'Radiation', \
'wet':'Wet Day Frequency', \
'tmp':'Mean Temperature', \
'tmx':'Maximum Temperature', \
'tmn':'Minimum Temperature', \
'vap':'Vapour Pressure', \
'wnd':'Wind',\
'uas':'Eastward wind', \
'vas':'Northward wind', \
'huss':'Specific humidity', \
'tas':'Air Temperature', \
'tasmax':'Air Temperature, daily max', \
'tasmin':'Air Temperature, daily min', \
'rsds':'Downwelling shortwave flux at surface', \
'pr':'Precipitation rate', \
'psl':'Sea level pressure'}

kl = ['uas', 'vas', 'huss', 'tas', 'pr', 'psl','rsds','tasmax','tasmin']
for k in kl:
  cru_vdict[ k + '-change' ] = cru_vdict[k] + ' (change)'

ta = open( 'data/tar_aliasses.txt', 'r' )
tar_vdict = {}
for l in ta.readlines():
  a,b = string.split(string.strip(l), '=')
  tar_vdict[ string.strip(a) ] = string.strip(b)
ta.close()

def iget(rq,id,default):
  if rq.fields.has_key( id ):
      return int( rq.fields[id].value ) - 1
  else:
      return default

class navrq:

  def __init__(self,o1,rq,path, flistd,mlist,mopts):

    ## path= '/cgi-bin/nav/%s' % p
    bits = string.split( path, '/' )
    self.ff = {}
    for b in bits:
        bb = string.split(b, '=' )
        if bb[0] in ['mime','dataset']:
          try:
            self.ff[str(bb[0])] = bb[1]
          except:
            o1.write( 'failed to set element of ff\n' )
    datasetID = self.ff.get( 'dataset','cru21' )
    flist = flistd[datasetID]

    o1.write( '---navrq: set datasetID = %s\n ' % datasetID )
    s1 = []
    d1 = []
    s1vals = []
    ee = {}
    doooo = 1
    m1 = ' '
    for (m,kdef) in mlist:
        k = iget(rq, m, kdef )
        ee[m] = mopts[m][k]

    o1.write( '--navrq: set ee\n' )
    for k in rq.fields.keys():
        if k[0] in ['=','z']:
            if k[1:] in flist:
              s1.append( k[1:] )
              s1vals.append( rq.fields[k].value )
              if k[0] == 'z':
                d1.append( k[1:] )
            elif k[1:] in map( lambda t: t[0], mlist):
              ee[k[1:]] = rq.fields[k].value
        elif k[0:4] == 'mime':
          if k == 'mimeCSV':
            self.ff['mime'] = 'csv'

    o1.write( '--navrq: finished 1st loop\n' )
    for k in rq.fields.keys():
        m1 += '<br/>%s :: %s ' % (k,rq.fields[k].value)
        if k[0] == '+':
          s1.append( k[1:] )
          s1vals.append( rq.fields[k].value )
        elif k[0] == '*':
          if k[1:] in flist:
            s1.append( k[1:] )
            s1vals[s1.index( k[1:] ) ] = rq.fields[k].value
          else:
            for (m,kdef) in mlist:
              if k[1:] in mopts[m]:
                ee[m] = k[1:]
        elif k[0] == '-':
           s1vals.pop( s1.index( k[1:] ) )
           s1.pop( s1.index( k[1:] ) )
        elif k[0] == '#':
          f = fdict_inv[ k[2] ]
          val = k[3:]
          if k[1] == '+':
            s1.append( f )
            s1vals.append( val )
          elif k[1] == '*':
            if f in flist:
              s1.append( f )
              s1vals[s1.index( f ) ] = val
            else:
              for (m,kdef) in mlist:
                if f in mopts[m]:
                  ee[m] = f
          elif k[1] == '-':
             s1vals.pop( s1.index( f ) )
             s1.pop( s1.index( f ) )

    o1.write( '--navrq: finished 2nd loop\n' )
    for field in flist:
        val = iget(rq, field, None )
        if val != None:
          s1.append( field )
          s1vals.append( val )

## modified ##
    p = path
    bits = string.split( p, '/' )
    for b in bits:
        bb = string.split(b, '=' )
        if bb[0] in flist:
          if bb[0] in s1:
            raise 'duplicate parameter setting'
          else:
            s1.append( bb[0] )
            s1vals.append( bb[1] )
        else:
          try:
            self.ff[str(bb[0])] = bb[1]
          except:
            o1.write( 'failed to set element of ff\n' )

    self.set = []
    self.deflt = []
    self.setvals = []
    for f in flist:
      if f in s1:
        self.set.append(f)
        self.setvals.append( s1vals[s1.index(f)] )
        if f in d1:
          self.deflt.append(f)
    self.ee = ee


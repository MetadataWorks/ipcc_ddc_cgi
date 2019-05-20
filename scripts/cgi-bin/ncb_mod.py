#!/usr/bin/python
import string
import utils, sys, stat, os

 
mnths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
seas = ['djf','mam','jja','son','annual']

fmts = {'air_temperature':'%5.1f', 'air_temperature_anomaly':'%5.2f', 
        'tmp':'%5.2f', 'tmn':'%5.2f', 'tmx':'%5.2f', 'pre':'%7.2f',
        'frs':'%5.2f', 'dtr':'%5.2f', 
        'precipitation_flux':'%7.2f', 'precipitation_flux_anomaly':'%6.3f',
        'surface_downwelling_shortwave_flux_in_air':'%6.1f',
        'surface_downwelling_shortwave_flux_in_air_anomaly':'%6.3f',
        'air_pressure_at_sea_level':'%8.0f', 'air_pressure_at_sea_level_anomaly':'%6.1f',
        'latitude':'%6.2f','latitude_bounds':'%6.2f'}

def ccget( rq, targ, df, ax ):
        yy = cget( rq, targ, df )
        ytarg = float( yy )
        dy = min( abs( ax - ytarg  ) )
        iy = 1
        for i in range(len(ax)):
          if abs( ax[i] - ytarg ) - dy < 0.001:
            return (ytarg, i)
        return (ytarg, iy)

def iget(rq,id,default):
  if rq.fields.has_key( id ):
     return int( rq.fields[id].value ) - 1
  else:
     return default

def cget(rq,id,default):
  if rq.fields.has_key( id ):
     return rq.fields[id].value
  else:
     return default

def axname( ax, default ):
      try:
        name = ax.name
      except:
        try:
          name = ax.name_in_file
        except:
          name = default
      return name

def slice2table(title,xname,xvals,yname,yvals,v,axesReorder,fmt,factor,mime='html'):
  mess = ' '
  try:
      if mime == 'html':
        data_display = '<h2>%s</h2>\n' % title

        data_display += '<table border="2">\n'
        data_display += '<tr><th rowspan="2"><i>%s</i></th><td colspan="%s"><i>%s</i></td></tr>\n' % (yname,len(xvals),xname)
        data_display += '<tr>\n'
        for x in xvals:
          data_display += '<td><i>%6.2f</i></td>' % x
        data_display += '\n</tr>\n'
      else:
        data_display = '<DATA>\n'
        data_display += 'AXES,' 
        for x in xvals:
          data_display += '%6.2f,' % x
        data_display += '\n'


      llist = range(len(yvals))
      if yvals[-1] > yvals[0]:
        llist.reverse()
      sl = [0,0]
      if axesReorder:
        islx = 0
        isly = 1
      else:
        isly = 0
        islx = 1

      for j in llist:
        if mime == 'html':
          data_display += '<tr>\n'
          data_display += '<th><i>%6.2f</i></th>' % yvals[j]
        else:
          data_display += '%6.2f,' % yvals[j]
        sl[isly] = j
        sl[islx] = slice(0,len(xvals) )
        for d in v[sl].tolist():
          dv = fmt % (d*factor)
          if mime == 'html':
            data_display += '<td>%s</td>' % dv 
          else:
            data_display += '%s,' % dv 
        if mime == 'html':
          data_display += '\n</tr>'
        data_display += '\n'
      if mime == 'html':
        data_display += '</table>\n'
      return data_display
  except:
    mess = 'failed<br/><br/>' + data_display
    return mess
   

class ncb_open:
  tmpl_xyt1 ='templates/ncb_template_xyt1.txt'
  tmpl_xyt2 = 'templates/ncb_template_xyt2.txt'

  def __init__(self, path,fh=None,reraise=False,rptFile='/tmp/downl_report.txt'):

    try:
      ddd = utils.ddc_file( path,rptFile=rptFile )

      self.found = True
      self.path = path
      ddd.check_file()
      if ddd.file_not_found:
        if fh != None:
          fh.write( 'ncb_mod:: File not found\n' )
        sys.stdout.write( 'ncb_mod:: File not found' )
        self.found = False
      self.ddd = ddd
    except:
      if fh != None:
          fh.write( 'ncb_mod:: error\n' )
          fh.write( 'path:: %s\n' % path )
      sys.stdout.write( 'ncb_mod:: error' )
      self.found = False
      if reraise:
        raise
    self.openned = False

  def get_csv_header(self):
     tmpl = '''Conventions,G,BADC-CSV,1
title, G, My data file
creator, G, Prof W E Ather, Reading
contributor, G, Sam Pepler, BADC
creator, G, A. Pdra
variable_name, 1, time, days since 2007-03-14
variable_name, 2, air temperature
variable_name, 3, met station air temperature
creator, 3, unknown,Met Office
coordinate_variable,1, x
location_name, G, Rutherford Appleton Lab
data'''
  

  def get_time_info(self):
    try:
      return self.time_info
    except:
      return (0,0,0,0)

  def get_html(self):
    if self.ddd.filetype == 'nc':
      out = 'nc\n'
      try:
        import cdms
        self.cdmsv = 1
      except:
        import cdms2 as cdms
        self.cdmsv = 2

      try:
        nc = cdms.open( self.ddd.this_file, 'r' )
        gl = nc.listglobal()
        gl.sort()
        stem = string.split( string.split( self.ddd.this_file, '/' )[-1], '.')[0]

        bits = string.split( stem, '_' )
        out = '<h2>Global attributes</h2>\n<ul>\n'
        for g in gl:
          gv = nc.getglobal( g )
          out += '<li>%s: %s</li>\n' % (g,str(gv)) 
        out += '</ul><br/>\n\n' 
        scenario = nc.getglobal( 'scenario_tag' )
        model = nc.getglobal( 'model_tag' )

        startYear, startMonth, startDay, endYear = utils.cf_time_info( nc, tAx, bounds='clim_bounds' )
        trange = '%s-%s' % (startYear, endYear)
        self.time_info = (startYear, startMonth, startDay, endYear)

        vk = nc.variables.keys()
        vk.sort()
        for v in vk:
           Axes = map( lambda x: x.attributes.get('standard_name','-'), nc.variables[v].getAxisList() )
           axesstring =  string.join( Axes, ', ' )
           out += '<h2>%s [ %s ]</h2>' % (v,axesstring) 
           out += '<a href="/cgi-bin/ncbv/%s/%s">View data</a>\n' % (self.path,v) 
           ak = nc.variables[v].attributes.keys()
           ak.sort()
           out += '<ul>\n' 
           for a in ak:
             out += '<li>\n%s::%s\n</li>' % (a,nc.variables[v].attributes[a]) 

           if len( nc.variables[v].shape ) == 3:
             standard_name = nc.variables[v].attributes.get('standard_name', nc.variables[v].attributes['name'] )
           out += '</ul>\n' 
        out += '<br/>%s, %s, %s, %s\n' % (standard_name, model, scenario, trange) 
        nc.close()
      except:
        out += 'failed to construct html'
        raise
      return out

  def check_open(self):
    if self.openned:
      return True
    try:
      file = self.ddd.this_file
      html = '%s <br/>' % file
      try:
        import cdms
        self.nc = cdms.open( file, 'r' )
        self.cdmsv = 1
      except:
        import cdms2
        self.nc = cdms2.open( file, 'r' )
        self.cdmsv = 2
      self.openned = True
      return True
    except:
      return False

  def get_ascii_xy(self,rq,variable=None, mime='html'):

    html = 'trying <br/>'
    if not self.check_open():
        return (1, 'failed to open file','   ','could not open %s<br/>' % self.ddd.this_file)

    pmess = ' xxx  '
    try:
      nc = self.nc
      vk = nc.variables.keys()
      html += '%s <br/>' % str( vk )
      nsn = 0
      
      for vv in vk:
           if len( nc.variables[vv].shape ) == 3:
             html += '%s <br/>' % str(nc.variables[vv].attributes.keys())
             standard_name = nc.variables[vv].attributes.get('standard_name', nc.variables[vv].attributes['name'] )
             v = vv

             nsn += 1
      if nsn != 1:
        if nsn > 1:
          return (0,' ', ' ','more than one named rank 3 variable in file')
        else:
          return (0,' ', ' ','no named rank 3 variable in file')
    except:
      return (1, 'failed to identify variable','   ',html)

    self.variable_name = v

    if  nc.variables[v].attributes.has_key('standard_name'):
      self.standard_name = standard_name
    else:
      self.standard_name = None

    if mime == 'csv':
      self.make_csv_header()

    try:
      html += '%s<br/>' % standard_name
      var = nc.variables[v]
      data = nc.variables[v].getValue()
      Axes = nc.variables[v].getAxisList()
      fmt = fmts.get( v, '%s' )
      tAx = nc.getAxis( 'time' )
      yAx = nc.getAxis( 'latitude' )
      xAx = nc.getAxis( 'longitude' )
      yAxes = yAx.getValue()
      xAxes = xAx.getValue()

      if rq.fields.has_key( 'forwardbutton' ):
        lat0 = iget( rq, 'startY', 0 )
        lat9 = iget( rq, 'endY', min(len(yAxes)-1,5) )
        lon0 = iget( rq, 'startX', 0 )
        lon9 = iget( rq, 'endX', min(len(xAxes)-1,5) )
        xtarg0 = xAxes[lon0]
        xtarg9 = xAxes[lon9]
        ytarg0 = yAxes[lat0]
        ytarg9 = yAxes[lat9]
      else:
        ytarg0, lat0 = ccget( rq, 'YY0', '0.00', yAxes )
        ytarg9, lat9 = ccget( rq, 'YY9', '30.00', yAxes )
        xtarg0, lon0 = ccget( rq, 'XX0', '0.00', xAxes )
        xtarg9, lon9 = ccget( rq, 'XX9', '30.00', xAxes )

      ##if ix > len( xAxes ) -1:
        ##ix = len( xAxes ) -1
      ##if iy > len( yAxes ) -1:
        ##iy = len( yAxes ) -1

      html += 'zz'
      startYear, startMonth, startDay, endYear = utils.cf_time_info( nc, tAx, bounds='clim_bounds' )
      trange = '%s-%s' % (startYear, endYear )
      self.time_info = (startYear, startMonth, startDay, endYear)

      kt=0
      km=0
      plot_mean = False
      try:
        if rq.fields.has_key( 'monthSeason'):
          msv = '??'
          try:
            msv = rq.fields['monthSeason'].value
            if msv in ['djf','mam','jja','son','annual']:
              plot_mean = True
            else:
              plot_mean = False
              km = int(msv) - 1
          except:
            msv = '???'
        else:
          msv = 'unset'
      except:
        msv = 'could not set'

      if msv == 'unset':
        cmsv = 'Jan'
      elif plot_mean:
        cmsv = msv
      else:
        cmsv = mnths[km]
      html += 'msv = %s<br/>' % str(msv)
      sel = { True:' selected="selected"', False:'' }
      sel2 = { True:' disabled="disabled"', False:'' }

      if mime == 'csv':
        self.csv_header_append( 'Attribute','g','Time period in year', cmsv )
        self.csv_header_append( 'Attribute','g','Start year', startYear )
        self.csv_header_append( 'Attribute','g','End year', endYear )
      
      il = range(len(yAxes))
      if yAxes[-1] > yAxes[0]:
          il.reverse()
      displayModes = ''
      dm2 = '<center>Select display mode:<br/>'
      if mime == 'html':
        try:
          dm = ['xy','ts']
          dmn = ['Latitude-Longitude grid','Time series at a point']
          for k in range(len(dm)):
            displayModes +=    \
              '<option value="%s"%s>%s</option>\n' % (k+1,sel[k==0],dmn[k])
            dm2 += '<input type="submit"%s name="*%s" value="%s"/><br/>\n' % (sel2[k==0],dm[k],dmn[k])
        except:
          displayModes = 'zzzzzzzzzzzzzzzzzzzz'
        dm2 += "</center>"

        time_options = ' '
        for k in range(12):
          time_options += '<option value="%s"%s>%s</option>\n' % (k+1,sel[km==k],mnths[k])
        for k in range(len(seas)):
          time_options += '<option value="%s"%s>%s</option>\n' % (seas[k],sel[msv==seas[k]],seas[k])

        start_y_options =' '
        end_y_options =' '
        end_y_label = 'Upper Latitude'
        start_y_label = 'Lower Latitude'

        for k in il:
          start_y_options +=    \
            '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==lat0],yAxes[k])
          end_y_options +=    \
            '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==lat9],yAxes[k])

        end_x_label = 'Upper Longitude'
        start_x_label = 'Lower Longitude'
        start_x_options =' '
        end_x_options =' '
        for k in range(len(xAxes)):
          start_x_options +=    \
            '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==lon0],xAxes[k])
          end_x_options +=    \
            '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==lon9],xAxes[k])

      yname = axname( yAx, 'Y' )
      xname = axname( xAx, 'X' )
      if mime == 'csv':
        self.csv_header_append( 'Comment','First column',yname, ' ' )
        self.csv_header_append( 'Comment','First row',xname, ' ' )

      html += 'axes: %s, %s<br/>' % (xname,yname)
      s = data.shape
      sl = [0,0,0]
      islt = Axes.index( tAx )
      isly = Axes.index( yAx )
      islx = Axes.index( xAx )

      if lat0 > lat9:
          yslice = slice( lat9, lat0+1 )
      else:
          yslice = slice( lat0, lat9+1 )

      sl[islt] = km
      sl[isly] = yslice
      sl[islx] = slice( lon0, lon9+1 )

      if standard_name in ['precipitation_flux_anomaly','precipitation_flux']:
        units = 'mm/day'
        factor = 3600*24
      elif standard_name in ['precipitation_amount']:
        units = 'mm/month'
        factor = 1
      else:
        factor = 1
        units = var.attributes['units']
        if standard_name == 'air_temperature' and units == 'hPa':
          units = 'Celsius'

      if variable in utils.cru_vdict.keys():
          display_name = utils.cru_vdict[variable]
      elif variable in utils.tar_vdict.keys():
          display_name = utils.tar_vdict[variable]
      else:
          display_name = standard_name

      title = '%s [%s], %s' % (display_name,units,cmsv)
      html += '<br/>xxx'
      html += '<br/>' + str(sl)
      html += '<br/>' + str(data[sl].shape)
      html += '<br/>' + xname
      html += '<br/>' + yname
      html += '<br/>' + str(xAxes[lon0:lon9+1])
      html += '<br/>' + str(plot_mean)
      if not plot_mean:
        data_display = slice2table( title, xname, xAxes[lon0:lon9+1], yname, yAxes[yslice], data[sl], isly > islx, fmt, factor, mime=mime )
      else:
        html += '<br/>' + str(msv)
        t =  { 'annual':(0,12), 'mam':(2,5), 'jja':(5,8),'son':(8,11),'djf':[(11,12),(0,2)] }[msv]
        html += '<br/> time slice: ' + str(t)
        pmess += '<br/> %s <br/>' % str(t)
        pmess += '%s<br/>\n' % str( type )
        pmess += '%s<br/>\n' % str(  t[0] )
        try:
          import Numeric
          import MA as thisMa
        except:
          import numpy
          import numpy.ma as thisMa
        if type( t[0] ) == type(0):
          sl[islt] = slice( t[0],t[1] )
          html += '<br/>' + str(sl)
          html += '<br/> data shape:: ' + str(data.shape)
          pmess += 'zzzz<br/>\n' 
          vv = thisMa.masked_outside( data[sl].tolist(), -990., 900. )
          v = thisMa.average( vv, axis=islt )
          v = thisMa.masked_values( v, -999. )
        else:
          sl1 = sl[:]
          sl[islt] = slice(t[0][0],t[0][1])
          sl1[islt] = slice(t[1][0],t[1][1])
          pmess += 'qqqq<br/>\n' 
          vv = thisMa.masked_outside( data[sl].tolist(), -990., 900. )
          vv1 = thisMa.masked_outside( data[sl1].tolist(), -990., 900. )
          pmess += 'qqqq<br/>\n' 
          v = (thisMa.sum( vv, axis=islt ) + thisMa.sum( vv1, axis=islt ) )/3.
          v = thisMa.masked_values( v, -999. )
          pmess += 'qqqq<br/>\n' 
        html += '<br/> calling slice2table'
        data_display = slice2table( title, xname, xAxes[lon0:lon9+1], yname, yAxes[yslice], v, isly > islx, fmt, factor, mime=mime )
        pmess += 'qqqq<br/>\n' 
        html += '<br/> back from slice2table'
      
      if mime == 'html':
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('YY0',ytarg0)
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('YY9',ytarg9)
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('XX0',xtarg0)
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('XX9',xtarg9)
      html += '<br/>display generated' 
      if mime == 'html':
        try:
          x = 0
          import os
          ii = open( self.tmpl_xyt1, 'r' )
          x = 3
          html_pat = ii.readlines() 
          x = 1
          html_pat = string.join( html_pat )
          x = 2
          table_html = html_pat % locals()

        except:
          if x == 2:
            data_display += '<br/> could not generate table'
          elif x == 1:
            data_display += '<br/> could not join template'
          elif x == 3:
            data_display += '<br/> could not read template'
          else:
            data_display += '<br/> could _open template'
          table_html = ' '
      else:
          table_html = ' '
      rv = 0
      table_html += dm2
      pmess += str( data.shape )
      pmess += '<br/> %s ' % islt
      return (rv,html,table_html, data_display)
    except:
      return (1, 'failed','   ',html + pmess)

  def make_csv_header(self):
     self.csv_header = 'Convention,"IPCC DDC CSV Format","Provisional",0.5,\n'
     scenario = self.nc.getglobal( 'scenario_tag' )
     model = self.nc.getglobal( 'model_tag' )

     if self.ddd.datasetid == 'ar4_gcm':
       self.csv_header += 'Attribute,g,"%s","%s",\n' % ('Dataset','IPCC AR4 Climate projections')
       self.csv_header += 'Attribute,g,"%s","%s",\n' % ('Scenario',scenario)
       self.csv_header += 'Attribute,g,"%s","%s",\n' % ('Model',model)
     elif self.ddd.datasetid == 'cru21':
       self.csv_header += 'Attribute,g,"%s","%s",\n' % ('Dataset','Climate Research Unit Gridded Data TS 2.1')

     if self.standard_name != None:
       self.csv_header += 'Attribute,v,"%s","%s",\n' % ('Standard name',self.standard_name)
     self.csv_header += 'Attribute,v,"%s","%s",\n' % ('Units',self.nc.variables[self.variable_name].attributes.get('units','No specified'))
     self.csv_header += 'Attribute,v,"%s","%s",\n' % ('Name',self.variable_name)

  def csv_header_append( self, l,t,k,v ):
     self.csv_header += '%s,%s,%s,%s,\n' % (l,t,k,v)

  def get_ascii_ts(self, o1, rq, tslice='1931-1960', opt='decadal', mime='html', variable=None):

    o1.write( 'starting get_ascii_ts\n' )
    html = 'trying <br/>'
    if not self.check_open():
        return (1, 'failed to open file','   ','could not open %s<br/>' % self.ddd.this_file)

    table_html = 'table not done'
    data_display = 'data_display not done'
    sel = { True:' selected="selected"', False:'' }
    try:
      nc = self.nc
      vk = nc.variables.keys()
      nsn = 0
      
      for vv in vk:
         if len( nc.variables[vv].shape ) == 3:
             v = vv
             standard_name = nc.variables[v].attributes.get('standard_name', nc.variables[v].attributes['name'] )

             nsn += 1
      if nsn != 1:
        if nsn > 1:
          return (0,' ', ' ','more than one named rank 3 variable in file')
        else:
          return (0,' ', ' ','no named rank 3 variable in file')
    except:
        rv = 1
        return (rv,html,table_html, 'could not find suitable variable')


    if  nc.variables[v].attributes.has_key('standard_name'):
      self.standard_name = standard_name
    else:
      self.standard_name = None

    self.variable_name = v
    if mime == 'csv':
      self.make_csv_header()

    try:
      html += '%s<br/>' % standard_name
      var = nc.variables[v]
      data = nc.variables[v].getValue()
      Axes = nc.variables[v].getAxisList()
      fmt = fmts.get( v, '%s' )
      tAx = nc.getAxis( 'time' )
      yAx = nc.getAxis( 'latitude' )
      xAx = nc.getAxis( 'longitude' )
      yAxes = yAx.getValue()
      xAxes = xAx.getValue()
      tAxes = tAx.getValue()

##
## when submitted from the area selector, use those values,
## otherwise use the values from the hidden inputs, which are saved as lat and long, 
## rather than indicies. This means we don't get shifted to a totally different domain
## when the model is switched.
##
      if rq.fields.has_key( 'forwardbutton' ):
        ix = iget( rq, 'IX', 0 )
        iy = iget( rq, 'IY', 0 )
        xtarg = xAxes[ix]
        ytarg = yAxes[iy]
      else:
        yy = cget( rq, 'YY', '0.00' )
        ytarg = float( yy )
        dy = min( abs( yAxes - ytarg  ) )
        iy = 1
        for i in range(len(yAxes)):
          if abs( yAxes[i] - ytarg  ) - dy < 0.001:
            iy = i
        xx = cget( rq, 'XX', '0.00' )
        xtarg = float( xx )
        dx = min( abs( xAxes - xtarg  ) )
        ix = 1
        for i in range(len(xAxes)):
          if abs( xAxes[i] - xtarg  ) - dx < 0.001:
            ix = i

      if ix > len( xAxes ) -1:
        ix = len( xAxes ) -1
      if iy > len( yAxes ) -1:
        iy = len( yAxes ) -1

      html += 'zz %s, %s\n' % (str(ix), str(iy) )
      if self.ddd.datasetid == 'cru21':
        startYear, startMonth, startDay, endYear = utils.cf_time_info( nc, tAx,bounds='clim_bounds' )
      else:
        startYear, startMonth, startDay, endYear = utils.cf_time_info( nc, tAx,bounds='clim_bounds' )
        ## startYear, startMonth, startDay, endYear = utils.cf_time_info( nc, tAx )
      trange = '%s-%s' % (startYear, endYear )
      self.time_info = (startYear, startMonth, startDay, endYear)

########################################################################
############### region selection for html page #########################
########################################################################
      if mime == 'html':
        displayModes = ''
        sel2 = { True:' disabled="disabled"', False:'' }
        dm2 = '<center>Select display mode:<br/>'
        dm = ['xy','ts']
        dmn = ['Latitude-Longitude grid','Time series at a point']
        for k in range(len(dm)):
          dm2 += '<input type="submit"%s name="*%s" value="%s"/><br/>\n' % (sel2[k==1],dm[k],dmn[k])
        dm2 += "</center>"
        try:
          dm = ['xy','ts']
          dmn = ['Latitude-Longitude grid','Time series at a point']
          for k in range(len(dm)):
              displayModes +=    \
                '<option value="%s"%s>Display as: %s</option>\n' % (k+1,sel[k==1],dmn[k])
        except:
          displayModes = 'zzzzzzzzzzzzzzzzzzzz'
        x_options =' '
        y_options =' '
                  
        html += '<br/>xxx'
        for k in range(len(yAxes)):
          y_options +=    \
            '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==iy],yAxes[k])

        html += '<br/>xxx'
        for k in range(len(xAxes)):
          x_options +=    \
              '<option value="%s"%s>%6.2f</option>\n' % (k+1,sel[k==ix],xAxes[k])

######################################################################

      html += 'xxx'
      sl = [0,0,0]
      islt = Axes.index( tAx )
      isly = Axes.index( yAx )
      islx = Axes.index( xAx )
      html += 'xxx'
      sl[islt] = slice( 0, len( tAx ) )
      sl[isly] = iy
      sl[islx] = ix
      html += 'xxx'
      x_label = 'Longitude'
      y_label = 'Latitude'

      data = nc.variables[v].getSlice( sl[0], sl[1], sl[2] )
      html += '<br/>' + str( dir(tAx) )
      html += '<br/>zzzzzzzzzzzzzzzzz<br/>' + str( dir(tAx.getExplicitBounds()) )
      cpos = 'Position: %s, %s' % (ix,iy)
      cpos = 'position: %7.2fE, %7.2fN' % (xAxes[ix],yAxes[iy])
      if mime == 'csv':
        self.csv_header_append( 'Attribute','g','Latitude','%7.2fN' % yAxes[iy] )
        self.csv_header_append( 'Attribute','g','Longitude','%7.2fN' % xAxes[ix] )
     ##   self.csv_header_append( 'Attribute','g','Start year', startYear )
     ##   self.csv_header_append( 'Attribute','g','End year', endYear )
      
        self.csv_header_append( 'Comment','First column','Time: days from start of year', ' ' )
        self.csv_header_append( 'Comment','Second column','Month of year', ' ' )
        self.csv_header_append( 'Comment','First row','Years averaged over', ' ' )
        self.csv_header_append( 'Comment','Second row','Scenario', ' ' )

      html += '<br/>xxx'

      yname = axname( yAx, 'Y' )
      xname = axname( xAx, 'X' )
      tname = 'Time [%s]' % tAx.units
      tname = 'Time [days from start of year]'

      html += 'axes: %s, %s<br/>' % (xname,yname)
      html += '<br/>xxx [checking datasetid %s]<br/>' % self.ddd.datasetid
      if self.ddd.datasetid == 'ar4_gcm':
        scenario = nc.getglobal( 'scenario_tag' )
        model = nc.getglobal( 'model_tag' )

        if scenario in ['COMMIT','SRA2','SRA1B','SRB1']:
          slist = ['COMMIT','SRA2','SRA1B','SRB1']
          trl = ['2011-2030','2046-2065','2080-2099']
        elif scenario in ['1PTO2X','1PTO4X']:
          slist = ['1PTO2X','1PTO4X' ]
          if tslice in ['o0001-0030','o0031-0060','o0061-0090']:
            trl = ['o0001-0030','o0031-0060','o0061-0090']
          else:
            trl = ['o0010-0039','o0046-0065','o0080-0099','o0180-0199']
        else:
          slist = [scenario]
          if scenario == '20C3M':
            trl = ['1901-1930','1931-1960','1961-1990']
          elif scenario == 'PICTL':
            if tslice in ['o0001-0030','o0031-0060','o0061-0090']:
              trl = ['o0001-0030','o0031-0060','o0061-0090']
            else:
              trl = ['o0010-0039','o0046-0065','o0080-0099','o0180-0199']
      elif self.ddd.datasetid == 'tar_gcm':
        path = self.path
        file = string.strip( string.split( path, '/' )[-1] )
        bits = string.split( file, '_' )
        scenario = bits[1]
        model = bits[0]

        slist = ['A1F','A1T','A1a','A2a','A2b','A2c','B1a','B2a','B2b']
        trl = ['1980', '2020', '2050', '2080' ]
      else:
        trl = []
        slist = ['Observations']
        scenario = slist[0]
        if opt == 'decadal':
          for i in range(10):
              trl.append( '%s-%s' % ( 1901 + 10*i, 1910 + 10*i ) )
        else:
          for i in range(3):
            trl.append( '%s-%s' % ( 1901 + 30*i, 1930 + 30*i ) )

        
      try:
        import Numeric
        thisZeros = Numeric.multiarray.zeros
      except:
        import numpy
        thisZeros = numpy.zeros
      lx = len(slist)*len(trl)
      dv = thisZeros( (12,lx), 'f' )
      iii = 0
      mess = ''
      for tr in trl:
           html += '<br/> %s::%s ' % (tr,trange)
           html += '<br/> %s ' % self.ddd.this_file
           for s in slist:
              html += '<br/> %s:: ' % s
              if s == scenario and tr == tslice:
               dv[:,iii] = data.tolist()
              else:
               if self.ddd.datasetid  in ['tar_gcm', 'ar4_gcm']:
                 nf = string.replace( self.ddd.this_file, scenario, s )
               else:
                 nf = self.ddd.this_file

               if string.find( nf, tslice ) == -1:
                 o1.write( 'could not fine %s in %s\n' % (tslice, nf ) )
                 raise 'broken'

               nf = string.replace( nf, tslice, tr )
               if self.ddd.datasetid  in ['tar_gcm']:
                 sln = string.lower(s)
                 nf = string.replace( nf, string.lower(scenario), sln )
               if os.path.isfile( nf ) and os.stat(nf)[stat.ST_SIZE] > 128:
                  try:
                    import cdms
                    nc2 = cdms.open( nf, 'r' )
                    self.cdmsv = 1
                  except:
                    import cdms2
                    nc2 = cdms2.open( nf, 'r' )
                    self.cdmsv = 2
                  ##import cdms
                  html += '<br/> ' + nf + '\n'
                  data2 = nc2.variables[v].getSlice( sl[0], sl[1], sl[2] )
                  mess += '<br/> %s %s %s' % (nf,data2[0],iii)
                  html += '<br/> %s %s %s' % (nf,data2[0],iii)
                  html += '<br/> %s %s' % (str(data2.shape), str(dv.shape))
                  html += 'z'
                  dv[:,iii] = data2.tolist()
                  nc2.close
                  html += 'z'
               else:
                  o1.write( 'no data for %s\n' % nf )
                  dv[:,iii] = -999.
              iii += 1
      html += '<br/> data_dispay --- %s  '  % cpos
      html += '<br/> data_dispay --- %s  '  % tname
      html += '<br/> data_dispay --- %s  '  % str(trl)
      fmt = fmts.get( v, '%s' )
      if standard_name in ['precipitation_flux_anomaly','precipitation_flux']:
        units = 'mm/day'
        factor = 3600*24
      elif standard_name in ['precipitation_amount']:
        units = 'mm/month'
        factor = 1
      else:
        factor = 1
        units = var.attributes['units']
        if standard_name == 'air_temperature' and units == 'hPa':
          units = 'Celsius'

      if variable in utils.cru_vdict.keys():
          display_name = utils.cru_vdict[variable]
      elif variable in utils.tar_vdict.keys():
          display_name = utils.tar_vdict[variable]
      else:
          display_name = standard_name

      title = '%s [%s], %s' % (display_name,units,cpos)
      html += '<br/>to utils.slice2table_1b .... '
      (rv, data_display) = utils.slice2table_1b(  title, tname, tAxes, 'Month', mnths, trl,slist, dv, fmt, factor, mime=mime )
      html += 'back from utils.slice2table_1b<br/>\n'
###################
#### rv ==0 indicates failure, add comments to display.
      if rv == 0:
          data_display = html + data_display

      if mime == 'html':
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('YY',ytarg)
        data_display += '<input type="hidden" name="%s" value="%7.3f"/>\n' % ('XX',xtarg)
      html += 'XXXX'

      if mime == 'html':
        o1.write( '--get_ascii_ts: reading template\n' )
        html_pat = string.join( open( self.tmpl_xyt2, 'r' ).readlines() )
        o1.write( '--get_ascii_ts: using template\n' )
        table_html = html_pat  % locals()
        o1.write( '--get_ascii_ts: adding dm2\n' )
        table_html += dm2
      html += 'XXXX'
      rv = 0
      return (rv,html,table_html, data_display)
    except:
        rv = 1
        return (rv,html,table_html, data_display)

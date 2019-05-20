#!/usr/bin/python
import cdms, os
import MA, string

### cycle longitude by 180
###
### getNewLonAxis written by Alan Iwi
###
### code below requires explicit coding for each rank and position of
### longitude within that rank. Currently only two variations
### are allowed for.
###

mn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
def extract_ij( ifile, ofile, i, j, verbose=0 ):


  oo = open( ofile, 'w' )
  f = cdms.open(ifile, 'r' )
  LonAxis = f.getAxis('longitude')
  LatAxis = f.getAxis('latitude')
  timeAxis = f.getAxis('time')
  time = f.getAxis('time').getValue()
  nlon = len(LonAxis)
  nlat = len(LatAxis)
  if i > nlon-1:
    raise 'request is beyong end of longitude range'
  if j > nlat-1:
    raise 'request is beyong end of latitude range'

  oo.write( '"Time units","%s",,,,\n' % timeAxis.attributes['units'] )
  oo.write( '"Longitude",%s,%s,\n' % (LonAxis.getValue()[i],LonAxis.attributes['units']) )
  oo.write( '"Latitude",%s,%s,\n' % (LatAxis.getValue()[j],LatAxis.attributes['units']) )
  if LonAxis.attributes.has_key( 'bounds' ):
    LonBounds = LonAxis.attributes['bounds']
    t = f.variables[LonBounds].getValue()
    oo.write( '"Longitudinal bounds","%s",%s,%s,\n' % (LonBounds,t[i,0],t[i,1]) )

  if LatAxis.attributes.has_key( 'bounds' ):
    LatBounds = LatAxis.attributes['bounds']
    t = f.variables[LatBounds].getValue()
    oo.write( '"Latitudinal bounds","%s",%s,%s,\n' % (LatBounds,t[j,0],t[j,1]) )

##
## loop through variables and cycle on longitude axis.
## NB: only a limited number of variable shapes are supported.
##
  for var in f.getVariables():
    Lon = var.getLongitude()
    Lat = var.getLatitude()
    if Lat and Lon:
        Axes = var.getAxisList()
            
        ii = Axes.index(LonAxis)
        jj = Axes.index(LatAxis)
        rank = var.rank()
        aa = var.getValue()
        print var.shape
        oo.write( 'Name, "%s",\n' % (var.attributes['name']) )
        oo.write( 'Units, "%s",\n' % (var.attributes['units']) )
        oo.write( 'Standard name, "%s",\n' % (var.attributes['standard_name']) )
        if rank == 3 and ii == 1 and jj == 2:
          for k in range(len(time)):
            oo.write( '%s, %s,\n' % (time[k],aa[k,i,j]) )
        if rank == 3 and ii == 2 and jj == 1:
          for k in range(len(time)):
            print time[k],k,j,i
            print aa[k,j,i]
            oo.write( '%s, %s, %s,\n' % (time[k],mn[k],aa[k,j,i]) )
        else:
          print rank, ii, jj
          print 'rank index combination not programmed for'

        if verbose > 0:
          print var.name, index, rank

  f.close()


if __name__ == "__main__":
  data_dir = '/usr/local/data/ipcc-ddc/data/netcdf/ar4_v2/'

  import sys
  if len(sys.argv) < 5:
    print 'usage: .... in_file out_file i j'
  
  else:
    file = sys.argv[1] 
    bits = string.split(file, '.' )
    if len( bits ) > 2:
      raise 'non compliant file name'

    ofile = sys.argv[2]
    i = long(sys.argv[3] )
    j = long(sys.argv[4] )


    extract_ij( data_dir + file, ofile, i,j )

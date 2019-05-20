#!/usr/bin/python
import cdms, os
import MA

def getNewLonAxis(oldLonAxis, startLon=-180):
    assert(oldLonAxis.isLongitude())
    oldLonVals = oldLonAxis.getData()

    newLonVals = (oldLonVals - startLon) % 360 + startLon  # range "startLon" to "startLon + 360"
    lonValShift = newLonVals - oldLonVals
    nlon = len(newLonVals)
##
## identify shift by jump in longitude values
    for i in range(1, nlon):
        if newLonVals[i] < newLonVals[i - 1]:
            nShift = i
            break
    else:
        nShift = 0

## create array with new longitude values
    newLonVals = MA.concatenate((newLonVals[nShift : ],
                                newLonVals[ : nShift ]))

##    print oldLonVals
##    print newLonVals
    
    newLonAxis = cdms.createAxis(newLonVals)
    newLonAxis.designateLongitude()
    newLonAxis.replace_external_attributes(oldLonAxis.attributes)
#   
    return newLonAxis, nShift, lonValShift




### cycle longitude by 180
###
### getNewLonAxis written by Alan Iwi
###
### code below requires explicit coding for each rank and position of
### longitude within that rank. Currently only two variations
### are allowed for.
###

def nc_lon_cyc( ifile, ofile, verbose=0 ):

  ii = os.popen( 'cp %s %s' %( ifile, ofile ), 'r' )
  ii.readlines()
  ii.close()
  ii = os.popen( 'chmod 777 %s' % ofile , 'r' )
  ii.readlines()
  ii.close()

  f = cdms.open(ofile, 'a' )
  oldLonAxis = f.getAxis('longitude')
  if oldLonAxis.attributes.has_key( 'bounds' ):
    oldLonBounds = oldLonAxis.attributes['bounds']
  axisMappings, nShift, lonValShift = getNewLonAxis(oldLonAxis)

  nlon = len(oldLonAxis)
  if nlon != nShift*2:
    print 'can only cope with shifts of half total length'
    print nlon, nShift
    raise 'config error'
  for k in range( len( oldLonAxis ) ):
    f.getAxis('longitude')[k] = axisMappings.getValue()[k]

##
## loop through variables and cycle on longitude axis.
## NB: only a limited number of variable shapes are supported.
##
  for var in f.getVariables():
    oldLonAxis = var.getLongitude()
    if oldLonAxis:
            
        newAxes = var.getAxisList()

        if var.name == oldLonBounds:
##
## the cf-checker likes the bounds to include the coordinate value in
## an absolute sense, so that bounds for -180. should be, e.g., [-182, -178],
## NOT [178,-178].
##

          if verbose > 0:
            print 'shifting bounds'
            print dir(var), var.getShape()

##
## shift longitude bounds by same amount as longitudes.
##
          va  = var.getValue()
          for j in range( var.getShape()[0] ):
            va[j,:] += lonValShift[j]
          var[:,:] = va

          if verbose > 1:
            print var.name, var
        
        index = newAxes.index(oldLonAxis)
        rank = var.rank()
        aa = var.getValue()
        if rank == 3 and index == 2:
          for i in range(nShift):
            var[:,:,i+nShift] = aa[:,:,i]
            var[:,:,i] = aa[:,:,i+nShift]
        elif rank == 2 and index == 0:
          for i in range(nShift):
            var[i+nShift,:] = aa[i,:]
            var[i,:] = aa[i+nShift,:]
        else:
          print rank, index
          raise 'rank index combination not programmed for'

        if verbose > 0:
          print var.name, index, rank

  f.history += '; longitude cycled to start at 180 degrees west'
  f.close()


if __name__ == "__main__":
  data_dir = '/usr/local/data/ipcc-ddc/data/netcdf/ar4_v2/'

  import sys
  if len(sys.argv) < 2:
    print 'usage: .... in_file [out_file]'
  
  else:
    file = sys.argv[1] 
    bits = string.split(file, '.' )
    if len( bits ) > 2:
      raise 'non compliant file name'

    if len(sys.argv) > 2:
      ofile = sys.argv[2]
    else:
      ofile = string.join( [string.split(bits[0], '/')[-1], 'cyto180W', bits[1]], '.' )


    u.nc_lon_cyc( data_dir + file, ofile )




file1 = '/badc/ipcc-ddc/data/netcdf/ar4_v2/huss/MIMR_1PTO2X_1_huss-change_o0080-0099.nc'
id1 = 'ar4_nc/IPCM4_1PTO4X_1_tas_o0040-0069.nc'
id1 = 'ar4_nc/huss/MIMR_1PTO2X_1_huss-change_o0080-0099.cyto180.nc'

import collections
##ntValue = collections.namedtuple( 'ntv', ['value'] )
class ntValue:
  def __init__(self,val):
    self.value = val

class dummyrq(object):

   def __init__(self):
     self.fields = {}
 
   def setMean(self):
     self.fields['monthSeason'] = ntValue( 'annual' )

class main(object):

  def __init__(self):
     self.ll = []
     pass

  def record(self,res,cls):
     self.ll.append( (res,cls.id,cls.msg) )
     print res,cls.id,cls.msg

  def out(self):
    for l in self.ll:
      print l

class baset(object):

  def __init__(self,parent):
    self.parent=parent
    self.run()
    self.__pass__()
    pass

  def __fail__(self):
    self.parent.record(False,self)

  def __pass__(self):
    self.parent.record(True,self)
    
class t1(baset):
  id = '01.001'
  msg = 'Testing import of ncb_mod'
  def run(self):
    import ncb_mod

class t2(baset):
  id = '01.002'
  msg = 'Testing import of utils'
  def run(self):
    import utils

class t3(baset):
  id = '01.003'
  msg = 'Testing instantiation of ddc_file'
  def run(self):
    import utils
    nc = utils.ddc_file( id1,rptFile='.tmp_rep.txt' )

class t4(baset):
  id = '01.004'
  msg = 'Testing instantiation of ncb_open'
  def run(self):
    import ncb_mod
    nc = ncb_mod.ncb_open( id1,rptFile='.tmp_rep.txt' )

class t5(baset):
  id = '01.005'
  msg = 'Testing ncb_open: open file'
  def run(self):
    import ncb_mod
    nc = ncb_mod.ncb_open( id1,rptFile='.tmp_rep.txt' )
    nc.check_open()

class t6(baset):
  id = '01.006'
  msg = 'Testing ncb_open: get_ascii_xy'
  def run(self):
    import ncb_mod
    nc = ncb_mod.ncb_open( id1,rptFile='.tmp_rep.txt' )
    nc.check_open()
    t = nc.get_ascii_xy(dummyrq(),variable='huss', mime='html')
    assert t[0] == 0, 'Failed to parse netcdf file\n %s'  % str(t)

class t7(baset):
  id = '01.007'
  msg = 'Testing ncb_open: get_ascii_xy with mean'
  def run(self):
    import ncb_mod
    nc = ncb_mod.ncb_open( id1,rptFile='.tmp_rep.txt' )
    nc.check_open()
    rq = dummyrq()
    rq.setMean()
    t = nc.get_ascii_xy(rq,variable='huss', mime='html')
    assert t[0] == 0, 'Failed to parse netcdf file\n %s'  % str(t)

mi = main()

for c in [t1,t2,t3,t4,t5,t6,t7]:
  try:
    inst = c(mi)
  except:
    mi.record(False,c)
    raise
    

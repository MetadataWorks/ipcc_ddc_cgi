import shelve
shelveDir = '/var/www/ipccddc_devel/shelves/'

def jds(sh,fn):
  oo = open( fn, 'w' )
  for k in sh.keys():
    oo.write( '%s=%s\n' % (k,str( sh[k])) )
  oo.close()
sh = shelve.open( shelveDir + 'ar4_v2_categories', 'r' )
jds( sh, 'ar4_v2_categories.txt' )
sh = shelve.open( shelveDir + 'tar_v2_categories', 'r' )
jds( sh, 'tar_v2_categories.txt' )

for n in range(1,5):
  sh = shelve.open( shelveDir + 'ar4_v2_navb_%s' % n, 'r' )
  jds( sh, 'ar4_v2_navb_%s.txt' % n )
for n in range(1,5):
  sh = shelve.open( shelveDir + 'tar_v2_navb_%s' % n, 'r' )
  jds( sh, 'tar_v2_navb_%s.txt' % n )


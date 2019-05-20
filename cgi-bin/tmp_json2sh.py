import shelve, string
shelveDir = '/tmp/shelves/'

def jds(sh,fn):
  oo = open( fn, 'r' )
  for l in oo.readlines():
    bits = string.split(string.strip(l),'=')
    k = bits[0]
    v = eval( bits[1] )
    sh[k] = v
  oo.close()
  sh.close()
sh = shelve.open( shelveDir + 'ar4_v2_categories' )
jds( sh, 'ar4_v2_categories.txt' )
sh = shelve.open( shelveDir + 'tar_v2_categories' )
jds( sh, 'tar_v2_categories.txt' )

for n in range(1,5):
  sh = shelve.open( shelveDir + 'ar4_v2_navb_%s' % n )
  jds( sh, 'ar4_v2_navb_%s.txt' % n )
for n in range(1,5):
  sh = shelve.open( shelveDir + 'tar_v2_navb_%s' % n )
  jds( sh, 'tar_v2_navb_%s.txt' % n )


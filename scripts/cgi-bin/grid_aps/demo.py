import cdms, time, MA

f = cdms.open( 'test0.nc', 'a' )

t = f.variables['air_temperature']

print time.time()
x = t.getValue()
for i in range(t.shape[0]):
 for j in range(t.shape[1]):
  x[i,j,:] += 2.
t[:,:,:] = x
print time.time()

for i in range(t.shape[0]):
 for j in range(t.shape[1]):
  t[i,j,:] = MA.array( t[i,j,:] + 2., 'f' )

print time.time()

f.close()


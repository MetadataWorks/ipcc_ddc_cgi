#!/usr/bin/python
import string, shelve, socket

import utils

def getShelveDir():
  host = socket.gethostname()
  if host == 'phobos':
    shelveDir = '/var/www/ipccddc_devel/shelves/'
  elif host == 'jddc1.ceda.ac.uk':
    shelveDir = 'shelves/'
  else:
    shelveDir = '/tmp/shelves/'
  return shelveDir

shelveDir = getShelveDir()

class dummy_request:

  def __init__(self):
    self.fields = {}


flist_aliasses = {'Ens':'Ensemble Member', 'Expt':'Scenario', 'Slice':'Time slice'}


def get_navtab(o1,ff,flist,olist,lm,set,unset,uopt,setvals,display_mode,datasetID=None,widths=None,deflt=[]):
  lset = set[:]
  lsetvals = setvals[:]
  o1.write( '--get_navtab: starting\n' )
  navtab = ' '
  navtab += '\n<center><table border="2" width="70%">\n<tr>\n'

  if datasetID == 'ar4_gcm':
    o1.write( '--get_navtab: lm = %s \n' % lm )
    if lm > 0:
      sh = shelve.open( shelveDir + 'ar4_v2_navb_%s' % lm, 'r' )
  elif datasetID == 'tar_gcm':
    o1.write( '--get_navtab: lm = %s \n' % lm )
    if lm > 0:
      sh = shelve.open( shelveDir + 'tar_v2_navb_%s' % lm, 'r' )

  idfs = []
  for f in flist:
        oo = ff[flist.index(f)]
        if f in unset:
          ooo = olist[flist.index(f)]
          action = '+'
        elif f in lset:
          action = '*'
          fv = setvals[set.index(f) ]
          s1 = set[:]
          sv = setvals[:]
          sv.pop( s1.index(f) )
          s1.pop( s1.index(f) )
          if lm == 0:
            ol = ff[:]
          else:
            key = string.join( sv, '_' )
            if datasetID in ['tar_gcm','ar4_gcm']:
              if sh.has_key(key):
                ol = sh[key][:]
              else:
                raise 'invalid key'
            else:
              ol = ff[:]
          ooo = ol[flist.index(f)][:]
          if fv in ooo:
            ooo.pop( ooo.index( fv ) )
        else:
          ooo = []

        nooo = 0
        thisov = 'dud'
        for ov in oo:
          if ov in ooo:
            thisov = ov
            nooo += 1
          elif ov in lsetvals:
            thisov = ov

        isdflt = nooo == 0
        idfs.append( isdflt )
             
  fset = {}
  kk = 0
  for f in flist:
    if f in lset and not idfs[kk]:
      fset[f] =  'set'
## attempt to make the page "remember" that a value has only been set by default fails here/ Uncommentign these
## causes a crash -- not clear why.
      ##lsetvals.pop( lset.index(f) )
      ##lset.pop( lset.index(f) )
    elif f in unset:
      fset[f] = 'unset'
    else:
      fset[f] = 'defaulting'
    kk+=1


  kk = 0
  for f in flist:
    xtr = ''
    if widths != None:
      xtr += ' width="%s%%"' % widths[kk]

    if f in unset:
      navtab += '<td class="%s" %s>Select</td>\n' % (fset[f],xtr)
    elif f in lset and not idfs[kk]:
      navtab += '<td class="set" %s>Change or unselect</td>\n' % xtr
    else:
      navtab += '<td class="defaulting" %s>Defaulting</td>\n' % xtr
    kk+=1
  navtab += '</tr><tr height="45px">\n'

  o1.write( '--get_navtab: 3rd loop\n' )
  kk = 0
  for f in flist:
    o1.write( '--get_navtab: 3rd loop %s ' % f )
    fa = flist_aliasses.get( f,f )
    if f in lset:
       o1.write( ' set\n' )
       fv = lsetvals[lset.index(f)]
       cls = { True:'defaulting', False:'set' }[idfs[kk]]
       navtab += '<th class="%s" width="18%%">%s=%s</th>' % (cls,fa,fv)
       ## navtab += '<th class="set" width="18%%">%s=%s<br/><input type="submit" name="-%s" value="(Unset)"/></th>' % (fa,fv,f )
    elif f in uopt:
       o1.write( ' uopt\n' )
       try:
         fv = olist[flist.index(f)][0]
         navtab += '<th class="defaulting" width="18%%">%s=%s</th>' % (fa,fv )
       except:
         o1.write( 'failed to deal with uopt\n' )
         o1.write( '%s, %s, %s\n' % (f, flist.index(f), len(olist) ) )
         o1.write( str(olist) )
         o1.write( '\n%s\n' % str(olist[flist.index(f)]) )
         navtab += '<th class="defaulting" width="18%%">Error</th>' 
         
    else:
       o1.write( ' other\n' )
       navtab += '<th class="%s" width="18%%">%s</th>' % (fset[f],fa)
    kk+=1

  o1.write( '--get_navtab: 3rd loop done\n' )
  navtab += '</tr><tr>\n'

  o1.write( '--get_navtab: 4th loop\n' )
  pmess = ''
  for f in flist:
        navtab += '<td class="%s">' % fset[f]
        oo = ff[flist.index(f)]
        if f in unset:
          ooo = olist[flist.index(f)]
          action = '+'
        elif f in lset:
          action = '*'
          fv = lsetvals[lset.index(f) ]
          s1 = lset[:]
          sv = lsetvals[:]
          sv.pop( s1.index(f) )
          s1.pop( s1.index(f) )
          if lm == 0:
            ol = ff[:]
          else:
            key = string.join( sv, '_' )
            if datasetID in ['tar_gcm','ar4_gcm']:
              if sh.has_key(key):
                ol = sh[key][:]
              else:
                raise 'invalid key'
            else:
              ol = ff[:]
          ooo = ol[flist.index(f)][:]
          if fv in ooo:
            ooo.pop( ooo.index( fv ) )
        else:
          o1.write( '??? %s, %s, %s\n' % (f, str(lset), str(unset) ) )
          action = '?'
          ooo = []
        o1.write( '%s, %s, %s\n' % (f in lset, f in unset, str( ooo ) ) )

        if datasetID == 'cru21' and f == 'Slice':
          oo.sort( utils.dlsort().cmp )
        else:
          oo.sort()

        nooo = 0
        thisov = 'dud'
        for ov in oo:
          if ov in ooo:
            thisov = ov
            nooo += 1
          elif ov in lsetvals:
            thisov = ov

        if nooo == 0:
          pmess += '%s,  %s, %s' % (f,thisov,str(oo))
          if thisov in lsetvals and f not in uopt:
            pmess += '<br/>uopt: %s;' % str(uopt)
        isdflt = nooo == 0
             
        
        for ov in oo:
          
          if ov in utils.cru_vdict.keys():
            ova = utils.cru_vdict[ov]
          elif ov in utils.tar_vdict.keys():
            ova = utils.tar_vdict[ov]
          else:
            ova = None

          if ova != None:
            if ov in ooo:
              navtab += '<label><input type="submit" name="%s%s" value="%s"/>%s</label><br/>\n' % (action,f,ov,ova)
            elif ov in lsetvals and not isdflt:
              navtab += '<label><input type="submit" style="color:#aa0000;" name="-%s" value="%s"/>%s</label><br/>\n' % (f,ov,ova)
            else:
              navtab += '<label><input type="submit" disabled="disabled" name="+%s" value="%s"/>%s</label><br/>\n' % (f,ov,ova)
          elif ov in utils.ar4_mdict.keys():
            fs = utils.fdict[f]
            lab = utils.ar4_mdict[ov]
            if ov in ooo:
              navtab += '<input type="submit" name="#%s%s%s" value="%s"/><br/>\n' % (action,fs,ov,lab)
            elif ov in lsetvals:
              if isdflt:
                navtab += '<input type="submit" style="color:#aa0000;" disabled="disabled" name="#-%s%s" value="%s"/><br/>\n' % (fs,ov,lab)
              else:
                navtab += '<input type="submit" style="color:#aa0000;" name="#-%s%s" value="%s"/><br/>\n' % (fs,ov,lab)
            elif f in uopt and ov == olist[flist.index(f)][0]:
              navtab += '<input type="submit" style="color:#aa0000;"  disabled="disabled" name="-%s" value="%s"/><br/>\n' % (f,ov)
            else:
              navtab += '<input type="submit" disabled="disabled" name="#+%s%s" value="%s"/><br/>\n' % (fs,ov,lab)
          else:
            if ov in ooo:
              navtab += '<input type="submit" name="%s%s" value="%s"/><br/>\n' % (action,f,ov)
            elif ov in lsetvals:
              if isdflt:
                navtab += '<input type="submit" style="color:#aa0000;" disabled="disabled" name="-%s" value="%s"/><br/>\n' % (f,ov)
              else:
                navtab += '<input type="submit" style="color:#aa0000;" name="-%s" value="%s"/><br/>\n' % (f,ov)
            elif f in uopt and ov == olist[flist.index(f)][0]:
              navtab += '<input type="submit" style="color:#aa0000;"  disabled="disabled" name="-%s" value="%s"/><br/>\n' % (f,ov)
            else:
              navtab += '<input type="submit" disabled="disabled" name="+%s" value="%s"/><br/>\n' % (f,ov)
        navtab += '</td>\n'

  if datasetID in ['tar_gcm', 'ar4_gcm']:
    if lm > 0:
      sh.close()

  navtab += '</tr></table></center>\n'
  
  for s in lset:
    if s in deflt:
      navtab += '<input type="hidden" name="z%s" value="%s"/>' % (s,lsetvals[lset.index(s)])
    else:
      navtab += '<input type="hidden" name="=%s" value="%s"/>' % (s,lsetvals[lset.index(s)])
  for f in uopt:
      ov = olist[flist.index(f)][0]
      navtab += '<input type="hidden" name="z%s" value="%s"/>' % (f,ov)

  navtab += '<input type="hidden" name="=%s" value="%s"/>' % ('display_mode',display_mode)

  ## navtab += '<br/> %s <br/>' % pmess
  ## navtab += '<br/> %s <br/>' % str(deflt)
  return navtab


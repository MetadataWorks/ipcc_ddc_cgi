# gcf_common.tcl - common routines for GCM Change Fields

set GcmScenarios {
  {CCCma_A2a  CCCma/A2a }
  {CCCma_B2a  CCCma/B2a }
  {CSIRO_A1a  CSIRO/A1a }
  {CSIRO_A2a  CSIRO/A2a }
  {CSIRO_B1a  CSIRO/B1a }
  {CSIRO_B2a  CSIRO/B2a }
  {ECHAM4_A2a ECHAM4/A2a}
  {ECHAM4_B2a ECHAM4/B2a}
  {GFDL99_A2a GFDL99/A2a}
  {GFDL99_B2a GFDL99/B2a}
  {HADCM3_A1F HadCM3/A1F}
  {HADCM3_A2a HadCM3/A2a}
  {HADCM3_A2b HadCM3/A2b}
  {HADCM3_A2c HadCM3/A2c}
  {HADCM3_B1a HadCM3/B1a}
  {HADCM3_B2a HadCM3/B2a}
  {HADCM3_B2b HadCM3/B2b}
  {NIES99_A1a NIES99/A1a}
  {NIES99_A1F NIES99/A1F}
  {NIES99_A1T NIES99/A1T}
  {NIES99_A2a NIES99/A2a}
  {NIES99_B1a NIES99/B1a}
  {NIES99_B2a NIES99/B2a}
}  
  
set Variables {  
  {TEMP "Mean Temperature (&#176;C)"} 
  {TMAX "Maximum Temperature (&#176;C)"} 
  {TMIN "Minimum Temperature (&#176;C)"} 
  {PREC "Precipitation (mm/day)"} 
  {RHUM "Vapour pressure (hPa)"}
  {TCLW "Cloud cover (%)"} 
  {WIND "Wind speed (m/s)"}
  {SMOI "Soil moisture"}
}

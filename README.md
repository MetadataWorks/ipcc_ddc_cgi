# ipcc_ddc_cgi
Some cgi scripts used in the IPCC DDC site

There are four entry points from the site: `downl`, `downl_form`, `ddc_nav`, and `query`.

## downl

The `downl` script is used to retrieve files from the archive. It has a primitive user registration procedure.

http://apps.ipcc-data.org/cgi-bin/downl/ar4_nc/pr/GFCM21_1PTO2X_pr_oc20x.tar

This script is linked to from tables such as the one on [IPCC 4th Assessment Report (2007): Model INM-CM3](http://www.ipcc-data.org/auto/ar4/model-INM-CM3.html)

## downl_form

The `downl_form` script is for files requested through a form .. the script parses the form data and compiles a call to `downl`.

Used by the [CRU_TS 2.1](http://www.ipcc-data.org/observ/clim/cru_ts2_1.html) page (as a HTML form action).

## ddc_nav

The `ddc_nav` script provides a non-heierarchical browse interface for data collections with multiple facets. Once a file is selected, there is also an option for data sub-setting and extracting as a CSV files.

http://apps.ipcc-data.org/cgi-bin/ddc_nav/dataset=ar4_gcm

Linked to from [Model output described in the 2007 IPCC Fourth Assessment Report (SRES scenarios), multi-year means](http://www.ipcc-data.org/sim/gcm_clim/SRES_AR4/index.html) (labelled as "DDC file navigator").

## query

The `query` script simply provides a form through which users can submit a query.

http://apps.ipcc-data.org/cgi-bin/query

Linked to from [Technical Guidelines, Fact Sheets and other Supporting Material](http://www.ipcc-data.org/guidelines/index.html) (we should probably retire this one).

## obsolete

Some obsolete scripts, retained for a while in case something has been overlooked

# ipcc_ddc_cgi
Some cgi scripts used in the IPCC DDC site

There are four entry points from the site: `downl`, `downl_form`, `ddc_nav`, and `query`.

## downl

The `downl` script is used to retrieve files from the archive. It has a primitive user registration procedure.

http://apps.ipcc-data.org/cgi-bin/downl/ar4_nc/pr/GFCM21_1PTO2X_pr_oc20x.tar

## downl_form

The `downl_form` script is for files requested through a form .. the script parses the form data and compiles a call to `downl`.

Used by the [CRU_TS 2.1](http://www.ipcc-data.org/observ/clim/cru_ts2_1.html) page (as a HTML form action).

## ddc_nav

The `ddc_nav` script provides a non-heierarchical browse interface for data collections with multiple facets. Once a file is selected, there is also an option for data sub-setting and extracting as a CSV files.

http://apps.ipcc-data.org/cgi-bin/ddc_nav/dataset=ar4_gcm

## query

The `query` script simply provides a form through which users can submit a query.

http://apps.ipcc-data.org/cgi-bin/query

## obsolete

Some obsolete scripts, retained for a while in case something has been overlooked.

# ipcc_ddc_cgi
Some cgi scripts used in the IPCC DDC site

There are four entry points from the site: `downl`, `downl_form`, `ddc_nav`, and `query`.

## downl

The `downl` script is used to retrieve files from the archive. It has a primitive user registration procedure.

## downl_form

The `downl_form` script is for files requested through a form .. the script parses the form data and compiles a call to `downl`.

## ddc_nav

The `ddc_nav` script provides a non-heierarchical browse interface for data collections with multiple facets. Once a file is selected, there is also an option for data sub-setting and extracting as a CSV files.

## query

The `query` script simply provides a form through which users can submit a query.

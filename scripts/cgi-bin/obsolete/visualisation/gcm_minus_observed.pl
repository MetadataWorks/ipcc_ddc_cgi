#!/usr/bin/perl
#
#
#
$|=1;
use CGI qw/:standard/;
use GD;
use Benchmark;
use Compress::Zlib;
use Sys::Hostname;
use gcm_subs;
# Set up some predefined values
my $host = hostname();
print STDERR "H: $host\n";

$data_path = "/badc/ipcc-ddc/data/legacy/visualisation_data";

my $docroot = "/var/www/ipccddc_site/html/";
my $cgi = "/cgi-bin/visualisation/single_observed_mean.pl";
my $cache_path = "/tmp/ddc_legacy_cache/visualisation_data/is92_gcm";
my $mask = "$data_path/masks/image6.gif";
my $measure_max = -9999;
my $measure_min = 9999;
my $mean_reading, $mean_count = 0;
my $cru_cols = 1;
#CHECK these out
my %var_factors = (
	"Mean temperature (°C)", 1,
	"Maximum temperature (°C)", 1,
	"Minimum temperature (°C)", 1,
	"Diurnal temperature (°C)", 1,
	"Precipitation (mm/day)", 1,
	"Vapour pressure (hPa)", 1,
	"Cloud cover (%)", 100,
	"Wind speed (m/s)", 1,
	"Global radiation (W/m2)", 1,
	"Wet days (days/month)", 1,
	"Frost days (days/month)", 1
);


# ° = AltGr-Shift-0
my %variables = (
	"Mean temperature (°C)", "tmp",
	"Maximum temperature (°C)", "tmx",
	"Minimum temperature (°C)", "tmn",
	"Diurnal temperature (°C)", "dtr",
	"Precipitation (mm/day)", "pre",
	"Vapour pressure (hPa)", "vap",
	"Cloud cover (%)", "cld",
	"Wind speed (m/s)", "wnd",
	"Global radiation (W/m2)", "rad",
	"Wet days (days/month)", "wet",
	"Frost days (days/month)", "frs"
);

my %resolutions = (
	"0.5", "25920 cells",
	"HadCM2", "grid 96*73, 3.75 x 2.75 degrees, centred 0.00E 90.0N",
	"GFDL-R15", "grid 48*40, 7.5 x 4.5 degrees, centred 0.00E 86.598N",
	"ECHAM4", "grid 128*64, 2.8125 x 2.8125 degrees, centred 0.00E 87.8638N",
	"CGCM1", "grid 96*48, 3.75 x 3.75 degrees, centred 0.00E 87.1591N",
);
my %dividers = (
	"Mean temperature (°C)", 10,
	"Maximum temperature (°C)", 10,
	"Minimum temperature (°C)", 10,
	"Diurnal temperature (°C)", 10,
	"Precipitation (mm/day)", 10,
	"Vapour pressure (hPa)", 10,
	"Cloud cover (%)", 1,
	"Wind speed (m/s)", 10,
	"Global radiation (W/m2)", 1,
	"Wet days (days/month)", 10,
	"Frost days (days/month)", 10
);



my %months = (
	"January"=>0, "February"=>1, "March"=>2, "April"=>3,
	"May"=>4, "June"=>5, "July"=>6, "August"=>7,
	"September"=>8, "October"=>9, "November"=>10, "December"=>11
	);
my %gcms = (
	"HadCM2", "HH",
	"ECHAM4", "EE",
	"GFDL-R15", "GG",
	"CGCM1", "CC",
	"CSIRO-Mk2", "AA",
);

my %forcing_types = (
	"GG", "Greenhouse Gas",
	"GS", "Greenhouse Gas and Aerosols",
);

my %mask_types = (
	"Land", "L",
	"Land plus ocean","LO"
);

#my %scenarios = (
#	"A", "1% per annum (IS92a)",
#	"D", "0.5% per annum, (IS92d)",
#);
my %scenarios = (
      	"IS92a", "A",
	"IS92d", "D"
);    
my %ensemble_members = (
	"Member 1", "1",	
	"Member 2", "2",	
	"Member 3", "3",	
	"Member 4", "4",	
	"Ensemble-mean", "X"	
);

my %timeslices = (
	"2020s","20", 
	"2050s","50", 
	"2080s","80"
);


my %bounds = (
	tmp		=> [ -90, -60, -30, 0, 30, 60, 90, 120, 150, 180 ,1],
	tmx		=> [ -90, -60, -30, 0, 30, 60, 90, 120, 150, 180 ,1],
	tmn		=> [ -90, -60, -30, 0, 30, 60, 90, 120, 150, 180 ,1],
	dtr 		=> [ -90, -60, -30, 0, 30, 60, 90, 120, 150, 180 ,1],
	diu		=> [ 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000 ],
	pre		=> [ -120, -100, -80, -60, -40, -20, 0, 20, 40, 60,-1 ], # need to invert colours
	vap		=> [ -120, -100, -80, -60, -40, -20, 0, 20, 40, 60,-1 ], # need to invert colours
	cld		=> [ -30, -24, -18, -12, -6, 0, 6, 12, 18, 24,-1 ], # need to invert colours
	wnd		=> [ -20, -10, -5, 0, 5, 10, 20, 30, 40, 50,1 ],
	rad		=> [ -60, -50, -40,  -30, -20, -10, 0, 10, 20, 30,1 ],
	wet		=> [ -100, -80, -60, -40, -20, 0, 20, 40, 60, 80,-1 ], # need to invert colours
	frs		=> [ -100, -80, -60, -40, -20, 0, 20, 40, 60, 80,-1 ], # need to invert colours
);

print STDERR "Beginning run at " . localtime(time) . "\n";

# set default values for ensemble_member and scenario
# Retrieve CGI input
my $query = new CGI;
#my $gcm = $query->param('gcm');
my $gcm = $query->param('resolution');
my $variable = $query->param('variable');
my $time_slice = $query->param('timeSlice');
my $forcing_type = $query->param('forcing_type');
my $start_month = $query->param('start_month');
my $end_month = $query->param('end_month');
my $map_type = $query->param('mapType');
my $scenario = $scenarios{$query->param('scenario')};
my $ensemble_member = $ensemble_members{$query->param('ensemble_member')};
my $return_format=$query->param('format');
my $return_compressed = $query->param('compressed');


#if ($gcm eq "HadCM2"){
#	$ensemble_member = $ensemble_members{$query->param('ensemble')};
#}else {
#	$ensemble_member = $ensemble_members{$query->param('ensemble_c')};
#}
($scenario ne "" ) || ($scenario = "A");
($ensemble_member ne "") || ($ensemble_member = 1);

$time_slice=$timeslices{$time_slice};
$time_slice1=$time_slice;
# to use script for 61-90 data only.   
$time_slice= 61;
$map_type = "Land";

print STDERR "variable=$variable\nstart_month = $start_month\nend_month=$end_month\ngcm=$gcm\nperiods=$periods\nreturn_format=$return_format\nreturn_compressed=$return_compressed\nensemble_member=$ensemble_member\ntime_slice=$time_slice\n";


if ($return_compressed eq "" )
{
	$return_compressed = "false";
}

if ( $return_format eq "" )
{
	$return_format = "graphics";
}

# Check months and calculate span
if ($months{$end_month} < $months{$start_month}) {
	$start_month = $end_month;
}
$num_of_months = ($months{$end_month} - $months{$start_month}) + 1;
if ($num_of_months < 1) { $num_of_months = 1; }


# Try to get the data from the cache, first work out what the cache file
# is called

if ( $return_format eq "text" )
{
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.dat.gz";
}
else
{
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.gif";
}

# now check to see if it exists

if ( -e $file )
{
	my $type = "";
	my $disposition = "attachment; ";
	if ( $return_compressed eq "true" && $return_format eq "text")
	{
		open (DATA, $file);
		$type = "application/x-gzip-compressed";
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.dat.gz\"";
	}
	elsif ($return_format eq "text")
	{
		open (DATA, "gzip -dc $file |");
		$type = "text/plain";
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.dat.gz\"";
	}
	else
	{
		open (DATA, $file);
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.gif\"";
		$type = "image/gif";
	}
		my @raw_data = <DATA>;
		
		my $data = join("",@raw_data);
		print $query->header(-type => $type,
									#-content_disposition => $disposition,
									-content_length => length($data));

		print $data;

	close(DATA);
}
else
{

	# Calculate resolution

	#$file = "$data_path/observed/${resolution}c$variables{$variable}$period.zip";
	#$file = &get_file_name();
	$file = &get_file_name($gcm,$gcms{$gcm},$forcing_type,$scenario,$ensemble_member,$time_slice,$variables{$variable});

	print STDERR "file: $file\n";
	if (!-e $file){
		print $query->header(),$query->start_html(-title=>'Data Not Found');
		print $query->h2('The data for the requested scenario is not available.');
		print $query->end_html;
		die "Data file not found\n";
	}
	@raw_data = &read_modelled_data() ;
	#print STDERR "$raw_data[70]\n";
	# Parse data from the file
	my @discrete_data;
	for ($month=0; $month<12; $month++) {
		splice(@raw_data, 0, 6);
		$adder=$month * $data_desc{n_cols} * $data_desc{n_rows};
			while (scalar @discrete_data < $data_desc{n_cols} * $data_desc{n_rows}+ $adder) {
				my @bits = split(/\s+/,shift(@raw_data));
				push(@discrete_data,splice(@bits,1));
			}
#print STDERR "month:$month\npoints:". scalar @discrete_data . "\n";
	}
print STDERR "points:". scalar @discrete_data . "\n";
# Shape parsed data
my @shaped_data;
my @line_data;
for ($row_count=0; $row_count<12*$data_desc{n_rows}; $row_count++) {
	for ($longitude=0; $longitude<$data_desc{n_cols}; $longitude++) {
		$shaped_data[$row_count].= pack("a5",shift @discrete_data);
	}
	#print STDERR "row:$row_count\t$shaped_data[$row_count]\n";

}
	#print STDERR "rows:$row_count\n";
	#print STDERR @discrete_data;
	# Read data into map array
	#my @map;
	#my @map2;

	my $num_of_numbers = 0;

	$t0 = new Benchmark;

	for ($i=$months{$start_month}; $i<=$months{$end_month}; $i++) {
		my $multiplier = $i * $data_desc{n_rows};
		#print STDERR "multiplier=$multiplier\n";
		for ($row = 0; $row < $data_desc{n_rows}; $row++) {
			chomp $shaped_data[$row + $multiplier];
			#print STDERR "row:$row $shaped_data[$row + $multiplier]";
			@chunks = unpack("a5"x$data_desc{n_cols},$shaped_data[$row + $multiplier]);
			#print STDERR "Chunks: @chunks\n";
			for ($col=0; $col < $data_desc{n_cols}; $col++) {
				if ( $chunks[$col] != 9999 ) {
					$map[$row][$col] += $chunks[$col];
				}
				elsif ( $map[$row][$col] != -9999 ) {
					$map[$row][$col] = -9999;
				}
				#print STDERR "$map[$row][$col]\t";
				if ($chunks[$col] != -9999) {
					$mean_reading += $chunks[$col];
					$num_of_numbers ++;
					if ($chunks[$col] > $measure_max) { 
						$measure_max = $chunks[$col]; 
					}
					if ($chunks[$col] < $measure_min) { 
						$measure_min = $chunks[$col]; 
					}
				}
			}
		}
	}
	for ( $row = 0; $row < $data_desc{n_rows}; $row++) {
		for ($col = 0; $col < $data_desc{n_cols}; $col++) {
			if ( $map[$row][$col] != -9999 ) {
				#$map[$row][$col] = int($dividers{$variable}*$var_factors{$variable}*$map[$row][$col] / $num_of_months + 0.5)/$var_factors{$variable};
				$map[$row][$col] = int($dividers{$variable}*$var_factors{$variable}*$map[$row][$col] / $num_of_months + 0.5);

				#print STDERR "map $row,$col\t$map[$row][$col]\n";
			}
		}
	}
	# Remove row 0 and row 72 for Hadley data
	if ( $gcm eq "HadCM2" ) {
		splice (@map, $data_desc{n_rows} -1,1);
		splice (@map, 0, 1);
		$data_desc{n_rows} -= 2;
		print STDERR "$gcm, Removing first and last rows\n";
	}

	$mean_reading = $mean_reading / $num_of_numbers;
	$t1 = new Benchmark;
	$td = timediff($t1, $t0);
	print STDERR "time in read loop: ", timestr($td), "\n";

	# Free up some memory
	@raw_data = "";

	# Work out scale etc
	$difference = $measure_max - $measure_min;
	$increment = $difference / 10;
	my $factor = $mean_reading / 10;
	print STDERR "max: $measure_max min: $measure_min inc: $increment mean: $mean_reading factor: $factor\n";
# END OF FIRST READ

# START OF OBSERVED DATA
# Retrieve CGI input
# to use script for 61-90 data only.   
$time_slice= 61;

print STDERR "variable=$variable\nstart_month = $start_month\nend_month=$end_month\ngcm=$gcm\nperiods=$periods\nreturn_format=$return_format\nreturn_compressed=$return_compressed\n";



	# Calculate resolution

	#$file = "$data_path/observed/${resolution}c$variables{$variable}$period.zip";
	$file = &get_obs_file_name();
	print STDERR "file: $file\n";
	@raw_data = &read_obs_data() ;
	#print STDERR "$raw_data[70]\n";
	# Read data into map array
	my $num_of_numbers = 0;

	$t0 = new Benchmark;

	for ($i=$months{$start_month}; $i<=$months{$end_month}; $i++) {
		my $multiplier = $i * $data_desc{n_rows};
		#print STDERR "multiplier=$multiplier\n";
		for ($row = 0; $row < $data_desc{n_rows}; $row++) {
			chomp $raw_data[$row + $multiplier];
			#print STDERR "row:$row $raw_data[$row + $multiplier]";
			@chunks = unpack("a5"x$data_desc{n_cols},$raw_data[$row + $multiplier]);
			
			for ($col=0; $col < $data_desc{n_cols}; $col++) {
				if ( $chunks[$col] != -9999 ) {
					$map2[$row][$col] += $chunks[$col];
				}
				elsif ( $map2[$row][$col] != -9999 ) {
					$map2[$row][$col] = -9999;
				}
				
				if ($chunks[$col] != -9999) {
					$mean_reading += $chunks[$col];
					$num_of_numbers ++;
					if ($chunks[$col] > $measure_max) { 
						$measure_max = $chunks[$col]; 
					}
					if ($chunks[$col] < $measure_min) { 
						$measure_min = $chunks[$col]; 
					}
				}
			}
		}
	}

	for ( $row = 0; $row < $data_desc{n_rows}; $row++) {
		for ($col = 0; $col < $data_desc{n_cols}; $col++) {
			if ( $map2[$row][$col] != -9999 ) {
				$map2[$row][$col] = int($map2[$row][$col] / $num_of_months);
			}
		}
	}

	$mean_reading = $mean_reading / $num_of_numbers;
	$t1 = new Benchmark;
	$td = timediff($t1, $t0);
	print STDERR "time in read loop: ", timestr($td), "\n";

	# Free up some memory
	@raw_data = "";

	# calculate difference
	for ( $row = 0; $row < $data_desc{n_rows}; $row++) {
		for ($col = 0; $col < $data_desc{n_cols}; $col++) {
			#print STDERR "$map[$row][$col] $map2[$row][$col] ";
			if ( ($map[$row][$col] != -9999) && ($map2[$row][$col] != -9999) ) {
				$map[$row][$col] = $map[$row][$col] - $map2[$row][$col];
			} 
			else {
				$map[$row][$col] = -9999;
			}
			#print STDERR "$map[$row][$col]\n";

		}
	}
	# $map [][] now contains summed data

	# Work out scale etc
	$difference = $measure_max - $measure_min;
	$increment = $difference / 10;
	my $factor = $mean_reading / 10;
	print STDERR "max: $measure_max min: $measure_min inc: $increment mean: $mean_reading factor: $factor\n";

	# Graphics stuff
	if ( $return_format ne "text" )
	{
		my $caption = "1961-90 $start_month to $end_month $gcm $forcing_type$scenario$ensemble_member modelled $variable minus observed values ";
		my $image_file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.gif";
		my $pointer = \%bounds;
		my $variable_bounds = $$pointer{$variables{$variable}};
		&draw_picture(\@map, $variable_bounds, $data_desc{n_rows},$data_desc{n_cols},$map_type,$cru_cols,$measure_min,$measure_max,$dividers{$variable},$docroot,$image_file,$caption);
	}
	else
	{
		my $document = "";

		for ($row = 0; $row < $data_desc{n_rows}; $row++)
		{
			for ($col = 0; $col < $data_desc{n_cols}; $col++)
			{
				if ( $col < $data_desc{n_cols} && $map[$row][$col] < -9999 )
				{
					$document .= -9999;
				}
				else
				{
					$document .= $map[$row][$col];
				}
				if ( $col < $data_desc{n_cols} - 1 )
				{
					$document .= ",";
				}
			#print  STDERR "$map[$row][$row]\t";
			# all garbage here
			}
			$document .= "\n";

		}
		# Cache the data
		
		$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}gmo.dat.gz";
		if (!-e "$file")
		{
			open (CACHE_DATA, "| gzip -c > $file");
				print CACHE_DATA $document;
			close (CACHE_DATA);
		}
		
		open (DATA,"gzip -dc $file |");
			@document = <DATA>;
			$document = join("",@document);
		close $file;
		
		print $query->header(-type => "text/plain",
									-Content_length => length($document));

		print $document;
		
	}
}

sub GetColour {

	my $v = shift (@_);
	my $vmin = shift (@_);
	my $vmax = shift (@_);
	
	#print "val: $v min: $vmin max: $vmax\n";

	my $red = $green = $blue = 1;
	my $dv;

	if ($v < $vmin) { $v = $vmin; }
	if ($v > $vmax) { $v = $vmax; }
	$dv = $vmax - $vmin;

	if ($v < ($vmin + 0.25 * $dv)) {
		$red = 0;
		$green = 4 * ($v - $vmin) / $dv;
	}
	elsif ($v < ($vmin + 0.5 * $dv)) {
		$red = 0;
		$blue = 1 + 4 * ($vmin + 0.25 * $dv - $v) / $dv;
	}
	elsif ($v < ($vmin + 0.75 * $dv)) {
		$red = 4 * ($v - $vmin - 0.5 * $dv) / $dv;
		$blue = 0;
	}
	else {
		$green = 1 + 4 * ($vmin + 0.75 * $dv - $v) / $dv;
		$blue = 0;
	}

	my $const = 0.65;
	$red = sprintf("%u",$red * 255 * $const);
	$green = sprintf("%u",$green * 255 * $const);
	$blue = sprintf("%u",$blue * 255 * $const);

	#print STDERR "r: $red g: $green b: $blue\n";
	return($red,$green,$blue);
}

#sub get_file_name(){
#print STDERR "ensemble_member = $ensemble_member\n";
#return( "$data_path/gcm/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member" . "$time_slice." . uc($variables{$variable}));

#}

sub read_modelled_data() {
 	print STDERR ("sub read_data file: $file\n");

	open(DATA, "<$file") || print STDERR "Unable to open DATA \"$file\": $!\n";
	@raw_data = <DATA>;
	close(DATA);


	# Find out about data

# Get Resolution from file
	my @res_line = split (/[\s\t]+/,$raw_data[1]);
	$data_desc{n_cols} = $res_line[2];
	$data_desc{n_rows} = $res_line[4];
	#die ("	$data_desc{n_cols} x $data_desc{n_rows}");
   # print STDERR "$resolution\n@raw_data";
   return @raw_data;
}

sub get_obs_file_name(){
# print STDERR "sub get_file_name period = $period\n";
	if ($gcm eq "HadCM2"){
		return("$data_path/observed/had$variables{$variable}.gz");
	}
	elsif ($gcm eq "GFDL-R15"){
		return("$data_path/observed/gfdl$variables{$variable}.gz");
	}
	elsif ($gcm eq "ECHAM4"){
		print STDERR "Echam file name\n";
		return("$data_path/observed/echam$variables{$variable}.gz");

	}
	elsif ($gcm eq "CGCM1"){
		return("$data_path/observed/ccm$variables{$variable}.gz");
	}

	else {
		return("$data_path/observed/c$variables{$variable}$period.zip");
	}

}

sub read_obs_data() {
#print STDERR " read_obs_data() sub\n";
    if ($gcm eq "HadCM2"){
	# open read and process binary data
	$data_desc{n_rows} = 71;
	$data_desc{n_cols} = 96;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	print STDERR "HadCM2 Reading data file\n";
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	 print STDERR "Bytes read=$bytes_read";

	close (DATA);
	@raw_data = &process_binary ($raw_binary);
    }
    elsif ($gcm eq "GFDL-R15"){
	# open read and process binary data
	$data_desc{n_rows} = 40;
	$data_desc{n_cols} = 48;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	# print STDERR $bytes_read;

	close (DATA);
	@raw_data = &process_binary ($raw_binary);
    }
    elsif ($gcm eq "ECHAM4"){
	# open read and process binary data
	$data_desc{n_rows} = 64;
	$data_desc{n_cols} = 128;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	# print STDERR $bytes_read;
	print STDERR "echam processing\n";
	close (DATA);
	@raw_data = &process_binary ($raw_binary);
    }
    elsif ($gcm eq "CGCM1"){
	# open read and process binary data
	$data_desc{n_rows} = 48;
	$data_desc{n_cols} = 96;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	# print STDERR $bytes_read;

	close (DATA);
	@raw_data = &process_binary ($raw_binary);
    }

    else {
	open(DATA, "unzip -p $file |") || print STDERR "Unable to open DATA \"$file\": $!\n";
	@raw_data = <DATA>;
	close(DATA);


	# Find out about data
	my $line1 = shift @raw_data;
	my $line2 = shift @raw_data;
	chomp ($line1,$line2);
	$line1 =~ s/^\s+//g;
	$line2 =~ s/^\s+//g;
	my (@fieldnames) = split(/\s+/,$line1);
	my (@fieldvalues) = split(/\s+/,$line2);
	foreach $name (@fieldnames) {
		$data_desc{$name} = shift @fieldvalues;
	}
    } # end of else
   # print STDERR "$gcm\n@raw_data";
    return @raw_data;
}

sub process_binary
{
    my ($data1) = @_;
#print STDERR "sub process_binary\n";
#print STDERR "rows: $data_desc{n_rows}\tcolumns: $data_desc{n_cols}\n";

    for ( my $i=0; $i<=11; $i++)
    {
	#print STDERR "month: $i\n";
	for (my $rowcount = 0; $rowcount < $data_desc{n_rows}; $rowcount++){
	    my $adder = $i * $data_desc{n_rows};
		my @data_row;
		for (my $colcount = 0; $colcount < $data_desc{n_cols}; $colcount++){;
			# Maybe use "unpack" instead of the following
        		my ($part1, $part2) = $data1 =~ /^(.)(.).*/s;
			$data1 =~ s/^..//s;
        		$part1 = ord($part1);
        		$part2 = ord($part2);
			#print STDERR "part1 = $part1\tpart2=$part2\t rowcount = $rowcount\tcolcount = $colcount\n";
			my $thisdata = ($part2 << 8);
			$thisdata += $part1;
					
			if ($thisdata >= 0x8000) {
				$thisdata -= (0x8000 * 2);
			}
			push ( @data_row, $thisdata);
			
		}
		$raw_string = pack ("a5"x$data_desc{n_cols},@data_row);
		@raw_data[$rowcount+ $adder] = $raw_string;
		# print STDERR "$i $rowcount  $raw_string\n";
	}			
	
     }
return (@raw_data);
}
__END__


		

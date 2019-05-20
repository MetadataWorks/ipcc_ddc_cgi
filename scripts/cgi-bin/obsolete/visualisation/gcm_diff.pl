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
	"Diurnal temperature range (°C)", 1,
	"Precipitation (mm/day)", 1,
	"Vapour pressure (hPa)", 1,
	"Cloud cover (%)", 100,
	"Wind speed (m/s)", 1,
	"Global radiation (W/m2)", 1,
	"Global radiation (W/m²)", 1,
	"Wet days (days/month)", 1,
	"Frost days (days/month)", 1
);



# ° = AltGr-Shift-0
my %variables = (
	"Mean temperature (°C)", "tmp",
	"Maximum temperature (°C)", "tmx",
	"Minimum temperature (°C)", "tmn",
	"Diurnal temperature range (°C)", "dtr",
	"Precipitation (mm/day)", "pre",
	"Vapour pressure (hPa)", "vap",
	"Cloud cover (%)", "cld",
	"Wind speed (m/s)", "wnd",
	"Global radiation (W/m2)", "rad",
	"Global radiation (W/m²)", "rad",
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
	"Diurnal temperature range (°C)", 10,
	"Precipitation (mm/day)", 10,
	"Vapour pressure (hPa)", 10,
	"Cloud cover (%)", 10,
	"Wind speed (m/s)", 10,
	"Global radiation (W/m2)", 10,
	"Global radiation (W/m²)",10,
	"Wet days (days/month)", 10,
	"Frost days (days/month)", 10
);

my %months = (
	"January"=>0, "February"=>1, "March"=>2, "April"=>3,
	"May"=>4, "June"=>5, "July"=>6, "August"=>7,
	"September"=>8, "October"=>9, "November"=>10, "December"=>11
	);

# gcms changed for difference calculation (using Had grid)
my %gcms = (
	"HadCM2", "HH",
	"ECHAM4", "EH",
	"GFDL-R15", "GH",
	"CGCM1", "CH",
	"CSIRO-Mk2", "AH",
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
	"IS92d", "D",
      	"A", "A",
	"D", "D"
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
	tmp		=> [ -20, -10, -5, 0, 5, 10, 20, 30, 40, 50,1],
	tmx		=> [ -20, -10, -5, 0, 5, 10, 20, 30, 40, 50,1],
	tmn		=> [ -20, -10, -5, 0, 5, 10, 20, 30, 40, 50,1],
	dtr 		=> [ -2, -1, -0.5, 0, 0.5, 1, 2, 3, 4 ,5, 1],
	diu		=> [ 20, 40, 60, 80, 100, 120, 140, 160, 180, 200 , 1],
	pre		=> [  -60, -50,-40, -30,-20,-10,0,10, 20, 30, -1], # need to invert colours
	vap		=> [ -12,-10,-8,-6,-4,-2,0,2, 4, 6,-1], # need to invert colours
	cld		=> [ -120, -100, -80, -60, -40, -20, 0, 20, 40, 60 , -1], # need to invert colours
	wnd		=> [ -30, -25, -20, -15, -10, -5, 0,5, 10, 15,  1 ],
	rad		=> [ -150, -100, -50, -0, 50, 100, 150, 200, 250, 300,1],
	wet		=> [ 10, 20, 30, 40, 50, 100, 150, 200, 250, 300 , -1], # need to invert colours
	frs		=> [ 10, 20, 30, 40, 50, 100, 150, 200, 250, 300 , -1] # need to invert colours
);

print STDERR "Beginning run at " . localtime(time) . "\n";

# set default values for ensemble_member and scenario
# Retrieve CGI input
my $query = new CGI;
my $gcm = $query->param('gcm');
my $variable = $query->param('variable');
my $time_slice = $query->param('timeSlice');
my $forcing_type = $query->param('forcing_type');
my $start_month = $query->param('start_month');
my $end_month = $query->param('end_month');
my $map_type = $query->param('mapType');
my $scenario = $scenarios{$query->param('scenario')};
my $ensemble_member = $query->param('ensemble_member');
my $return_format=$query->param('format');
my $return_compressed = $query->param('compressed');

my $gcm2 = $query->param('gcm2');
my $time_slice2 = $query->param('timeSlice2');
my $forcing_type2 = $query->param('forcing_type2');
my $start_month2 = $query->param('start_month2');
my $end_month2 = $query->param('end_month2');
my $scenario2 = $scenarios{$query->param('scenario2')};
my $ensemble_member2 = $query->param('ensemble_member2');


#if ($gcm eq "HadCM2"){
#	$ensemble_member = $ensemble_members{$query->param('ensemble')};
#}else {
#	$ensemble_member = $ensemble_members{$query->param('ensemble_c')};
#}
($scenario ne "" ) || ($scenario = "A");
($ensemble_member ne "") || ($ensemble_member = 1);

#if ($gcm2 eq "HadCM2"){
#	$ensemble_member = $ensemble_members{$query->param('ensemble2')};
#}else {
#	$ensemble_member = $ensemble_members{$query->param('ensemble_c2')};
#}
($scenario2 ne "" ) || ($scenario2 = "A");
($ensemble_member2 ne "") || ($ensemble_member2 = 1);

$time_slice=$timeslices{$time_slice};
$time_slice2=$timeslices{$time_slice2};

# Store values for use in header or data description
my $time_slice1   = $time_slice;
my $gcm1          = $gcm;
my $forcing_type1 = $forcing_type;
my $start_month1  = $start_month;
my $end_month1    = $end_month;
my $scenario1     = $scenario;
my $ensemble_member1 = $ensemble_member;

print STDERR "variable=$variable\nstart_month = $start_month\nend_month=$end_month\ngcm=$gcm\nperiods=$periods\nreturn_format=$return_format\nreturn_compressed=$return_compressed\nensemble_member=$ensemble_member\ntime_slice=$time_slice\n";
print STDERR "TEST $query->param('ensemble_member')\t$ensemble_members{$query->param('ensemble')}\n";


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
	$file = "$cache_path/" . lc($gcm1) . "/$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.dat.gz";
}
else
{
	$file = "$cache_path/" . lc($gcm1) . "/$gcms{$gcm1}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}$mask_types{$map_type}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.gif";
}

# now check to see if it exists
print STDERR "cache file: $file\n";
if ( -e $file )
{
	my $type = "";
	my $disposition = "attachment; ";
	if ( $return_compressed eq "true" && $return_format eq "text")
	{
		open (DATA, $file);
		$type = "application/x-gzip-compressed";
		$disposition .= "filename=\"$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.dat.gz\"";
	}
	elsif ($return_format eq "text")
	{
		open (DATA, "gzip -dc $file |");
		$type = "text/plain";
		$disposition .= "filename=\"$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.dat.gz\"";
	}
	else
	{
		open (DATA, $file);
		$disposition .= "filename=\"$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}$mask_types{$map_type}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.gif\"";
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
	$file = &get_file_name($gcm,$gcms{$gcm},$forcing_type,$scenario,$ensemble_member,$time_slice,$variables{$variable});
	print STDERR "file: $file\n";
	if (!-e $file){
		print $query->header(),$query->start_html(-title=>'Data Not Found');
		print $query->h2('The data for the requested scenario is not available.');
		print $query->end_html;
		die "Data file not found\n";
	}
	@raw_data = &read_data() ;
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
	print STDERR "rows:$row_count\n";
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
				$map[$row][$col] = int($var_factors{$variable}*$dividers{$variable}*$map[$row][$col] / $num_of_months + 0.5);

				#$map[$row][$col] = int($var_factors{$variable}*$map[$row][$col] / $num_of_months + 0.5)/$var_factors{$variable};
				#print STDERR "map $row,$col\t$map[$row][$col]\n";
			}
		}
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
# Set live values to the second data parameters
$time_slice   = $time_slice2;
$gcm          = $gcm2;
$forcing_type = $forcing_type2;
$start_month  = $start_month2;
$end_month    = $end_month2;
$scenario     = $scenario2;
$ensemble_member = $ensemble_member2;

print STDERR "variable=$variable\nstart_month = $start_month\nend_month=$end_month\nresolution=$resolution\nperiods=$periods\nreturn_format=$return_format\nreturn_compressed=$return_compressed\n";



	# Calculate resolution

	$file = &get_file_name($gcm,$gcms{$gcm},$forcing_type,$scenario,$ensemble_member,$time_slice,$variables{$variable});
	print STDERR "file: $file\n";
	@raw_data = &read_data() ;
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
	print STDERR "rows:$row_count\n";
	#print STDERR @discrete_data;
	# Read data into map array
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
					$map2[$row][$col] += $chunks[$col];
				}
				elsif ( $map2[$row][$col] != -9999 ) {
					$map2[$row][$col] = -9999;
				}
				#print STDERR "$map2[$row][$col]\t";
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
				$map2[$row][$col] = int($var_factors{$variable}*$dividers{$variable}*$map2[$row][$col] / $num_of_months + 0.5);
				#$map2[$row][$col] = int($var_factors{$variable}*$map2[$row][$col] / $num_of_months + 0.5)/$var_factors{$variable};
			#print STDERR "Ha $map[$row][$col] $map2[$row][$col] \n";

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
	# $map [][] now contains difference data

	# Work out scale etc
	$difference = $measure_max - $measure_min;
	$increment = $difference / 10;
	my $factor = $mean_reading / 10;
	print STDERR "max: $measure_max min: $measure_min inc: $increment mean: $mean_reading factor: $factor\n";

	# Graphics stuff
	if ( $return_format ne "text" )
	{
		my $caption = "20${time_slice2}s $start_month2 to $end_month2 $gcm2 $forcing_type2$scenario2$ensemble_member2 minus 20${time_slice1}s $start_month1 to $end_month1 $gcm1 $forcing_type1$scenario1$ensemble_member1";
		my $image_file = "$cache_path/" . lc($gcm1) . "/$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}$mask_types{$map_type}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.gif";
		my $pointer = \%bounds;
		my $variable_bounds = $$pointer{$variables{$variable}};
		#print STDERR "variable_bounds[3] $variable_bounds->[3]\n ";
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
		
		$file = "$cache_path/" . lc($gcm1) . "/$gcms{$gcm1}$forcing_type1" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month1}$months{$end_month1}diff$gcms{$gcm2}$forcing_type2" . uc($scenario2) . "$ensemble_member2$time_slice2" ."$months{$start_month2}$months{$end_month2}.dat.gz";
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
	
	#print STDERR "val: $v min: $vmin max: $vmax\n";

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

sub read_data() {
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


__END__


		

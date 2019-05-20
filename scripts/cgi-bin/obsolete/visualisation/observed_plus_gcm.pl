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
	tmp		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300 , 1],
	tmx		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300, 1 ],
	tmn		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300, 1 ],
	dtr 		=> [ 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 1 ],
	diu		=> [ 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 1 ],
	pre		=> [ -80, -70, -60, -50, -40, -30, -20, -10, -5, -1, -1 ], # need to invert colours
	vap		=> [ -300, -270, -240, -210, -180, -150, -120, -90, -60, -30, -1],  
	cld		=> [ -95, -85, -75, -65, -55, -45, -35, -25, -15, -5, -1 ], # need to invert colours
	wnd		=> [ 1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 1 ],
	rad		=> [ 20, 50, 80, 110, 140, 170, 200, 230, 260, 290, 1 ],
	wet		=> [ -300, -250, -200, -150, -100, -50, -40, -30, -20, -10, -1 ], # need to invert colours
	frs		=> [ -300, -250, -200, -150, -100, -50, -40, -30, -20, -10, -1 ], # need to invert colours
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


#if ($gcm eq "HadCM2"){
#	$ensemble_member = $ensemble_members{$query->param('ensemble')};
#}else {
#	$ensemble_member = $ensemble_members{$query->param('ensemble_c')};
#}
($scenario ne "" ) || ($scenario = "A");
($ensemble_member ne "") || ($ensemble_member = 1);

$time_slice=$timeslices{$time_slice};
$time_slice1=$time_slice;
my $scenario1 = $scenario;
my $ensemble_member1 = $ensemble_member;

# to use script for 61-90 data only.   
#$time_slice= 61;

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
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}plus.dat.gz";
}
else
{
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}$mask_types{$map_type}plus.gif";
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
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}plus.dat.gz\"";
	}
	elsif ($return_format eq "text")
	{
		open (DATA, "gzip -dc $file |");
		$type = "text/plain";
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}plus.dat.gz\"";
	}
	else
	{
		open (DATA, $file);
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}$mask_types{$map_type}plus.gif\"";
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
	$file = &get_file_name();
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
				#$map[$row][$col] = int($dividers{$variable}*$var_factors{$variable}*$map[$row][$col] / $num_of_months + 0.5)/$var_factors{$variable};
				#print STDERR "map $row,$col\t$map[$row][$col]\n";
			}
		}
	}
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
				$map2[$row][$col] = int($map2[$row][$col] / $num_of_months +0.5);
			}
		}
	}

	$mean_reading = $mean_reading / $num_of_numbers;
	$t1 = new Benchmark;
	$td = timediff($t1, $t0);
	print STDERR "time in read loop: ", timestr($td), "\n";

	# Free up some memory
	@raw_data = "";

	# calculate sum
	for ( $row = 0; $row < $data_desc{n_rows}; $row++) {
		for ($col = 0; $col < $data_desc{n_cols}; $col++) {
			#print STDERR "$map[$row][$col] $map2[$row][$col] ";
			if ( ($map[$row][$col] != -9999) && ($map2[$row][$col] != -9999) ) {
				$map[$row][$col] += $map2[$row][$col];
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
		print "Content-type: image/gif\n\n";

		my $image;
		#if (open (MASK, "$mask") ) {
		if (0) {
			$image = newFromGif GD::Image(MASK) || print STDERR "Unable to create new image: $!\n";
			close MASK;
		} else {
			#print STDERR "Unable to open MASK \"$mask\": $!\n";
			$image = new GD::Image(640,370);
		}
		$white = $image->colorAllocate(255,255,255);
		$black = $image->colorAllocate(0,0,0);
		$grey = $image->colorAllocate(200,200,200);
		$green = $image->colorAllocate(0,255,0);
		#$foo = $image->colorAllocate(128,128,128);
		# The following reflect climate data

		if ($cru_cols) {
			$col10 = $image->colorAllocate(168,16,28); # red (A8101C)
			$col9 = $image->colorAllocate(176,60,40); # flesh (B03C28)
			$col8 = $image->colorAllocate(200,120,32); # mud (C87820)
			$col7 = $image->colorAllocate(248,236,20); # yellow (F8EC14)
			$col6 = $image->colorAllocate(152,192,0); # light green (98C000)
			$col5 = $image->colorAllocate(88,160,72); # mid green (58A048)
			$col4 = $image->colorAllocate(4,100,12); # dark green (04640c)
			$col3 = $image->colorAllocate(96,160,228); # light blue (60A0e4)
			$col2 = $image->colorAllocate(0,16,104); # dark blue (001068)
			$col1 = $image->colorAllocate(56,28,84); # purple (381c54)
			$col0 = $image->colorAllocate(112,32,52); # pink (702034)
			$col11 = $image->colorAllocate(160,8,80); # cerise (a00850)
		}

		# Put data into grid for printing
		my $scale = (640/$data_desc{n_cols});
		my $y_scale = (320/$data_desc{n_rows});
		my $offset_x = 360;
		my $offset_y = 0;

		# Print grid
		#for ($x=0; $x<$data_desc{n_cols}*$scale; $x=($x+60*$scale)) {
		#	for ($y=0; $y<$data_desc{n_rows}*$scale; $y=($y+60*$scale)) {
		#		$image->rectangle($x,$y,$x+60*$scale,$y+60*$scale,$grey);
		#	}
		#}

		$t2 = new Benchmark;
		# inverter taken from bounds array = -1 if colours are to be inverted
		$inverter= $bounds{$variables{$variable}}[10];
		print STDERR "inverter = $inverter\n";
		for ($row = 0; $row < $data_desc{n_rows}; $row++) {
			if ($row+$offset_y >= 0) {
				$offset_y = 0;
			}
			$offset_x = $data_desc{n_cols}/2;
			for ($col=0; $col < $data_desc{n_cols}; $col++) {
				if (($col >= $data_desc{n_cols}/2) && ($col+$offset_x) >= ($data_desc{n_cols})) { $offset_x = -$data_desc{n_cols}/2;}
				#$value = $map[$row][$col] / ($num_of_months);
				# $map has already been averaged over months hasn't it?
				$value = $map[$row][$col];
				#print "map: $map[$row][$col] div: $value\n";
				if ($value== "-9999") {
					# Do nothing
				}
				else {
					($r,$g,$b) = GetColour($value,$measure_min,$measure_max);
					$colour = $image->colorExact($r,$g,$b);
					if ($colour == -1) {
						$colour = $image->colorAllocate($r,$g,$b);
					}
					#print STDERR "r: $r g: $g b: $b\n";
					if (!$cru_cols) {
						$image->setPixel(($col+$offset_x)*$scale,($row+$offset_y)*$scale,$colour);
					}
					else {
						SWITCH: {
							# Out of bounds (too low)?
							if ($value * $inverter <= $bounds{$variables{$variable}}[0]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col0);
	#print STDERR "\nvalue: $value, bounds:  $bounds{$variables{$variable}}[0]\n";
	#die;
							last SWITCH; }
							# Normal
							if ($value * $inverter > $bounds{$variables{$variable}}[0] && $value * $inverter <= $bounds{$variables{$variable}}[1]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col1); last SWITCH; }
							if ($value* $inverter  > $bounds{$variables{$variable}}[1] && $value * $inverter  <= $bounds{$variables{$variable}}[2]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col2); last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[2] && $value* $inverter  <= $bounds{$variables{$variable}}[3]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col3); last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[3] && $value * $inverter <= $bounds{$variables{$variable}}[4]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col4);
	#print STDERR "\nvalue: $value, bounds:  $bounds{$variables{$variable}}[3]\n";
	#die;
 last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[4] && $value * $inverter <= $bounds{$variables{$variable}}[5]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col5); last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[5] && $value * $inverter <= $bounds{$variables{$variable}}[6]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col6); last SWITCH; }
							if ($value* $inverter  > $bounds{$variables{$variable}}[6] && $value * $inverter <= $bounds{$variables{$variable}}[7]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col7); last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[7] && $value * $inverter <= $bounds{$variables{$variable}}[8]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col8); last SWITCH; }
							if ($value * $inverter > $bounds{$variables{$variable}}[8] && $value * $inverter <= $bounds{$variables{$variable}}[9]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col9); last SWITCH; }
							# Out of bounds (too high)?
							if ($value * $inverter >= $bounds{$variables{$variable}}[9]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col10); last SWITCH; }
							# Pathological case!
							$image->$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$black); $foo = 1;
						}
					}
				}
			}
		}
		$t3 = new Benchmark;
		$td = timediff($t3, $t2);
		print STDERR "time in pixel loop: ", timestr($td), "\n";
		$image->string(gdSmallFont, 500, 325, "Plotted by the IPCC-DDC", $black);
		if ($inverter == -1){
			$image->filledRectangle( 128, 322,158,350, $col10);
			$image->filledRectangle( 448, 322,478,350, $col0);
			$image->filledRectangle( 160, 322,190,350, $col9);
			$image->filledRectangle( 192, 322,222,350, $col8);
			$image->filledRectangle( 224, 322,254,350, $col7);
			$image->filledRectangle( 256, 322,286,350, $col6);
			$image->filledRectangle( 288, 322,318,350, $col5);
			$image->filledRectangle( 320, 322,350,350, $col4);
			$image->filledRectangle( 352, 322,382,350, $col3);
			$image->filledRectangle( 384, 322,414,350, $col2);
			$image->filledRectangle( 416, 322,446,350, $col1);
			$image->string(gdSmallFont, 155, 352, -$bounds{$variables{$variable}}[9]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 187, 352, -$bounds{$variables{$variable}}[8]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 219, 352, -$bounds{$variables{$variable}}[7]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 251, 352, -$bounds{$variables{$variable}}[6]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 283, 352, -$bounds{$variables{$variable}}[5]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 315, 352, -$bounds{$variables{$variable}}[4]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 347, 352, -$bounds{$variables{$variable}}[3]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 379, 352, -$bounds{$variables{$variable}}[2]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 411, 352, -$bounds{$variables{$variable}}[1]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 443, 352, -$bounds{$variables{$variable}}[0]/$dividers{$variable}, $black);
		}else{
			$image->filledRectangle( 128, 322,158,350, $col0);
			$image->filledRectangle( 448, 322,478,350, $col10);
			$image->filledRectangle( 160, 322,190,350, $col1);
			$image->filledRectangle( 192, 322,222,350, $col2);
			$image->filledRectangle( 224, 322,254,350, $col3);
			$image->filledRectangle( 256, 322,286,350, $col4);
			$image->filledRectangle( 288, 322,318,350, $col5);
			$image->filledRectangle( 320, 322,350,350, $col6);
			$image->filledRectangle( 352, 322,382,350, $col7);
			$image->filledRectangle( 384, 322,414,350, $col8);
			$image->filledRectangle( 416, 322,446,350, $col9);
			$image->string(gdSmallFont, 155, 352, $bounds{$variables{$variable}}[0]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 187, 352, $bounds{$variables{$variable}}[1]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 219, 352, $bounds{$variables{$variable}}[2]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 251, 352, $bounds{$variables{$variable}}[3]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 283, 352, $bounds{$variables{$variable}}[4]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 315, 352, $bounds{$variables{$variable}}[5]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 347, 352, $bounds{$variables{$variable}}[6]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 379, 352, $bounds{$variables{$variable}}[7]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 411, 352, $bounds{$variables{$variable}}[8]/$dividers{$variable}, $black);
			$image->string(gdSmallFont, 443, 352, $bounds{$variables{$variable}}[9]/$dividers{$variable}, $black);
		}
			open (SEAMASK, "$docroot/masks/whiteocean2.gif") || die "Unable to open SEAMASK\n";
			my $mask_image = newFromGif GD::Image(SEAMASK) ||  die "Unable to create SEAMASK gif";
			$image->copy($mask_image,0,0,0,0,640,320);
			close SEAMASK;
		#$image->string(gdSmallFont, 500, $data_desc{n_rows}*$scale-15, "Plotted by the IPCC-DDC", $black);
		# New image to carry header information
		my $header_image = new GD::Image(640,420);
		$white = $header_image->colorAllocate(255,255,255);
		$black = $header_image->colorAllocate(0,0,0);
		$header_image->string(gdSmallFont, 0, 20, "1961-90 $start_month to $end_month observed $variable plus 20${time_slice1}s $gcm $forcing_type$scenario$ensemble_member modelled changes", $black);
		$header_image->copy($image,0,50,0,0,640,370);
		# Free up some memory
		$image = new GD::Image(0,0);
		# Write out the image
		$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}$mask_types{$map_type}plus.gif";
		if (!-e "$file") {
			open(CACHE_IMAGE, ">$file") || print STDERR "Unable to open CACHE_IMAGE \"$file\": $!\n";
			binmode CACHE_IMAGE;
			print CACHE_IMAGE $header_image->gif;
			close(CACHE_IMAGE);
		}

		binmode STDOUT;
		print $header_image->gif;
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
		
		$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario1) . "$ensemble_member1$time_slice1" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}plus.dat.gz";
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

sub get_file_name(){
#print STDERR "ensemble_member = $ensemble_member\n";
return( "$data_path/gcm/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member" . "$time_slice." . uc($variables{$variable}));

}

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
 #print STDERR "sub get_file_name obs period = $period\n";
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
print STDERR " read_obs_data() sub\n";
    if ($gcm eq "HadCM2"){
	# open read and process binary data
	$data_desc{n_rows} = 71;
	$data_desc{n_cols} = 96;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	#print STDERR "HadCM2 Reading data file\n";
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	# print STDERR "Bytes read=$bytes_read";

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


		

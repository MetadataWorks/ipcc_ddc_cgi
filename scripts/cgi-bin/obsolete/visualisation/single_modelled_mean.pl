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

my %scenarios = (
	"A", "1% per annum (IS92a)",
	"D", "0.5% per annum, (IS92d)",
);

my %ensemble_members = (
	"1",	"Ensemble 1",
	"2",	"Ensemble 2",
	"3",	"Ensemble 3",
	"4",	"Ensemble 4",
	"X", "Ensemble Mean",
);

my %timeslices = (
	"20", "2010-2039 (2020's)",
	"50", "2040-2069 (2050's)",
	"80", "2070-2099 (2080's)",
);



my %bounds = (
	tmp		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300 ],
	tmx		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300 ],
	tmn		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300 ],
	dtr 	=> [ 20, 40, 60, 80, 100, 120, 140, 160, 180, 200 ],
	diu		=> [ 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000 ],
	pre		=> [ 1, 5, 10, 20, 30, 40, 50, 60, 70, 80 ], # need to invert colours
	vap		=> [ 30, 60, 90, 120, 150, 180, 210, 240, 270, 300 ], # need to invert colours
	cld		=> [ 5, 15, 25, 35, 45, 55, 65, 75, 85, 95 ], # need to invert colours
	wnd		=> [ 1, 5, 10, 20, 30, 40, 50, 60, 70, 80 ],
	rad		=> [ 20, 50, 80, 110, 140, 170, 200, 230, 260, 290 ],
	wet		=> [ 10, 20, 30, 40, 50, 100, 150, 200, 250, 300 ], # need to invert colours
	frs		=> [ 10, 20, 30, 40, 50, 100, 150, 200, 250, 300 ], # need to invert colours

	# Difference between 2 fields?
	#tmp	=> [ -200, -100, -50, 0, 50, 100, 200, 300, 400, 500 ],
	diffpre	=> [ -300, -200, -100, 0, 100, 200, 300, 400, 500, 600 ],
	diffvap	=> [ -200, -100, -50, 0, 50, 100, 200, 400, 800, 1600 ],
	diffcld	=> [ -600, -400, -200, 0, 200, 400, 600, 800, 1000, 1200 ],
	diffwet	=> [ -600, -500, -400, -300, -200, -100, 0, 100, 200,300 ],	

	motmp 	=> [ -900, -600, -300, 0, 300, 600, 900, 1200, 1500, 1800 ],
	morad	=> [ -6000, -5000, -4000, -3000, -2000, -1000, 0, 1000, 2000, 3000 ],
	mocld	=> [ -2400, -1800, -1200, -600, 0, 600, 1200, 1800, 2400, 3000 ],
);

print STDERR "Beginning run at " . localtime(time) . "\n";

# set default values for ensemble_member and scenario

# Retrieve CGI input
my $query = new CGI;
my $gcm = $query->param('resolution');
my $variable = $query->param('variable');
my $time_slice = $query->param('time_slice');
my $forcing_type = $query->param('forcing_type');
my $start_month = $query->param('start_month');
my $end_month = $query->param('end_month');
my $map_type = $query->param('map_type');
my $scenario = $query->param('scenario');
my $ensemble_member = $query->param('ensemble_member');
my $return_format=$query->param('format');
my $return_compressed = $query->param('compressed');

($scenario ne "" ) || ($scenario = "A");
($ensemble_member ne "") || ($ensemble_member = 1);
# to use script for 61-90 data only.   
$time_slice= 61;

print STDERR "variable=$variable\nstart_month = $start_month\nend_month=$end_month\nresolution=$resolution\nperiods=$periods\nreturn_format=$return_format\nreturn_compressed=$return_compressed\n";

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
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.dat.gz";
}
else
{
	$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.gif";
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
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.dat.gz\"";
	}
	elsif ($return_format eq "text")
	{
		open (DATA, "gzip -dc $file |");
		$type = "text/plain";
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.dat.gz\"";
	}
	else
	{
		open (DATA, $file);
		$disposition .= "filename=\"$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.gif\"";
		$type = "image/gif";
	}
		my @raw_data = <DATA>;
		
		my $data = join("",@raw_data);
		print $query->header(-type => $type,
									-content_disposition => $disposition,
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
	my @map;
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

	# Graphics stuff
	if ( $return_format ne "text" )
	{
		print "Content-type: image/gif\n\n";

		my $image;
		if (open (MASK, "$mask") ) {
			$image = newFromGif GD::Image(MASK) || print STDERR "Unable to create new image: $!\n";
			close MASK;
		} else {
			print STDERR "Unable to open MASK \"$mask\": $!\n";
			$image = new GD::Image($data_desc{n_cols},$data_desc{n_rows}+16);
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
		my $scale = (1/1.125);
		my $offset_x = 360;
		my $offset_y = 0;

		# Print grid
		for ($x=0; $x<$data_desc{n_cols}*$scale; $x=($x+60*$scale)) {
			for ($y=0; $y<$data_desc{n_rows}*$scale; $y=($y+60*$scale)) {
				$image->rectangle($x,$y,$x+60*$scale,$y+60*$scale,$grey);
			}
		}

		$t2 = new Benchmark;
		for ($row = 0; $row < $data_desc{n_rows}; $row++) {
			if ($row+$offset_y >= 0) {
				$offset_y = 0;
			}
			$offset_x = 360;
			for ($col=0; $col < $data_desc{n_cols}; $col++) {
				if (($col >= 360) && ($col+$offset_x) >= ($data_desc{n_cols})) { $offset_x = -360;}
				$value = $map[$row][$col] / ($num_of_months);
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
							if ($value <= $bounds{$variables{$variable}}[0]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col0); last SWITCH; }
							# Normal
							if ($value > $bounds{$variables{$variable}}[0] && $value <= $bounds{$variables{$variable}}[1]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col1); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[1] && $value <= $bounds{$variables{$variable}}[2]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col2); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[2] && $value <= $bounds{$variables{$variable}}[3]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col3); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[3] && $value <= $bounds{$variables{$variable}}[4]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col4); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[4] && $value <= $bounds{$variables{$variable}}[5]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col5); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[5] && $value <= $bounds{$variables{$variable}}[6]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col6); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[6] && $value <= $bounds{$variables{$variable}}[7]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col7); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[7] && $value <= $bounds{$variables{$variable}}[8]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col8); last SWITCH; }
							if ($value > $bounds{$variables{$variable}}[8] && $value <= $bounds{$variables{$variable}}[9]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col9); last SWITCH; }
							# Out of bounds (too high)?
							if ($value >= $bounds{$variables{$variable}}[9]) { $image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$col10); last SWITCH; }
							# Pathological case!
							$image->setPixel( ($col+$offset_x)*$scale,($row+$offset_y)*$scale,$black); $foo = 1;
						}
					}
				}
			}
		}
		$t3 = new Benchmark;
		$td = timediff($t3, $t2);
		print STDERR "time in pixel loop: ", timestr($td), "\n";

		$image->string(gdSmallFont, 500, $data_desc{n_rows}*$scale-15, "Plotted by the IPCC-DDC", $black);

		# Write out the image
		$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.gif";
		if (!-e "$file") {
			open(CACHE_IMAGE, ">$file") || print STDERR "Unable to open CACHE_IMAGE \"$file\": $!\n";
			binmode CACHE_IMAGE;
			print CACHE_IMAGE $image->gif;
			close(CACHE_IMAGE);
		}

		binmode STDOUT;
		print $image->gif;
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
		
		$file = "$cache_path/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice" . uc($variables{$variable}) . "$months{$start_month}$months{$end_month}.dat.gz";
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
return( "$data_path/gcm/" . lc($gcm) . "/$gcms{$gcm}$forcing_type" . uc($scenario) . "$ensemble_member$time_slice." . uc($variables{$variable}));

}

sub read_data() {
 
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

sub process_binary
{
    my ($data1) = @_;
    for ( my $i=0; $i<=11; $i++)
    {
	for (my $rowcount = 0; $rowcount < $data_desc{n_rows}; $rowcount++){
	    my $adder = $i * $data_desc{n_rows};
		my @data_row;
		for (my $colcount = 0; $colcount < $data_desc{n_cols}; $colcount++){;
			# Maybe use "unpack" instead of the following
        		my ($part1, $part2) = $data1 =~ /^(.)(.).*/s;
			$data1 =~ s/^..//s;
        		$part1 = ord($part1);
        		$part2 = ord($part2);
			#print STDERR "part1 = $part1\tpart2=$part2\t count = $count\n";
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

# WELCOME TO THE CODE GRAVEYARD!

# Work on data file
#$file = "$data_path/observed/c$variables{$variable}$period.dat";
#open(DATA, "$file") || print STDERR "Unable to open DATA \"$file\": $!\n";
#@raw_data = <DATA>;
#close (DATA);

#open(DATA, "$file") || print STDERR "Unable to open DATA \"$file\": $!\n";
#binmode DATA;
#undef $/;
#my $compressed_data = <DATA>;
#close (DATA);

#my $uncompressed_data = uncompress($compressed_data) || print STDERR "Decompression failed: $!\n";

#my $x = inflateInit() || print STDERR "Cannot create an inflation stream: $!\n";
#my $output, $status;

#while (read (DATA, $foo, 4096)) {
#	($output, $status) = $x->inflate(\$foo) ;
#	push @raw_data, $output if $status == Z_OK || $status == Z_STREAM_END;
#	last if $status != Z_OK;
#}
#print STDERR "inflation failed: $! ($status)\n" unless $status == Z_STREAM_END;
# editor settings for vim, tabs -> 3 spaces wide
# vim:set ts=3:set sw=3:

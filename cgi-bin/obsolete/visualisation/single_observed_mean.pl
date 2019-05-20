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
my $cache_path = "/tmp/ddc_legacy_cache/visualisation_data";
my $mask = "$data_path/masks/image7.gif";
my $measure_max = -9999;
my $measure_min = 9999;
my $mean_reading, $mean_count = 0;
my $cru_cols = 1;


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

my %bounds = (
	tmp		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300 , 1],
	tmx		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300, 1 ],
	tmn		=> [ -150, -100, -50, 0, 50, 100, 150, 200, 250, 300, 1 ],
	dtr 	=> [ 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 1 ],
	diu		=> [ 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 1 ],
	pre		=> [ -80, -70, -60, -50, -40, -30, -20, -10, -5, -1, -1 ], # need to invert colours
	vap		=> [ -300, -270, -240, -210, -180, -150, -120, -90, -60, -30, -1],  
	cld		=> [ -95, -85, -75, -65, -55, -45, -35, -25, -15, -5, -1 ], # need to invert colours
	wnd		=> [ 1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 1 ],
	rad		=> [ 20, 50, 80, 110, 140, 170, 200, 230, 260, 290, 1 ],
	wet		=> [ -300, -250, -200, -150, -100, -50, -40, -30, -20, -10, -1 ], # need to invert colours
	frs		=> [ -300, -250, -200, -150, -100, -50, -40, -30, -20, -10, -1 ], # need to invert colours

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

# Retrieve CGI input
my $query = new CGI;
my $variable = $query->param('variable');
my $start_month = $query->param('start_month');
my $end_month = $query->param('end_month');
my $resolution =  $query->param('resolution');
my $periods = $query->param('periods');
my $return_format = $query->param('format');
my $return_compressed = $query->param('compressed');
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

# Calculate timeslice
my ($start_year, $end_year) = split (/-/,$periods);
my $period = substr($start_year,2,2) . substr($end_year,2,2);

# Try to get the data from the cache, first work out what the cache file
# is called

if ( $return_format eq "text" )
{
	$file = "$cache_path/observed/${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.dat.gz";
}
else
{
	$file = "$cache_path/observed/${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.gif";
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
		$disposition .= "filename=\"${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.dat.gz\"";
	}
	elsif ($return_format eq "text")
	{
		open (DATA, "gzip -dc $file |");
		$type = "text/plain";
		$disposition .= "filename=\"${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.dat\"";
	}
	else
	{
		open (DATA, $file);
		$disposition .= "filename=\"${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.gif\"";
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
	if (!-e $file){
		print $query->header(),$query->start_html(-title=>'Data Not Found');
		print $query->h2('The data for the requested scenario is not available.');
		print $query->end_html;
		die "Data file not found\n";
	}
	@raw_data = &read_data() ;
	#print STDERR "$raw_data[70]\n";
	# Read data into map array
	my @map;
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
					$map[$row][$col] += $chunks[$col];
				}
				elsif ( $map[$row][$col] != -9999 ) {
					$map[$row][$col] = -9999;
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
			if ( $map[$row][$col] != -9999 ) {
				$map[$row][$col] = int($map[$row][$col] / $num_of_months + 0.5);
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
		for ($x=0; $x<$data_desc{n_cols}*$scale; $x=($x+60*$scale)) {
			for ($y=0; $y<$data_desc{n_rows}*$scale; $y=($y+60*$scale)) {
				$image->rectangle($x,$y,$x+60*$scale,$y+60*$scale,$grey);
			}
		}

		$t2 = new Benchmark;
		# inverter taken from bounds array = -1 if colours are to be inverted
		$inverter= $bounds{$variables{$variable}}[10];

		for ($row = 0; $row < $data_desc{n_rows}; $row++) {
			if ($row+$offset_y >= 0) {
				$offset_y = 0;
			}
			$offset_x = $data_desc{n_cols}/2;
			for ($col=0; $col < $data_desc{n_cols}; $col++) {
				if (($col >= $data_desc{n_cols}/2) && ($col+$offset_x) >= ($data_desc{n_cols})) { $offset_x = -$data_desc{n_cols}/2;}
				#$value = $map[$row][$col] / ($num_of_months);
				$value = $map[$row][$col] ;
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
		$image->filledRectangle(0,320,640,370,$white);
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
		# New image to carry header information
		# New image to carry header information
		my $header_image = new GD::Image(640,420);
		$white = $header_image->colorAllocate(255,255,255);
		$black = $header_image->colorAllocate(0,0,0);
		$header_image->string(gdSmallFont, 0, 20, "Observed $variable $start_month to $end_month $periods", $black);
		$header_image->copy($image,0,50,0,0,640,370);
		# Free up some memory
		$image = new GD::Image(0,0);

		# Write out the image
		$file = "$cache_path/observed/${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.gif";
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
			}
			$document .= "\n";

		}

		# Cache the data
		
		$file = "$cache_path/observed/${resolution}c$variables{$variable}$period$months{$start_month}$months{$end_month}.dat.gz";
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
	if ($resolution eq "HadCM2"){
		return("$data_path/observed/had$variables{$variable}.gz");
	}
	elsif ($resolution eq "GFDL-R15"){
		return("$data_path/observed/gfdl$variables{$variable}.gz");
	}
	elsif ($resolution eq "ECHAM4"){
		print STDERR "Echam file name\n";
		return("$data_path/observed/echam$variables{$variable}.gz");

	}
	elsif ($resolution eq "CGCM1"){
		return("$data_path/observed/ccm$variables{$variable}.gz");
	}
#	elsif ($variables{$variable} eq "rad"){
#		return("$data_path/observed/c$variables{$variable}$period.gz");
#	}


	else {
		return("$data_path/observed/c$variables{$variable}$period.zip");
	}

}

sub read_data() {
    if ($resolution eq "HadCM2"){
	# open read and process binary data
	$data_desc{n_rows} = 71;
	$data_desc{n_cols} = 96;
	$read_length = 2 * $data_desc{n_rows} * $data_desc{n_cols} * 12;
	open(DATA, "gzip -dc $file |")|| die "unable to open data file $file \n";
	binmode DATA;
	$bytes_read = read(DATA,$raw_binary, $read_length);
	# print STDERR "Bytes read=$bytes_read";

	close (DATA);
	@raw_data = &process_binary ($raw_binary);
    }
    elsif ($resolution eq "GFDL-R15"){
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
    elsif ($resolution eq "ECHAM4"){
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
    elsif ($resolution eq "CGCM1"){
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


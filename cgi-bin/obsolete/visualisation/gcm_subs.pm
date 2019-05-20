#!/usr/bin/perl

sub get_ascii_data (){
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
			chomp @$shaped_data[$row + $multiplier];
			#print STDERR "row:$row @$shaped_data[$row + $multiplier]";
			@chunks = unpack("a5"x$data_desc{n_cols},@$shaped_data[$row + $multiplier]);
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
}

sub draw_picture (){
	# Graphics stuff
	my ($map, $bounds, $n_rows,$n_cols,$map_type,$cru_cols,$measure_min,$measure_max,$divider,$docroot,$image_file,$caption) = @_;
		print STDERR "@_\nmap[0][0]: @$map->[0][0]\n";
		#print STDERR "bounds: " . @$bounds[3] . "\n";
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
		my $scale = (640/$n_cols);
		my $y_scale = (320/$n_rows);
		my $offset_x = 360;
		my $offset_y = 0;

		# Print grid
		#for ($x=0; $x<$n_cols*$scale; $x=($x+60*$scale)) {
		#	for ($y=0; $y<$n_rows*$scale; $y=($y+60*$scale)) {
		#		$image->rectangle($x,$y,$x+60*$scale,$y+60*$scale,$grey);
		#	}
		#}

		$t2 = new Benchmark;
		# inverter taken from bounds array = -1 if colours are to be inverted
		$inverter= @$bounds[10];
		print STDERR "inverter = $inverter\n";
		for ($row = 0; $row < $n_rows; $row++) {
			if ($row+$offset_y >= 0) {
				$offset_y = 0;
			}
			$offset_x = $n_cols/2;
			for ($col=0; $col < $n_cols; $col++) {
				if (($col >= $n_cols/2) && ($col+$offset_x) >= ($n_cols)) { $offset_x = -$n_cols/2;}
				#$value = $map[$row][$col] / ($num_of_months);
				# $map has already been averaged over months hasn't it?
				$value = @$map->[$row][$col];
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
							if ($value * $inverter <= @$bounds[0]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col0);
	#print STDERR "\nvalue: $value, bounds:  @$bounds[0]\n";
	#die;
							last SWITCH; }
							# Normal
							if ($value * $inverter > @$bounds[0] && $value * $inverter <= @$bounds[1]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col1); last SWITCH; }
							if ($value* $inverter  > @$bounds[1] && $value * $inverter  <= @$bounds[2]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col2); last SWITCH; }
							if ($value * $inverter > @$bounds[2] && $value* $inverter  <= @$bounds[3]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col3); last SWITCH; }
							if ($value * $inverter > @$bounds[3] && $value * $inverter <= @$bounds[4]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col4);
	#print STDERR "\nvalue: $value, bounds:  @$bounds[3]\n";
	#die;
 last SWITCH; }
							if ($value * $inverter > @$bounds[4] && $value * $inverter <= @$bounds[5]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col5); last SWITCH; }
							if ($value * $inverter > @$bounds[5] && $value * $inverter <= @$bounds[6]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col6); last SWITCH; }
							if ($value* $inverter  > @$bounds[6] && $value * $inverter <= @$bounds[7]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col7); last SWITCH; }
							if ($value * $inverter > @$bounds[7] && $value * $inverter <= @$bounds[8]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col8); last SWITCH; }
							if ($value * $inverter > @$bounds[8] && $value * $inverter <= @$bounds[9]) { $image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col9); last SWITCH; }
							# Out of bounds (too high)?
							if ($value * $inverter >= @$bounds[9]) {$image->filledRectangle( ($col+$offset_x)*$scale,($row+$offset_y)*$y_scale,($col+1+$offset_x)*$scale-1,($row+1+$offset_y)*$y_scale-1,$col10); last SWITCH; }
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
print STDERR "var_factors{variable}: " . $var_factors{$variable};
			$image->string(gdSmallFont, 155, 352, -@$bounds[9]/$divider, $black);
			$image->string(gdSmallFont, 187, 352, -@$bounds[8]/$divider, $black);
			$image->string(gdSmallFont, 219, 352, -@$bounds[7]/$divider, $black);
			$image->string(gdSmallFont, 251, 352, -@$bounds[6]/$divider, $black);
			$image->string(gdSmallFont, 283, 352, -@$bounds[5]/$divider, $black);
			$image->string(gdSmallFont, 315, 352, -@$bounds[4]/$divider, $black);
			$image->string(gdSmallFont, 347, 352, -@$bounds[3]/$divider, $black);
			$image->string(gdSmallFont, 379, 352, -@$bounds[2]/$divider, $black);
			$image->string(gdSmallFont, 411, 352, -@$bounds[1]/$divider, $black);
			$image->string(gdSmallFont, 443, 352, -@$bounds[0]/$divider, $black);
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
			$image->string(gdSmallFont, 155, 352, @$bounds[0]/$divider, $black);
			$image->string(gdSmallFont, 187, 352, @$bounds[1]/$divider, $black);
			$image->string(gdSmallFont, 219, 352, @$bounds[2]/$divider, $black);
			$image->string(gdSmallFont, 251, 352, @$bounds[3]/$divider, $black);
			$image->string(gdSmallFont, 283, 352, @$bounds[4]/$divider, $black);
			$image->string(gdSmallFont, 315, 352, @$bounds[5]/$divider, $black);
			$image->string(gdSmallFont, 347, 352, @$bounds[6]/$divider, $black);
			$image->string(gdSmallFont, 379, 352, @$bounds[7]/$divider, $black);
			$image->string(gdSmallFont, 411, 352, @$bounds[8]/$divider, $black);
			$image->string(gdSmallFont, 443, 352, @$bounds[9]/$divider, $black);
		}
		if ($map_type eq "Land"){
			open (SEAMASK, "$docroot/masks/whiteocean2.gif") || die "Unable to open SEAMASK\n";
			my $mask_image = newFromGif GD::Image(SEAMASK) ||  die "Unable to create SEAMASK gif";
			$image->copy($mask_image,0,0,0,0,640,320);
			close SEAMASK;
		}else{
			open (GRIDMASK, "$docroot/masks/grid2.gif") || die "Unable to open GRIDMASK\n";
			my $mask_image = newFromGif GD::Image(GRIDMASK) ||  die "Unable to create GRIDMASK gif";
			$image->copy($mask_image,0,0,0,0,640,320);
			close GRIDMASK;
		}
		#$image->string(gdSmallFont, 500, $n_rows*$scale-15, "Plotted by the IPCC-DDC", $black);
		# New image to carry header information
		my $header_image = new GD::Image(640,420);
		$white = $header_image->colorAllocate(255,255,255);
		$black = $header_image->colorAllocate(0,0,0);
		$header_image->string(gdSmallFont, 0, 20, $caption, $black);
		$header_image->copy($image,0,50,0,0,640,370);
		# Free up some memory
		$image = new GD::Image(0,0);
		# Write out the image

		if (!-e "$image_file") {
			open(CACHE_IMAGE, ">$image_file") || print STDERR "Unable to open CACHE_IMAGE \"$image_file\": $!\n";
			binmode CACHE_IMAGE;
			print CACHE_IMAGE $header_image->gif;
			close(CACHE_IMAGE);
		}

		binmode STDOUT;
		print $header_image->gif;


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
($gcm,$short_gcm,$forcing_type,$scenario,$ensemble_member,$time_slice,$short_variable) = @_;
#print STDERR "ensemble_member = $ensemble_member\n";
return( "$data_path/gcm/" . lc($gcm) . "/$short_gcm$forcing_type" . uc($scenario) . "$ensemble_member" . "$time_slice." . uc($short_variable));

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
return true;
__END__


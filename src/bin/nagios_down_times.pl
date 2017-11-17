#!/usr/bin/perl

use strict;
use warnings;

use DateTime;
use Pod::Usage;
use Data::Dumper;
use IO::File;
use Text::ASCIITable;

=pod

=head1 NAME

Nagios Down Times - displays all scheduled downtime in a retention file sorted by end time.

=head1 SYNOPSIS

  nagios_down_times.pl /path/to/retention/file

=head1 DESCRIPTION

This script looks for host downtime and service downtime entries in the nagios retention file.

In the future, I might add checking for whether or not a bit of downtime
expires in the evening or on weekends.  We might even be able to alert on that.

=head1 AUTHOR

Martin VanWinkle

=cut


my $retention_file = $ARGV[0] 
	|| '/var/log/nagios/retention.dat';

if (! -f $retention_file)
{
	pod2usage ( -message => "You must give me the path to the retention file as an argument...", -exitval => 1);
	exit 1;
}

my @OUTPUT_COLUMNS = (
	{name => 'downtime_id', alias => 'id'},
	{name => 'end_time_nice', alias => 'end_time',},
	{name => 'is_in_effect', alias => 'in_effect',},
	{name => 'downtime_type', alias => 'type',},
	{name => 'host_name', alias => 'host',},
	{name => 'service_description', alias => 'description',},
	{name => 'author', alias => 'user',},
);
	
my $downtime_data = read_downtime_data($retention_file);
add_nice_dates($downtime_data);

#dump_output($downtime_data);
dump_tabular($downtime_data);

#print Dumper($downtime_data);

exit;

=pod

=head1 SUBROUTINES

=head2 dump_output

Takes an array of hashes and outputs the values of
@OUTPUT_COLUMNS in tab-delimited format.

=cut

sub dump_output
{
	my ($downtime_data) = @_;
	
	my @sorted_data = sort {$a->{end_time}<=>$b->{end_time}} @$downtime_data;
	
	my $downtime_entry;
	
	my $delimiter = "\t";
	
	print join($delimiter, map{$_->{alias}} @OUTPUT_COLUMNS),$/;
	
	foreach $downtime_entry (@sorted_data)
	{
		my @output_data;
		my $output_column;
		
		foreach $output_column(@OUTPUT_COLUMNS)
		{
			push @output_data, (defined $downtime_entry->{$output_column}?
				$downtime_entry->{$output_column} : '');
		}
		
		print join($delimiter, @output_data),$/;
	}
}

=pod

=head2 add_nice_dates

For the keys listed in @time_converts , takes a downtime entry and
converts epoch to ISO date.

=cut

sub add_nice_dates
{
	my ($downtime_data) = @_;
	
	my $downtime_entry;

	my @time_converts = qw(
		entry_time
		start_time
		end_time
	);
	
	foreach $downtime_entry ( @$downtime_data)
	{

		
		my $time_convert;
		foreach $time_convert(@time_converts)
		{
			my $dt = DateTime->from_epoch(epoch => $downtime_entry->{$time_convert});
			my $key_name = $time_convert.'_nice';
			$downtime_entry->{$key_name} = $dt->ymd('-').' '.$dt->hms(':');
		}
	}
}

=pod

=head2 read_downtime_data

Reads all downtime data from the nagios retention file.

=cut

sub read_downtime_data
{
	my ($file_name) = @_;
	
	my $fh = new IO::File "<$file_name"
		or die "Can't open $file_name for reading: $!";
	
	my $line;
	
	my @all_data;
	my $data = {};
	
	while (defined ($line = <$fh> ) )
	{
		next if $line =~ m/\s*#/;
		chomp($line);
		if ($line =~ m/\{/)
		{
			if (scalar keys %$data)
			{
				push @all_data, $data if defined $data->{end_time};
				$data = {}
			}
			my @parts = split(/\s+/, $line);
			
			if ($parts[0] !~ m/downtime/)
			{
				while (defined $line && $line !~ m/\}/)
				{
					$line = <$fh>;
				}
				next;
			}
			$data->{downtime_type} = $parts[0];
		}
		elsif ($line !~ m/\}/)
		{
			#print "Found line: $line\n";
			my @parts = split('=',$line,2);
			$data->{$parts[0]} = $parts[1];
		}
	}
	push @all_data, $data if defined $data->{end_time};
	
	$fh->close();
	
	return \@all_data;
}


sub dump_tabular
{
	my ($downtime_data) = @_;
	
	my @sorted_data = sort {$a->{end_time}<=>$b->{end_time}} @$downtime_data;

	my $table = Text::ASCIITable->new();
	$table ->setCols( map{$_->{alias}} @OUTPUT_COLUMNS );

	# $table->add($downtime_data);
	
	my $downtime_entry;
	foreach $downtime_entry (@sorted_data)
	{
		my @output_data;
		my $output_column;
		
		foreach $output_column(map{$_->{name}} @OUTPUT_COLUMNS)
		{
			push @output_data, (defined $downtime_entry->{$output_column}?
				$downtime_entry->{$output_column} : '');
		}
		
		$table->addRow(@output_data);
	}	
	
	
	print $table,$/;
	
	
}

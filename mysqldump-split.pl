#!/usr/bin/perl

use warnings;
use strict;

my $tpl_fn_head = '%s-10_head.mysqldump';
my $tpl_fn_tbl  = '%s-50_table-%s.mysqldump';
my $tpl_fn_tail = '%s-90_tail.mysqldump';

my $schema = $ENV{SCHEMA} // 'UNDEF';

my $b_seen_table_struct = 0;
my $step = 0; # 0 - head, 1 - data, 2 - tail

my $fn = my $new_fn = sprintf( $tpl_fn_head, $schema );
my $FH = undef;


my $ll = undef; # last_line
while( <> ) {

	if ( m/^\-\- / ) {
		if ( $step == 0 and $schema eq 'UNDEF' and m/^\-\- Host: .* Database: (\S+)$/ ) {
			$schema = $1;
		}
		if (
			$step < 2 and (
				m/^\-\- Table (structure) for table \`(.*)\`$/
				or
				m/^\-\- Dumping (data) for table \`(.*)\`$/
			) 
		) {
			$step = 1;
			$b_seen_table_struct = 1 if $1 eq 'structure';
			# When dump contains both struct and data the data should not switch files as it is already switched by the struct
			if ( $1 eq 'structure' or ! $b_seen_table_struct ) {
				$new_fn = sprintf( $tpl_fn_tbl, $schema, $2 );
			}
		} elsif( $step == 1 ) {
			$new_fn = sprintf( $tpl_fn_tail, $schema );
			$step = 2;
		}
	}
	if ( defined $new_fn ) {
		if ( defined $FH ) { close $FH or warn("Closing $fn failed: $!"); }
		open( $FH, '>', $new_fn ) or die("Open failed: $new_fn : $!");
		$fn = $new_fn;
		$new_fn = undef;
	}
	print $FH $ll if defined $ll;
	$ll = $_;
}

if ( defined $FH ) {
	print $FH $ll if defined $ll;
	close $FH or warn("Closing $fn failed: $!");
}

if ( ! exists $ENV{SCHEMA} ) {
	rename( sprintf( $tpl_fn_head, 'UNDEF' ), sprintf( $tpl_fn_head, $schema ) )
		or warn( "rename: $!");
}

=head1 NAME

  mysqldump-split.pl - Perl script that splits monolith mysqldump output to per-table files

=head1 USAGE

  pushd /dest/dir
  mysqldump-split.pl < /path/to/myschema.mysqldump
  mysqldump --databases myschema | mysqldump-split.pl
  popd

=head1 DESCRIPTION

This Perl script reads mysqldump's output for a single MySQL DB from STDIN.
It splits this input to several files:

  - A header file
  - Multiple per-table files
  - A footer file

If no table definitions are found only the header is created.
The output files are created in the current directory.

=head1 PURPOSE

I needed to take consistent snapshots of large MySQL DBs and have per table data.
The consistent snapshots can be done by either:

  - using the mysqldump --single-transaction switch when all the tables in the DB use transactional engines or
  - table locking

I needed to have the per-table data for backup purposes - to avoid writing
too much new data on the target copy-on-write backup filesystem.


=head1 OUTPUT FILE NAMING

The names of the generated files is as follows by default:

  SCHEMA-10_head.mysqldump
  SCHEMA-50_table-TABLE.mysqldump
  SCHEMA-90_tail.mysqldump'

Table files are not enumerated in order the names to be kept when e.g. a table
is added or dropped.

SCHEMA name can be overridden by passing the environment variable "SCHEMA",
otherwise it is read from the mysqldump output.

The file naming scheme was chosen in order the generated file names to be
sortable. mysqldump sorts tables by name in its output. It should be easy
to concatenate the files and generate exactly the same output as this script
has read on its STDIN. Note however that the sort order of the file lists
in the shell might be locale dependent and you might need to do something
like:

   LANG=C ls | xargs cat > ../SCHEMA.sql

in order to get the tables sorted in the way that it was in the original
mysqldump output.

=head1 LIMITS

A monolith mysqldump file for multiple DBs is not supported - subsequent DB data
will go to the footer. It should be easy to modify this script to support it.

=head1 TODO

  - Check for problems with BLOB data
  - Test with different mysql(dump) versions
  - Support splitting mysqldump output containing multiple DBs ?
  - Separate files for VIEWS/PROCEDURES/EVENTS ?

=head1 Author and licence

Author: Delian Krustev <krustev@krustev.net>, 2019

License: GPLv2.0 plus the following requirement:

  - The original author of this software, Delian Krustev, is granted "Public domain" rights to any derived work.

The addition is needed for e.g. to allow further re-licencing if necessary.
E.g think of ZFS missing from the Linux kernel due to OSS licencing
incompatibilities.

=head1 Appreciation

I do these projects in my spare time and try to give back to the open source community.
If you find my work useful or you think that I have saved you a couple of valuable hours
you can send me a donation at <krustev-paypal@krustev.net> . Or just say thanks :-)

Thanks !

=cut

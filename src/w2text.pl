#!/usr/bin/env perl

# w2text, a plain text exporter for w2do
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
#
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
#
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use locale;
use Text::Wrap;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');       # Script name.
use constant VERSION => '2.2.3';                   # Script version.

# General script settings:
our $HOMEDIR         = $ENV{HOME}          || $ENV{USERPROFILE} || '.';
our $savefile        = $ENV{W2DO_SAVEFILE} || catfile($HOMEDIR, '.w2do');

# Appearance settings:
$Text::Wrap::columns = $ENV{W2DO_WIDTH}    || 75;  # Default line width.
our $bare            = 0;                          # Turn off group names?

# Other command-line options:
my $outfile          = '-';                        # Output file name.
my %args             = ();                         # Specifying options.

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occurred.';
  my $return_value = shift || 1;

  # Print message to STDERR:
  print STDERR NAME . ": $message\n";

  # Return failure:
  exit $return_value;
}

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my $time = shift || time;

  # Decompose the given time:
  my @date = localtime($time);

  # Return the result:
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
}

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $args) = @_;

  # Prepare the list of reserved characters:
  my $reserved   = '[\\\\\^\.\$\|\(\)\[\]\*\+\?\{\}]';

  # Escape reserved characters:
  $args->{group} =~ s/($reserved)/\\$1/g if $args->{group};
  $args->{task}  =~ s/($reserved)/\\$1/g if $args->{task};

  # Use default pattern when none is provided:
  my $group      = $args->{group}    || '[^:]*';
  my $date       = $args->{date}     || '[^:]*';
  my $priority   = $args->{priority} || '[1-5]';
  my $state      = $args->{state}    || '[ft]';
  my $task       = $args->{task}     || '';
  my $id         = $args->{id}       || '\d+';

  # Create the mask:
  my $mask       = "^$group:$date:$priority:$state:.*$task.*:$id\$";

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Process each line:
    while (my $line = <SAVEFILE>) {
      # Check whether the line matches given pattern:
      if ($line =~ /$mask/i) {
        # Add line to the selected items list:
        push(@$selected, $line);
      }
      else {
        # Add line to the other items list:
        push(@$rest, $line);
      }
    }

    # Close the save file:
    close(SAVEFILE);
  }

  # Return success:
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message:
  print << "END_HELP";
Usage: $NAME [-b] [-o file] [-s file] [-w width] [-f|-u] [-d date]
              [-g group] [-p priority] [-t task]
       $NAME -h | -v

General options:

  -h, --help               display this help and exit
  -v, --version            display version information and exit

Specifying options:

  -t, --task task          specify the task name
  -g, --group group        specify the group name
  -d, --date date          specify the due date; available options are
                           anytime, today, yesterday, tomorrow, month,
                           year, or an exact date in the YYYY-MM-DD format
  -p, --priority priority  specify the priority; available options are 1-5
                           where 1 represents the highest priority
  -f, --finished           specify the finished task
  -u, --unfinished         specify the unfinished task

Additional options:

  -s, --savefile file      use selected file instead of the default ~/.w2do
  -o, --output file        use selected file instead of the standard output
  -w, --width width        use selected line width; the minimal value is 75
  -b, --bare               organise tasks as a single list (no group names)
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Print the message:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Write items in the task list to the selected output:
sub write_tasks {
  my ($outfile, $args) = @_;

  # Initialize required variables:
  my @data;

  # Load matching tasks:
  load_selection(\@data, undef, $args) or return 0;

  # Open the selected output for writing:
  if (open(FILE, ">$outfile")) {
    # Check whether the list is not empty:
    if (@data) {
      my ($group, $task) = '';

      # Process each task:
      foreach my $line (sort @data) {
        # Parse the task record:
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        # Write heading when group changes:
        if (lc($1) ne $group && !$bare) {
          print FILE "\n" if $group;
          print FILE "$1:\n\n";
          $group = lc($1);
        }

        # Create the task entry:
        $task = ($4 eq 't') ? "$5 (OK)\n" : "$5\n";

        # Write the task entry:
        print FILE wrap('  * ', '    ', $task);
      }

      # Close the output:
      close(FILE);
    }
  }
  else {
    # Report failure:
    print STDERR "Unable to write to `$outfile'.\n";

    # Return failure:
    return 0;
  }

  # Return success:
  return 1;
}

# Fix the group name:
sub fix_group {
  my $group = shift || die 'Missing argument';

  # Check whether it contains forbidden characters:
  if ($group =~ /:/) {
    # Display warning:
    print STDERR "Colon is not allowed in the group name. Removing.\n";

    # Remove forbidden characters:
    $group =~ s/://g;
  }

  # Check the group name length:
  if (length($group) > 10) {
    # Display warning:
    print STDERR "Group name too long. Stripping.\n";

    # Strip it to the maximal allowed length:
    $group = substr($group, 0, 10);
  }

  # Make sure the result is not empty:
  unless ($group) {
    # Display warning:
    print STDERR "Group name is empty. Using the default group instead.\n";

    # Use default group instead:
    $group = 'general';
  }

  # Return the result:
  return $group;
}

# Translate due date alias to YYYY-MM-DD string:
sub translate_date {
  my $date = shift || die 'Missing argument';

  # Translate the alias:
  if    ($date =~ /^\d{4}-[01]\d-[0-3]\d$/) { return $date }
  elsif ($date eq 'anytime')   { return $date }
  elsif ($date eq 'today')     { return date_to_string(time) }
  elsif ($date eq 'yesterday') { return date_to_string(time - 86400) }
  elsif ($date eq 'tomorrow')  { return date_to_string(time + 86400) }
  elsif ($date eq 'month')     { return date_to_string(time + 2678400)  }
  elsif ($date eq 'year')      { return date_to_string(time + 31536000) }
  else  {
    # Report failure and exit:
    exit_with_error("Invalid due date `$date'.", 22);
  }
}

# Translate due date alias to mask:
sub translate_mask {
  my $date = shift;

  # Translate the alias:
  if ($date eq 'month') {
    return substr(date_to_string(time), 0, 8) . '..';
  }
  elsif ($date eq 'year') {
    return substr(date_to_string(time), 0, 5) . '..-..';
  }
  else {
    return translate_date($date);
  }
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Parse command line options:
GetOptions(
  # General options:
  'help|h'         => sub { display_help();    exit 0 },
  'version|v'      => sub { display_version(); exit 0 },

  # Specifying options:
  'task|t=s'       => sub { $args{task}     = $_[1] },
  'group|g=s'      => sub { $args{group}    = $_[1] },
  'date|d=s'       => sub { $args{date}     = $_[1] },
  'priority|p=i'   => sub { $args{priority} = $_[1] },
  'finished|f'     => sub { $args{state}    = 't' },
  'unfinished|u'   => sub { $args{state}    = 'f' },

  # Additional options:
  'savefile|s=s'   => sub { $savefile            = $_[1] },
  'output|o=s'     => sub { $outfile             = $_[1] },
  'width|w=i'      => sub { $Text::Wrap::columns = $_[1] },
  'bare|b'         => sub { $bare                = 1 },
  'no-bare|B'      => sub { $bare                = 0 },
);

# Detect superfluous options:
if (scalar(@ARGV) != 0) {
  exit_with_error("Invalid option `$ARGV[0]'.", 22);
}

# Fix the group option:
if (my $value = $args{group}) {
  $args{group} = fix_group($value);
}

# Translate the due date option:
if (my $value = $args{date}) {
  $args{date} = translate_mask($value)
}

# Check the priority option:
if (my $value = $args{priority}) {
  unless ($value =~ /^[1-5]$/) {
    exit_with_error("Invalid priority `$value'.", 22);
  }
}

# Check the line width option:
if ($Text::Wrap::columns < 75) {
  exit_with_error("Invalid line width `$Text::Wrap::columns'.", 22);
}

# Perform appropriate action:
write_tasks($outfile, \%args) or exit 1;

# Return success:
exit 0;

__END__

=head1 NAME

w2text - a plain text exporter for w2do

=head1 SYNOPSIS

B<w2text> [B<-S>] [B<-o> I<file>] [B<-s> I<file>] [B<-w> I<width>]
[B<-f>|B<-u>] [B<-d> I<date>] [B<-g> I<group>] [B<-p> I<priority>] [B<-t>
I<task>]

B<w2text> B<-h> | B<-v>

=head1 DESCRIPTION

B<w2text> is a plain text exporter for w2do, a simple to use yet efficient
command-line todo manager written in Perl 5. All tasks are listed by
default, but desired subset can be easily selected via specifying options.

=head1 OPTIONS

=head2 General Options

=over

=item B<-h>, B<--help>

Display help message and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head2 Specifying Options

=over

=item B<-t> I<task>, B<--task> I<task>

Specify the I<task> name.

=item B<-g> I<group>, B<--group> I<group>

Specify the I<group> name. The group name should be a single word with
maximum of 10 characters, but longer names are shortened automatically.

=item B<-d> I<date>, B<--date> I<date>

Specify the due I<date>. Available options are B<anytime>, B<today>,
B<yesterday>, B<tomorrow>, B<month>, B<year>, or an exact date in the
YYYY-MM-DD format, e.g. 2008-06-17 for 17 June 2008.

=item B<-p> I<priority>, B<--priority> I<priority>

Specify the I<priority>. Available options are integers between B<1> and
B<5>, where 1 represents the highest priority.

=item B<-f>, B<--finished>

Specify the finished task.

=item B<-u>, B<--unfinished>

Specify the unfinished task.

=back

=head2 Additional Options

=over

=item B<-o> I<file>, B<--output> I<file>

Use selected I<file> instead of the standard output.

=item B<-s> I<file>, B<--savefile> I<file>

Use selected I<file> instead of the default C<~/.w2do> as a save file.

=item B<-w> I<width>, B<--width> I<width>

Use selected line I<width>; the minimal value is B<75>.

=item B<-S>, B<--shallow>

Organise tasks as a single list instead of listing them by groups they
belong to.

=back

=head1 ENVIRONMENT

=over

=item B<W2DO_SAVEFILE>

Use selected file instead of the default C<~/.w2do> as a save file.

=item B<W2DO_WIDTH>

Use selected line width; the minimal value is B<75>.

=back

=head1 FILES

=over

=item I<~/.w2do>

Default save file.

=back

=head1 SEE ALSO

B<w2do>(1), B<w2html>(1), B<perl>(1).

=head1 BUGS

To report bugs or even send patches, you can either add new issue to the
project bugtracker at <http://code.google.com/p/w2do/issues/>, visit the
discussion group at <http://groups.google.com/group/w2do/>, or you can
contact the author directly via e-mail.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the w2do source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

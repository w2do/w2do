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
use constant VERSION => '2.1.1';                   # Script version.

# Global script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE} || '.';
our $savefile  = $ENV{W2DO_SAVEFILE}    || catfile($HOMEDIR, '.w2do');

# Appearance settings:
$Text::Wrap::columns = $ENV{W2DO_WIDTH} || 75;     # Default line width.

# Command line options:
my $outfile    = '-';                              # Output file name.
my %args       = ();                               # Specifying options.

# Signal handlers:
$SIG{__WARN__} = sub {
  exit_with_error((shift) . "Try `--help' for more information.", 22);
};

# Display script usage:
sub display_help {
  my $NAME = NAME;

  # Print the message:
  print << "END_HELP";
Usage: $NAME [-o file] [-s file] [-w width] [-f|-u] [-d date] [-g group]
              [-p priority] [-t task]
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
END_HELP
}

# Display script version:
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
}

# Write items in the task list to the selected output:
sub write_tasks {
  my ($outfile, $args) = @_;
  my @data;

  # Load matching tasks:
  load_selection(\@data, undef, $args);

  # Open the selected output for writing:
  if (open(SAVEFILE, ">$outfile")) {
    # Check whether the list is not empty:
    if (@data) {
      my ($group, $task) = '';
      
      # Process each task:
      foreach my $line (sort @data) {
        # Parse the task record:
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        # Write heading when group changes:
        if (lc($1) ne $group) {
          print SAVEFILE "\n" if $group;
          print SAVEFILE "$1:\n\n";
          $group = lc($1);
        }

        # Create the task entry:
        $task = ($4 eq 't') ? "$5 (OK)\n" : "$5\n";

        # Write the task entry:
        print SAVEFILE wrap('  * ', '    ', $task);
      }

      # Close the output:
      close(SAVEFILE);
    }
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$outfile'.", 13);
  }
}

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $args) = @_;
  my  $reserved  = '[\\\\\^\.\$\|\(\)\[\]\*\+\?\{\}]';

  # Escape reserved characters:
  $args->{group} =~ s/($reserved)/\\$1/g if $args->{group};
  $args->{task}  =~ s/($reserved)/\\$1/g if $args->{task};

  # Use default pattern when none is provided:
  my $group    = $args->{group}    || '[^:]*';
  my $date     = $args->{date}     || '[^:]*';
  my $priority = $args->{priority} || '[1-5]';
  my $state    = $args->{state}    || '[ft]';
  my $task     = $args->{task}     || '';
  my $id       = $args->{id}       || '\d+';

  # Create the mask:
  my $mask     = "^$group:$date:$priority:$state:.*$task.*:$id\$";

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
  else {
    # Report failure and exit:
    exit_with_error("Unable to read from `$savefile'.", 13);
  }
}

# Translate due date alias to mask:
sub translate_mask {
  my $date = shift;

  if ($date eq 'month') { 
    return substr(date_to_string(time), 0, 8) . '..';
  }
  elsif ($date eq 'year')  { 
    return substr(date_to_string(time), 0, 5) . '..-..';
  }
  else  { 
    return translate_date($date);
  }
}

# Translate due date alias to YYYY-MM-DD string:
sub translate_date {
  my $date = shift;

  if    ($date =~ /^\d{4}-[01]\d-[0-3]\d$/) { return $date }
  elsif ($date eq 'anytime')   { return $date }
  elsif ($date eq 'today')     { return date_to_string(time) }
  elsif ($date eq 'yesterday') { return date_to_string(time - 86400) }
  elsif ($date eq 'tomorrow')  { return date_to_string(time + 86400) }
  elsif ($date eq 'month')     { return date_to_string(time + 2678400)  }
  elsif ($date eq 'year')      { return date_to_string(time + 31536000) }
  else  { exit_with_error("Invalid due date `$date'.", 22) }
}

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
}

# Display given message and immediately terminate the script:
sub exit_with_error {
  my $message = shift || 'An unspecified error has occurred.';
  my $retval  = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $retval;
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
);

# Detect superfluous options:
if (scalar(@ARGV) != 0) {
  exit_with_error("Invalid option `$ARGV[0]'.", 22);
}

# Trim group option:
if (my $value = $args{group}) {
  $args{group} = substr($value, 0, 10);
}

# Translate due date option:
if (my $value = $args{date}) {
  $args{date} = translate_mask($value)
}

# Check priority option:
if (my $value = $args{priority}) {
  unless ($value =~ /^[1-5]$/) {
    exit_with_error("Invalid priority `$value'.", 22);
  }
}

# Check line width option:
if ($Text::Wrap::columns < 75) {
  exit_with_error("Invalid line width `$Text::Wrap::columns'.", 22);
}

# Perform appropriate action:
write_tasks($outfile, \%args);

# Return success:
exit 0;
#!/usr/bin/env perl

# w2text -- a plain text exporter for w2do
# Copyright (C) 2008 Jaromir Hradilek

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
our $NAME      = basename($0, '.pl');              # Script name.
our $VERSION   = '2.0.4';                          # Script version.

# Global script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE};  # User's home directory.
our $savefile  = catfile($HOMEDIR, '.w2do');       # Save file location.

# Appearance settings:
$Text::Wrap::columns = 75;                         # Line width.

# Command line options:
my $outfile    = '-';                              # Output file name.
my %args       = ();                               # Specifying options.

# Signal handlers:
$SIG{__WARN__} = sub {
  exit_with_error((shift) . "Try `--help' for more information.", 22);
};

# Display script usage:
sub display_help {
  print << "END_HELP";
Usage: $NAME [-s file] [-o file] [-w width] [-t task] [-g group] [-d date]
              [-p priority] [-f|-u]
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
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008 Jaromir Hradilek
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

  load_selection(\@data, undef, $args);

  if (open(SAVEFILE, ">$outfile")) {
    if (@data) {
      my ($group, $task) = '';
      
      foreach my $line (sort @data) {
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        if ($1 ne $group) {
          print SAVEFILE "\n" if $group;
          print SAVEFILE "$1:\n\n";
          $group = $1;
        }

        $task = ($4 eq 't') ? "$5 (done)\n" : "$5\n";
        print SAVEFILE wrap('  * ', '    ', $task);
      }

      close(SAVEFILE);
    }
  }
  else {
    exit_with_error("Unable to write to `$outfile'.", 13);
  }
}

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $args) = @_;

  my $group    = $args->{group}    || '[^:]*';
  my $date     = $args->{date}     || '[^:]*';
  my $priority = $args->{priority} || '[1-5]';
  my $state    = $args->{state}    || '[ft]';
  my $task     = $args->{task}     || '.*';
  my $id       = $args->{id}       || '\d+';

  my $mask     = "^$group:$date:$priority:$state:$task:$id\$";

  if (open(SAVEFILE, "$savefile")) {
    while (my $line = <SAVEFILE>) {
      if ($line =~ /$mask/) {
        push(@$selected, $line);
      }
      else {
        push(@$rest, $line);
      }
    }

    close(SAVEFILE);
  }
  else {
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
  my $message = shift || 'An unspecified error has occured.';
  my $retval  = shift || 1;

  print STDERR "$NAME: $message\n";
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

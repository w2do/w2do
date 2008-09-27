#!/usr/bin/env perl

# w2html -- a HTML exporter for w2do
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
our $VERSION   = '2.1.0';                          # Script version.
our $HOMEPAGE  = 'http://code.google.com/p/w2do/'; # Project homepage.

# Global script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE} || '.';
our $TIMESTAMP = localtime(time);
our $savefile  = $ENV{W2DO_SAVEFILE} || catfile($HOMEDIR, '.w2do');
our $heading   = $ENV{USERNAME} ? "$ENV{USERNAME}'s task list"
                                : "current task list";

# Command line options:
my $outfile    = '-';                              # Output file name.
my $design     = 'blue';                           # Output design.
my %args       = ();                               # Specifying options.

# Signal handlers:
$SIG{__WARN__} = sub {
  exit_with_error((shift) . "Try `--help' for more information.", 22);
};

# Display script usage:
sub display_help {
  print << "END_HELP";
Usage: $NAME [-B|-D] [-H heading] [-o file] [-s file] [-f|-u] [-d date]
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
  -H, --heading text       use selected heading
  -B, --blue               produce page with blue design
  -D, --dark               produce page with dark design
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
  my $stats = {};
  my @data;

  # Load matching tasks:
  load_selection(\@data, undef, $args);

  # Get task list statistics:
  get_stats($stats);

  # Open the selected output for writing:
  if (open(SAVEFILE, ">$outfile")) {

    # Check whether the list is not empty:
    if (@data) {
      my $group = '';

      # Write header:
      print SAVEFILE header();

      # Process each task:
      foreach my $line (sort @data) {

        # Parse the task record:
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        # Write heading when group changes:
        if (lc($1) ne $group) {
          # Write group closing if opened:
          print SAVEFILE close_group() if $group;

          # Translate the group name to lower case:
          $group = lc($1);

          # Write group beginning:
          print SAVEFILE begin_group($1, $stats->{$group}->{tasks},
                                         $stats->{$group}->{done});
        }

        # Write task entry:
        print SAVEFILE group_item($2, $3, $4, $5);
      }

      # Write group closing:
      print SAVEFILE close_group();

      # Write footer:
      print SAVEFILE footer();

      # Close the outpt:
      close(SAVEFILE);
    }
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$outfile'.", 13);
  }
}

# Return the document header:
sub header {
  if ($design eq 'blue') {
    return << "END_BLUE";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="Generator" content="$NAME $VERSION">
  <meta name="Date" content="$TIMESTAMP">
  <title>$heading</title>
  <style type="text/css">
  <!--
    body {
      background-color: #4682b4;
      color: #000000;
      font-family: Arial, sans-serif;
      text-align: center;
      margin: 0px;
    }

    h2 {
      color: #225588;
      margin-bottom: 4px;
      text-align: left;
    }

    table {
      margin: auto;
    }

    th {
      background-color: #4682b4;
      color: #ffffff;
    }

    tr {
      background-color: #f5f5f5;
    }

    tr:hover {
      background-color: #dcdcdc;
    }

    a {
      color: #add8e6;
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    #header {
      text-align: center;
      width: 100%;
    }

    #middle {
      background-color: #ffffff;
      border-bottom: 4px solid #add8e6;
      border-top: 4px solid #add8e6;
      margin: 0px;
    }

    #content {
      margin: auto;
      padding: 0px 5px 20px 5px;
      width: 640px;
    }

    #footer {
      color: #ffffff;
      font-size: x-small;
      text-align: right;
      margin-bottom: 20px;
      width: 100%;
    }

    .hack {
      padding: 15px 5px 15px 5px;
      background-color: #4682b4;
    }

    .heading {
      color: #ffffff;
      font-size: xx-large;
      font-weight: bold;
    }

    .subheading {
      color: #ffffff;
      font-size: small;
      text-align: right;
    }

    .stats {
      color: #225588;
      font-size: x-small;
    }

    .tasks {
      width: 100%;
    }

    .date {
      width: 100px;
    }

    .priority {
      width: 100px;
    }

    .state {
      width: 50px;
    }

    .description {
      text-align: left;
    }

    .finished {
      background-color: #add8e6;
    }

    .finished:hover {
      background-color: #4682b4;
    }
  -->
  </style>
</head>

<body>

<div id="header">
  <table>
    <tr>
      <td class="hack">
        <div class="heading">$heading</div>
        <div class="subheading">$TIMESTAMP</div>
      </td>
    </tr>
  </table>
</div>

<div id="middle"><div id="content">
END_BLUE
  }
  else {
    return << "END_DARK";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="Generator" content="$NAME $VERSION">
  <meta name="Date" content="$TIMESTAMP">
  <title>$heading</title>
  <style type="text/css">
  <!--
    body {
      background-color: #000000;
      color: #ffffff;
      font-family: Arial, sans-serif;
      text-align: center;
    }

    h2 {
      color: #1e90ff;
      margin-bottom: 4px;
      text-align: left;
    }

    table {
      margin: auto;
    }

    th {
      background-color: #1d1d1d;
    }

    tr {
      background-color: #080808;
    }

    tr:hover {
      background-color: #1d1d1d;
    }

    a {
      color: #1e90ff;
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    #header {
      background-color: #000000;
      border-bottom: 4px solid #1d1d1d;
      margin: auto;
      padding: 15px 5px 15px 5px;
      text-align: center;
      width: 640px;
    }

    #content {
      background-color: #0f0f0f;
      border-bottom: 4px solid #1d1d1d;
      border-top: 1px solid #080808;
      margin: auto;
      padding: 0px 5px 20px 5px;
      width: 640px;
    }

    #footer {
      background-color: #000000;
      border-top: 1px solid #080808;
      color: #404040;
      font-size: x-small;
      margin: auto;
      padding: 0px 0px 0px 10px;
      text-align: right;
      width: 640px;
    }

    .hack {
      background-color: #000000;
    }

    .heading {
      color: #1e90ff;
      font-size: xx-large;
      font-weight: bold;
    }

    .subheading {
      color: #4682b4;
      font-size: small;
      text-align: right;
    }

    .stats {
      color: #4682b4;
      font-size: x-small;
    }

    .tasks {
      width: 100%;
    }

    .date {
      width: 100px;
    }

    .priority {
      width: 100px;
    }

    .state {
      width: 50px;
    }

    .description {
      text-align: left;
    }

    .finished {
      background-color: #303030;
    }

    .finished:hover {
      background-color: #404040;
    }
  -->
  </style>
</head>

<body>

<div id="header">
  <table>
    <tr>
      <td class="hack">
        <div class="heading">$heading</div>
        <div class="subheading">$TIMESTAMP</div>
      </td>
    </tr>
  </table>
</div>

<div id="content">
END_DARK
  }
}

# Return the document footer:
sub footer {
  if ($design eq 'blue') {
    return << "END_BLUE"
</div></div>

<div id="footer">
  generated using <a href="$HOMEPAGE">$NAME $VERSION</a>
</div>

</body>
</html>
END_BLUE
  }
  else {
    return << "END_DARK";
</div>

<div id="footer">
  generated using <a href="$HOMEPAGE">$NAME $VERSION</a>
</div>

</body>
</html>
END_DARK
  }
}

# Return the beginning of new group:
sub begin_group {
  my ($group, $tasks, $done) = @_;
  my $stats = sprintf "%d task%s, %d unfinished",
                      $tasks, (($tasks != 1) ? 's' : ''),
                      $tasks - $done;

  return << "END_BEGIN_GROUP";
<h2><a name="$group"></a>$group <span class="stats">$stats</span></h2>

<table class="tasks">
  <tr>
    <th class="date">due date</th>
    <th class="priority">priority</th>
    <th class="state">state</th>
    <th class="description">task</th>
  </tr>
END_BEGIN_GROUP
}

# Return the group closing:
sub close_group {
  return "</table>\n\n";
}

# Return the group item:
sub group_item {
  my ($date, $priority, $state, $task) = @_;
  my @priorities = ('very high', 'high', 'medium', 'low', 'very low');

  my $class = ($state eq 't') ? ' class="finished"' : '';
  $state    = ($state eq 't') ? 'ok' : '&nbsp;';
  $priority = $priorities[--$priority];

  return << "END_GROUP_ITEM";
  <tr$class>
    <td class="date">$date</td>
    <td class="priority">$priority</td>
    <td class="state">$state</td>
    <td class="description">$task</td>
  </tr>
END_GROUP_ITEM
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
        push(@$selected, $line);
      }
      else {
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

# Get task list statistics:
sub get_stats {
  my $stats  = shift;
  my $groups = 0;
  my $tasks  = 0;
  my $undone = 0;

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {

    # Process each line:
    while (my $line = <SAVEFILE>) {

      # Parse the task record:
      if ($line =~ /^([^:]*):[^:]*:[1-5]:([ft]):.*:\d+$/) {
        my $group = lc($1);

        # Count group statistics:
        if ($stats->{$group}) {
          $stats->{$group}->{tasks} += 1;
          $stats->{$group}->{done}  += ($2 eq 't') ? 1 : 0;
        }
        else {
          $stats->{$group}->{tasks}  = 1;
          $stats->{$group}->{done}   = ($2 eq 't') ? 1 : 0;
          $groups++;
        }

        # Count overall statistics:
        $tasks++;
        $undone++ unless ($2 eq 't');
      }
    }
  }

  # Return overall statistics:
  return $groups, $tasks, $undone;
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
  'savefile|s=s'   => sub { $savefile       = $_[1] },
  'output|o=s'     => sub { $outfile        = $_[1] },
  'heading|H=s'    => sub { $heading        = $_[1] },
  'dark|D'         => sub { $design         = 'dark' },
  'blue|B'         => sub { $design         = 'blue' },
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

# Perform appropriate action:
write_tasks($outfile, \%args);

# Return success:
exit 0;

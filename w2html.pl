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
our $VERSION   = '2.0.4';                          # Script version.

# Global script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE};  # User's home directory.
our $USERNAME  = $ENV{USERNAME} || 'user';         # User's name.
our $SAVENAME  = '.w2do';                          # Save file name.
our $savefile  = catfile($HOMEDIR, $SAVENAME);     # Save file location.
our $title     = "$USERNAME\'s TODO list";         # Document title.
our $subtitle  = full_date_to_string(time);        # Document subtitle.

# Appearance settings:
our $fg_colour = '#000000';                        # Foreground colour.
our $bg_colour = '#ffffff';                        # Background colour.
our $header_fg = '#000000';                        # Header foreground.
our $header_bg = '#ffd700';                        # Header background.
our $header_hl = '#ffd700';                        # Header highlight.
our $done_fg   = '#000000';                        # Finished foreground.
our $done_bg   = '#c9fcac';                        # Finished background.
our $done_hl   = '#a0eb75';                        # Finished highlight.
our $undone_fg = '#000000';                        # Unfinished foreground.
our $undone_bg = '#fafad2';                        # Unfinished background.
our $undone_hl = '#ffe4b5';                        # Unfinished highlight.

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
Usage: $NAME [-s file] [-o file] [-H text] [-S text] [-t task] [-g group]
              [-d date] [-p priority] [-f|-u]
       $NAME [options]

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

  -s, --savefile file      use selected file instead of default ~/$SAVENAME
  -o, --output file        use selected file instead of the standard output
  -H, --heading text       use selected heading
  -S, --subheading text    use selected subheading
  --fg  colour             document foreground colour
  --bg  colour             document background colour
  --fgh colour             header foreground colour
  --bgh colour             header background colour
  --hlh colour             header highlight colour
  --fgf colour             finished task foreground colour
  --bgf colour             finished task background colour
  --hlf colour             finished task highlight colour 
  --fgu colour             unfinished task foreground colour
  --bgu colour             unfinished task background colour
  --hlu colour             unfinished task highlight colour
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
      my $group = '';

      print SAVEFILE header();

      foreach my $line (sort @data) {
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        if ($1 ne $group) {
          print SAVEFILE close_group() if $group;
          print SAVEFILE begin_group($1);
          $group = $1;
        }

        print SAVEFILE group_item($2, $3, $4, $5);
      }

      print SAVEFILE close_group();
      print SAVEFILE footer();
      close(SAVEFILE);
    }
  }
  else {
    exit_with_error("Unable to write to `$outfile'.", 13);
  }
}

# Return the document header:
sub header {
  my $generated = localtime(time);
  return << "END_HEADER";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="Generator" content="$NAME $VERSION">
  <meta name="Date" content="$generated">
  <title>$title</title>
  <style type="text/css">
  <!--
    body {
      color:            $fg_colour;
      background-color: $bg_colour;
      text-align:       center;
      font-family:      Arial, sans-serif;
    }

    h1 {
      text-align:       center;
    }

    h2 {
      padding:          2px;
      border-bottom:    1px solid $fg_colour;
    }

    table {
      width:            100%;
    }

    th {
      color:            $header_fg;
      background-color: $header_bg;
    }

    th:hover {
      background-color: $header_hl;
    }

    tr {
      color:            $undone_fg;
      background-color: $undone_bg;
    }

    tr:hover {
      background-color: $undone_hl;
    }

    .finished {
      color:            $done_fg;
      background-color: $done_bg;
    }

    .finished:hover {
      background-color: $done_hl;
    }

    .page {
      margin:           0 auto;
      width:            740px;
      text-align:       justify;
    }

    .date {
      width:            100px;
      text-align:       center;
    }

    .priority {
      width:            100px;
      text-align:       center;
    }

    .state {
      width:            50px;
      text-align:       center;
    }

    .description {
      text-align:       justify;
    }

    .info {
      text-align:       center;
    }
  -->
  </style>
</head>

<body>
<div class="page">

<h1>$title</h1>
<p class="info">$subtitle</p>

END_HEADER
}

# Return the document footer:
sub footer {
  return << "END_FOOTER";
</div>
</body>
</html>
END_FOOTER
}

# Return the beginning of new group:
sub begin_group {
  my $group = shift;
  return << "END_BEGIN_GROUP";
<h2><a name="$group"></a>$group</h2>

<table>
  <tr>
    <th class="date">due date</th>
    <th class="priority">priority</th>
    <th class="state">state</th>
    <th class="description">description</th>
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

# Translate given date to the full date string, e.g. 31 July 2008:
sub full_date_to_string {
  my @date   = localtime(shift);
  my @months = qw(January February March April May June July August
                  September October November December);
  return sprintf("%d %s %d", $date[3], $months[$date[4]], ($date[5]+1900));
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
  'heading|H=s'    => sub { $title          = $_[1] },
  'subheading|S=s' => sub { $subtitle       = $_[1] },
  'fg=s'           => sub { $fg_colour      = $_[1] },
  'bg=s'           => sub { $bg_colour      = $_[1] },
  'fgh=s'          => sub { $header_fg      = $_[1] },
  'bgh=s'          => sub { $header_bg      = $_[1] },
  'hlh=s'          => sub { $header_hl      = $_[1] },
  'fgf=s'          => sub { $done_fg        = $_[1] },
  'bgf=s'          => sub { $done_bg        = $_[1] },
  'hlf=s'          => sub { $done_hl        = $_[1] },
  'fgu=s'          => sub { $undone_fg      = $_[1] },
  'bgu=s'          => sub { $undone_bg      = $_[1] },
  'hlu=s'          => sub { $undone_hl      = $_[1] },
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

# Perform appropriate action:
write_tasks($outfile, \%args);

# Return success:
exit 0;

#!/usr/bin/env perl

# w2html, a HTML exporter for w2do
# Copyright (C) 2008, 2009, 2010 Jaromir Hradilek

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
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');       # Script name.
use constant VERSION => '2.3.1';                   # Script version.

# General script settings:
our $HOMEDIR         = $ENV{HOME}          || $ENV{USERPROFILE} || '.';
our $savefile        = $ENV{W2DO_SAVEFILE} || catfile($HOMEDIR, '.w2do');
our $heading         = $ENV{USERNAME}      ? "$ENV{USERNAME}'s task list"
                                           : "current task list";
our $encoding        = 'UTF-8';                    # Save file encoding.
our $outfile         = '-';                        # Output file name.
our $with_id         = 1;                          # Include ID?
our $with_date       = 1;                          # Include due date?
our $with_pri        = 1;                          # Include priority?
our $with_state      = 1;                          # Include state?
our $with_stats      = 0;                          # Include statistics?
our $preserve        = 0;                          # Preserve style sheet?
our $inline          = 0;                          # Embed the style sheet?
our $bare            = 0;                          # Leave out the HTML
                                                   # header and footer?
# Other command-line options:
my  %args            = ();                         # Specifying options.

# The document structure related part of the default style sheet:
our $css_structure   = << "END_CSS_STRUCTURE";
body {
  margin: 0px 0px 10px 0px;
  padding: 0px;
  color: #000000;
  background-color: #e7e7e7;
  font-family: "DejaVu Sans", Arial, sans;
  font-size: small;
}

#wrapper {
  margin: auto;
  padding: 0px;
  width: 768px;
  border-left: 1px solid #d6d6d6;
  border-right: 1px solid #d6d6d6;
  border-bottom: 1px solid #d6d6d6;
  background-color: #ffffff;
}

#heading {
  margin: auto;
  padding: 20px;
  width: 728px;
  background-color: #2e2e2e;
  border-bottom: 2px solid #2a2a2a;
  border-top: 2px solid #323232;
  color: #d0d0d0;
}

#heading a, #heading h1 {
  margin: 0px;
  text-decoration: none;
  color: #ffffff;
}

#heading a:hover {
  text-decoration: underline;
}

#content {
  margin: 0px;
  padding: 10px 20px 20px 20px;
  width: 728px;
  text-align: justify;
  border-top: 2px solid #e7e7e7;
  border-bottom: 2px solid #e7e7e7;
}

#footer {
  margin: 0px;
  padding: 10px 20px 10px 20px;
  width: 728px;
  border-top: 1px solid #5f5f5f;
  border-bottom: 1px solid #3d3d3d;
  background-color: #4e4e4e;
  text-align: right;
  font-size: x-small;
  color: #d0d0d0;
}

#footer a {
  color: #ffffff;
  text-decoration: none;
}

#footer a:hover {
  text-decoration: underline;
}

END_CSS_STRUCTURE

# The tasks related part of the default style sheet:
our $css_tasks       = << "END_CSS_TASKS";
h2.todo_group {
  margin-bottom: 0.3em;
}

h2.todo_group a {
  text-decoration: none;
  color: #9acd32;
}

h2.todo_group a:hover {
  text-decoration: underline;
}

h2 .todo_stats {
  font-size: x-small;
  font-weight: normal;
  color: #4e9a06;
}

table.todo_tasks {
  width: 100%;
  margin: auto;
}

table.todo_tasks th {
  background-color: #4e4e4e;
  color: #ffffff;
}

table.todo_tasks tr {
  background-color: #f5f5f5;
}

table.todo_tasks tr:hover {
  background-color: #dcdcdc;
}

table.todo_tasks .todo_id {
  width: 50px;
  text-align: center;
}

table.todo_tasks .todo_date {
  width: 100px;
  text-align: center;
}

table.todo_tasks .todo_priority {
  width: 100px;
  text-align: center;
}

table.todo_tasks .todo_state {
  width: 50px;
  text-align: center;
}

table.todo_tasks .todo_description {
  padding-left: 4px;
  padding-right: 4px;
  text-align: left;
}

table.todo_tasks .todo_finished {
  background-color: #98fb98;
}

table.todo_tasks .todo_finished:hover {
  background-color: #00ff7f;
}

table.todo_stats {
  width: 100%;
  margin: auto;
}

table.todo_stats tr:hover {
  background-color: #f5f5f5;
}

table.todo_stats .todo_group {
  width: 20%;
  text-align: left;
}

table.todo_stats .todo_progress {
  width: 80%;
  text-align: left;
  font-size: x-small;
}

table.todo_stats div.todo_greenbar {
  margin: 0 5px 0 0;
  float: left;
  display: block;
  background-color: #98fb98;
}

table.todo_stats div.todo_greenbar:hover {
  background-color: #00ff7f;
}

table.todo_stats div.todo_bluebar {
  margin: 0 5px 0 0;
  float: left;
  display: block;
  background-color: #729fcf;
}

table.todo_stats div.todo_bluebar:hover {
  background-color: #3465a4;
}
END_CSS_TASKS

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

# Get task list statistics:
sub get_stats {
  my $stats  = shift || die 'Missing argument';

  # Initialize required variables:
  my ($groups, $tasks, $undone) = (0, 0, 0);

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Process each line:
    while (my $line = <SAVEFILE>) {
      # Parse the task record:
      if ($line =~ /^([^:]*):[^:]*:[1-5]:([ft]):.*:\d+$/) {
        my $group = lc($1);

        # Count group statistics:
        if ($stats->{$group}) {
          # Increment counters:
          $stats->{$group}->{tasks} += 1;
          $stats->{$group}->{done}  += ($2 eq 't') ? 1 : 0;
        }
        else {
          # Initialize counters:
          $stats->{$group}->{tasks}  = 1;
          $stats->{$group}->{done}   = ($2 eq 't') ? 1 : 0;

          # Increment number of counted groups:
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

# Create a style sheet file and return the LINK element:
sub write_style_sheet {
  # Do not create the style sheet when writing to STDOUT:
  return 0 if $outfile eq '-';

  # Derive the style sheet file name:
  (my $file = $outfile) =~ s/(\.html?|\.php|)$/.css/;

  # Do not rewrite existing style sheet if its preservation is requested:
  unless (-e $file && $preserve) {
    # Open the file for writing:
    if (open(STYLE, ">$file")) {
      # Write the document structure related part:
      print STYLE $css_structure unless $bare;

      # Write the tasks related part:
      print STYLE $css_tasks;

      # Close the file:
      close(STYLE);
    }
    else {
      # Report failure:
      print STDERR "Unable to write to `$file'.\n";

      # Return failure:
      return 0;
    }
  }

  # Return the LINK element:
  return "<link rel=\"stylesheet\" href=\"" . basename($file) .
         "\" type=\"text/css\">\n";
}

# Return the style sheet or a LINK element pointing to it:
sub compose_style_sheet {
  # Check whether to have style sheet as a separate file:
  unless ($inline) {
    # Return the LINK element:
    return write_style_sheet();
  }
  else {
    # Return the style sheet:
    return << "END_STYLE_SHEET";
<style type="text/css"><!--
$css_structure$css_tasks  --></style>
END_STYLE_SHEET
  }
}

# Return the HTML header:
sub compose_html_header {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Initialize required variables:
  my $style_sheet      = compose_style_sheet() || "\n";
  my $timestamp        = localtime(time);

  # Return the HTML document beginning:
  return << "END_HTML_HEADER";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=$encoding">
  <meta name="Generator" content="$NAME $VERSION">
  <meta name="Date" content="$timestamp">
  $style_sheet  <title>$heading</title>
</head>

<body>

<div id="wrapper">

<div id="heading">
  <table>
    <tr>
      <td>
        <h1><a href="#">$heading</a></h1>
        $timestamp
      </td>
    </tr>
  </table>
</div>

<div id="content">

END_HTML_HEADER
}

# Return the HTML footer:
sub compose_html_footer {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Return the HTML document closing:
  return << "END_HTML_FOOTER";
</div>

<div id="footer">
  Generated using <a href="http://w2do.blackened.cz/">$NAME $VERSION</a>.
</div>

</div>

</body>
</html>
END_HTML_FOOTER
}

# Return the group header:
sub compose_group_header {
  my ($group, $tasks, $done) = @_;

  # Prepare the group statistics:
  my $stats = sprintf "%d task%s, %d unfinished",
                      $tasks, (($tasks != 1) ? 's' : ''),
                      $tasks - $done;

  # Prepare the table header columns:
  my $cols = '';
  $cols .= "    <th class=\"todo_id\">id</th>\n" if $with_id;
  $cols .= "    <th class=\"todo_date\">due date</th>\n" if $with_date;
  $cols .= "    <th class=\"todo_priority\">priority</th>\n" if $with_pri;
  $cols .= "    <th class=\"todo_state\">state</th>\n" if $with_state;
  $cols .= "    <th class=\"todo_description\">task</th>";

  # Return the group heading and the table header:
  return << "END_GROUP_HEADER";
<h2 class="todo_group">
  <a name="$group">$group</a>
  <span class="todo_stats">$stats</span>
</h2>

<table class="todo_tasks">
  <tr>
$cols
  </tr>
END_GROUP_HEADER
}

# Return the group footer:
sub compose_group_footer {
  # Return the table closing:
  return "</table>\n\n";
}

# Return the task entry:
sub compose_task_entry {
  my ($id, $date, $priority, $state, $task) = @_;

  # Decide which class the task belongs to:
  my $class      = ($state eq 't') ? ' class="todo_finished"' : '';

  # Prepare the aliases:
  my @priorities = ('very high', 'high', 'medium', 'low', 'very low');
  $state         = ($state eq 't') ? 'ok' : '&nbsp;';
  $priority      = $priorities[--$priority];

  # Escape reserved characters:
  $task =~ s/&/&amp;/g;
  $task =~ s/</&lt;/g;
  $task =~ s/>/&gt;/g;

  # Prepare the table columns:
  my $cols = '';
  $cols .= "    <td class=\"todo_id\">$id</td>\n" if $with_id;
  $cols .= "    <td class=\"todo_date\">$date</td>\n" if $with_date;
  $cols .= "    <td class=\"todo_priority\">$priority</td>\n" if $with_pri;
  $cols .= "    <td class=\"todo_state\">$state</td>\n" if $with_state;
  $cols .= "    <td class=\"todo_description\">$task</td>";

  # Return the task entry:
  return << "END_TASK_ENTRY";
  <tr$class>
$cols
  </tr>
END_TASK_ENTRY
}

# Return the statistics header:
sub compose_statistics_header {
  my ($groups, $tasks, $undone) = @_;

  # Prepare the overall statistics:
  my $stats = sprintf "%d group%s, %d task%s, %d unfinished",
                      $groups, (($groups != 1) ? 's' : ''),
                      $tasks,  (($tasks  != 1) ? 's' : ''),
                      $undone;
  # Return the statistics heading and the table header:
  return << "END_STATISTICS_HEADER";
<h2 class="todo_group">
  <a name="statistics">Overall Statistics</a>
  <span class="todo_stats">$stats</span>
</h2>

<table class="todo_stats">
END_STATISTICS_HEADER
}

# Return the statistics footer:
sub compose_statistics_footer {
  # Return the table closing:
  return "</table>\n\n";
}

# Return the group statistics entry:
sub compose_statistics_entry {
  my ($group, $percentage, $done, $tasks, $total) = @_;

  # Count the progress bar width:
  my $width = $percentage ? $percentage * 2 : 1;

  # Decide which class to use:
  my $class = $total ? 'todo_bluebar' : 'todo_greenbar';

  # Return the statistics entry:
  return << "END_STATISTICS_ENTRY";
  <tr>
    <td class="todo_group">$group</td>
    <td class="todo_progress">
      <div class="$class" style="width: ${width}px;">&nbsp;</div>
      <span title="$done from $tasks">$percentage&nbsp;%</span>
    </td>
  </tr>
END_STATISTICS_ENTRY
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message:
  print << "END_HELP";
Usage: $NAME [-bikDIPS] [-H heading] [-e encoding] [-o file] [-s file]
              [-f|-u] [-d date] [-g group] [-p priority] [-t task]
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

  -H, --heading text       use selected document heading
  -e, --encoding encoding  use selected file encoding
  -s, --savefile file      use selected file instead of the default ~/.w2do
  -o, --output file        use selected file instead of the standard output
  -k, --preserve           do not touch existing style sheet if present
  -b, --bare               leave out the HTML header and footer
  -i, --inline             embed the style sheet
  -I, --no-id              do not include ID column
  -D, --no-date            do not include due date column
  -P, --no-priority        do not include priority column
  -S, --no-state           do not include state column
  --with-stats, --stats    include overall task list statistics
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

Copyright (C) 2008, 2009, 2010 Jaromir Hradilek
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
  my $args  = shift || die 'Missing argument';

  # Initialize required variables:
  my $stats = {};
  my @data;

  # Get task list statistics:
  my ($groups, $tasks, $undone) = get_stats($stats);
  my  $done = $tasks - $undone;

  # Load matching tasks:
  load_selection(\@data, undef, $args);

  # Open the selected output for writing:
  if (open(FILE, ">$outfile")) {
    # Write header:
    print(FILE compose_html_header()) or return 0 unless $bare;

    # Check whether the list is not empty:
    if (@data) {
      my $group = '';

      # Process each task:
      foreach my $line (sort @data) {
        # Parse the task record:
        $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

        # Write heading when group changes:
        if (lc($1) ne $group) {
          # Write group closing if opened:
          print FILE compose_group_footer() if $group;

          # Translate the group name to lower case:
          $group = lc($1);

          # Write group beginning:
          print FILE compose_group_header($1, $stats->{$group}->{tasks},
                                              $stats->{$group}->{done});
        }

        # Write task entry:
        print FILE compose_task_entry($6, $2, $3, $4, $5);
      }

      # Write group closing:
      print FILE compose_group_footer();
    }
    else {
      # Report an empty list:
      print FILE "<p>No matching task found.</p>\n\n";
    }

    # Check whether to include overall statistics:
    if ($groups && $with_stats) {
      # Write statistics beginning:
      print FILE compose_statistics_header($groups, $tasks, $undone);

      # Process each group:
      foreach my $group (sort (keys %$stats)) {
        # Get the group statistics:
        my $group_done = $stats->{$group}->{done};
        my $group_all  = $stats->{$group}->{tasks};

        # Count the percentage:
        my $percentage = int($group_done * 100 / $group_all);

        # Write the group progress entry:
        print FILE compose_statistics_entry($group, $percentage,
                                            $group_done, $group_all);
      }

      # Count the overall percentage:
      my $percentage = $tasks ? int($done * 100 / $tasks) : 0;

      # Write the overall progress entry:
      print FILE compose_statistics_entry('total', $percentage, $done,
                                          $tasks, 1);

      # Write statistics closing:
      print FILE compose_statistics_footer();
    }

    # Write footer:
    print FILE compose_html_footer() unless $bare;

    # Close the outpt:
    close(FILE);
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
  'help|h'                => sub { display_help();    exit 0 },
  'version|v'             => sub { display_version(); exit 0 },

  # Specifying options:
  'task|t=s'              => sub { $args{task}     = $_[1] },
  'group|g=s'             => sub { $args{group}    = $_[1] },
  'date|d=s'              => sub { $args{date}     = $_[1] },
  'priority|p=i'          => sub { $args{priority} = $_[1] },
  'finished|f'            => sub { $args{state}    = 't' },
  'unfinished|u'          => sub { $args{state}    = 'f' },

  # Additional options:
  'savefile|s=s'          => sub { $savefile       = $_[1] },
  'output|o=s'            => sub { $outfile        = $_[1] },
  'encoding|e=s'          => sub { $encoding       = $_[1] },
  'heading|H=s'           => sub { $heading        = $_[1] },
  'preserve|k'            => sub { $preserve       = 1 },
  'inline|i'              => sub { $inline         = 1 },
  'no-bare|B'             => sub { $bare           = 0 },
  'bare|b'                => sub { $bare           = 1 },
  'no-id|I'               => sub { $with_id        = 0 },
  'with-id'               => sub { $with_id        = 1 },
  'no-date|D'             => sub { $with_date      = 0 },
  'with-date'             => sub { $with_date      = 1 },
  'no-priority|P'         => sub { $with_pri       = 0 },
  'with-priority'         => sub { $with_pri       = 1 },
  'no-state|S'            => sub { $with_state     = 0 },
  'with-state'            => sub { $with_state     = 1 },
  'no-stats|no-stat'      => sub { $with_stats     = 0 },
  'stats|stat|with-stats' => sub { $with_stats     = 1 },
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

# Force embedded style sheet when writing to STDOUT:
if ($outfile eq '-') {
  $inline = 1;
}

# Write the HTML file:
write_tasks(\%args) or exit 1;

# Write the CSS file:
write_style_sheet() or exit 1 if ($bare && !$inline);

# Return success:
exit 0;

__END__

=head1 NAME

w2html - a HTML exporter for w2do

=head1 SYNOPSIS

B<w2html> [B<-bikDIPS>] [B<-H> I<heading>] [B<-e> I<encoding>] [B<-o>
I<file>] [B<-s> I<file>] [B<-f>|B<-u>] [B<-d> I<date>] [B<-g> I<group>]
[B<-p> I<priority>] [B<-t> I<task>]

B<w2html> B<-h> | B<-v>

=head1 DESCRIPTION

B<w2html> is a HTML exporter for w2do, a simple to use yet efficient
command-line todo manager written in Perl. All tasks are listed by default,
but desired subset can be easily selected via specifying options.

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

=item B<-H> I<heading>, B<--heading> I<heading>

Use selected I<heading>.

=item B<-e> I<encoding>, B<--encoding> I<encoding>

Specify the file I<encoding> in a form recognised by the W3C HTML 4.01
standard (e.g. the default UTF-8).

=item B<-o> I<file>, B<--output> I<file>

Use selected I<file> instead of the standard output.

=item B<-s> I<file>, B<--savefile> I<file>

Use selected I<file> instead of the default C<~/.w2do> as a save file.

=item B<-k>, B<--preserve>

Do not rewrite existing style sheet if present (e.g. because it contains
some local changes).

=item B<-b>, B<--bare>

Leave out the HTML header and footer. This is especially useful when you
are planning to embed the list to another page.

=item B<-B>, B<--no-bare>

Include HTML header and footer; the default option.

=item B<-i>, B<--inline>

Embed the style sheet to the page itself instead of creating a separate CSS
file. Note that combining this option with C<-b> results in no style sheet
at all.

=item B<-I>, B<--no-id>

Do not include ID column in the listing.

=item B<--with-id>

Include ID column in the listing; the default option.

=item B<-D>, B<--no-date>

Do not include due date column in the listing.

=item B<--with-date>

Include due date column in the listing; the default option.

=item B<-P>, B<--no-priority>

Do not include priority column in the listing.

=item B<--with-priority>

Include priority column in the listing; the default option.

=item B<-S>, B<--no-state>

Do not include state column in the listing.

=item B<--with-state>

Include state column in the listing; the default option.

=item B<--with-stats>, B<--stats>

Include overall task list statistics.

=item B<--no-stats>

Do not include overall task list statistics; the default option.

=back

=head1 ENVIRONMENT

=over

=item B<W2DO_SAVEFILE>

Use selected file instead of the default C<~/.w2do> as a save file.

=back

=head1 FILES

=over

=item I<~/.w2do>

Default save file.

=back

=head1 SEE ALSO

B<w2do>(1), B<w2text>(1), B<perl>(1).

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

Copyright (C) 2008, 2009, 2010 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

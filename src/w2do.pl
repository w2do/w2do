#!/usr/bin/env perl

# w2do, a simple text-based todo manager
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
use File::Copy;
use File::Basename;
use File::Spec::Functions;
use Term::ANSIColor;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');       # Script name.
use constant VERSION => '2.1.1';                   # Script version.

# Global script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE} || '.';
our $savefile  = $ENV{W2DO_SAVEFILE} || catfile($HOMEDIR, '.w2do');
our $backext   = '.bak';                           # Backup file extension.
our $coloured  = 0;                                # Colour output setup.
our $verbose   = 1;                                # Verbosity level.
our $headcol   = 'bold white on_green';            # Table header colour.
our $donecol   = 'green';                          # Done task colour.
our $todaycol  = 'bold';                           # Today's task colour.
$Text::Wrap::columns = $ENV{W2DO_WIDTH} || 75;     # Default table width.

# Command line options:
my $identifier = undef;                            # Task identifier.
my $action     = 0;                                # Default action.
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
Usage: $NAME [-l] [-t task] [-g group] [-d date] [-p priority] [-f|-u]
       $NAME -a task [-g group] [-d date] [-p priority] [-f|-u]
       $NAME -c id [-t task] [-g group] [-d date] [-p priority] [-f|-u]
       $NAME -r id
       $NAME [options]

General options:

  -l, --list               display items in the task list
  -a, --add task           add new item to the task list
  -c, --change id          change selected item in the task list
  -r, --remove id          remove selected item from the task list

  --change-group group     change all items in the selected group
  --remove-group group     remove all items from the selected group
  --purge-group group      remove all finished items in the selected group

  --change-date date       change all items with selected due date
  --remove-date date       remove all items with selected due date
  --purge-date date        remove all finished items with selected due date

  --change-old             change all items with passed due date
  --remove-old             remove all items with passed due date
  --purge-old              remove all finished items with passed due date

  --change-all             change all items in the task list
  --remove-all             remove all items from the task list
  --purge-all              remove all finished items from the task list

  -U, --undo               revert last action
  -G, --groups             display all groups in the task list
  -S, --stats              display detailed task list statistics
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
  -w, --width width        use selected line width; the minimal value is 75
  -q, --quiet              avoid displaying messages that are not necessary
  -C, --colour             use coloured output instead of the default plain
                           text version
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

# Display all groups in the task list:
sub display_groups {
  my $stats = {};

  # Get task list statistics:
  get_stats($stats);

  # Check whether the list is not empty:
  if (%$stats) {
    # Display the list of groups:
    print join(', ', map { "$_ (" . $stats->{$_}->{done}  . '/'
                                  . $stats->{$_}->{tasks} . ')' }
                     sort keys(%$stats)),
          "\n";
  }
  else {
    # Report empty list:
    print "The task list is empty.\n" if $verbose;
  }
}

# Display detailed task list statistics:
sub display_statistics {
  my $stats = {};
  my $per;

  # Get task list statistics:
  my ($groups, $tasks, $undone) = get_stats($stats);

  # Display overall statistics:
  printf "%d group%s, %d task%s, %d unfinished\n\n",
         $groups, (($groups != 1) ? 's' : ''),
         $tasks,  (($tasks  != 1) ? 's' : ''),
         $undone;

  # Process each group:
  foreach my $group (sort (keys %$stats)) {
    # Count group percentage:
    $per = int($stats->{$group}->{done} * 100 / $stats->{$group}->{tasks});

    # Display group progress:
    printf "%-11s %s %d%%\n", "$group:", draw_progressbar($per), $per;
  }

  # Count overall percentage:
  $per = $tasks ? int(($tasks - $undone) * 100 / $tasks) : 0;

  # Display overall progress:
  printf "---\n%-11s %s %d%%\n", "total:", draw_progressbar($per), $per;
}

# Display items in the task list:
sub display_tasks {
  my $args = shift;
  my @data;

  # Load matching tasks:
  load_selection(\@data, undef, $args);

  # Check whether the list is not empty:
  if (@data) {
    my $current = '';
    my ($id, $group, $date, $priority, $state, $task);

    # Prepare the table layout:
    my $format  = " %-4s  %-10s  %-10s   %s    %s   %s\n";
    my $caption = " id    group       date        pri  sta  task" .
                  ' 'x ($Text::Wrap::columns - 45) . "\n";
    my $divider = '-'x  $Text::Wrap::columns . "\n";
    my $border  = '='x  $Text::Wrap::columns . "\n";
    my $indent  = ' 'x  41;

    # Set up the line wrapper:
    $Text::Wrap::columns++;

    # Display table header:
    $coloured ? print colored ($caption, $headcol)
              : print $border, $caption, $border;

    # Process each task:
    foreach my $line (sort @data) {
      # Parse the task record:
      $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

      # Check whether the group has changed:
      if (lc($1) ne $current) {
        # Display the divider unless the first group is being listed:
        if ($group) {
          $coloured ? print colored ($caption, $headcol) : print $divider;
        }

        # Remember the current group:
        $current = lc($1);
      }

      # If possible, use relative date reference:
      if ($2 eq date_to_string(time)) { $date = 'today'; }
      elsif ($2 eq date_to_string(time - 86400)) { $date = 'yesterday'; }
      elsif ($2 eq date_to_string(time + 86400)) { $date = 'tomorrow';  }
      else { $date = $2; }

      # Prepare the rest of the task entry:
      $id       = $6;
      $group    = $1;
      $priority = $3;
      $state    = ($4 eq 'f') ? '-' : 'f';
      $task     =  wrap($indent, $indent, $5); $task =~ s/\s+//;

      # Set up colours:
      print color $donecol  if $coloured && $state eq 'f';
      print color $todaycol if $coloured && $state ne 'f'
                                         && $date  eq 'today';

      # Display the task entry:
      printf($format, $id, $group, $date, $priority, $state, $task);

      # Reset colours:
      print color 'reset'   if $coloured;
    }
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }
}

# Add new item to the task list:
sub add_task {
  my $args     = shift;

  # Use default value when none is provided:
  my $group    = $args->{group}    || 'general';
  my $date     = $args->{date}     || 'anytime';
  my $priority = $args->{priority} || '3';
  my $state    = $args->{state}    || 'f';
  my $task     = $args->{task}     || '';
  my $id       = choose_id();

  # Create the task record:
  my @data     = ("$group:$date:$priority:$state:$task:$id\n"); 

  # Add data to the end of the save file:
  add_data(\@data);

  # Report success:
  print "Task has been successfully added with id $id.\n" if $verbose;
}

# Change selected item in the task list:
sub change_task {
  my (@selected, @data);

  # Load selected task:
  load_selection(\@selected, \@data, { id => shift });

  # Change selected item:
  change_selection(\@selected, \@data, shift);
}

# Remove selected item from the task list:
sub remove_task {
  my (@selected, @data);

  # Load selected task:
  load_selection(\@selected, \@data, { id => shift });

  # Remove selected item:
  remove_selection(\@selected, \@data);
}

# Change all items in the selected group:
sub change_group {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift });

  # Change selected items:
  change_selection(\@selected, \@data, shift);
}

# Remove all items in the selected group:
sub remove_group {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift });

  # Remove selected items:
  remove_selection(\@selected, \@data);
}

# Remove all finished items in the selected group:
sub purge_group {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift });

  # Purge selected items:
  purge_selection(\@selected, \@data);
}

# Change all items with selected due date:
sub change_date {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift });

  # Change selected items:
  change_selection(\@selected, \@data, shift);
}

# Remove all items with the selected due date:
sub remove_date {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift });

  # Remove selected items:
  remove_selection(\@selected, \@data);
}

# Remove all finished items with selected due date:
sub purge_date {
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift });

  # Purge selected items:
  purge_selection(\@selected, \@data);
}

# Change all items with passed due date:
sub change_old {
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data);

  # Change selected items:
  change_selection(\@selected, \@data, shift);
}

# Remove all items with passed due date:
sub remove_old {
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data);

  # Change selected items:
  remove_selection(\@selected, \@data);
}

# Purge all items with passed due date:
sub purge_old {
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data);

  # Purge selected tasks:
  purge_selection(\@selected, \@data);
}

# Change all items in the task list:
sub change_all {
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data);

  # Change all items:
  change_selection(\@selected, \@data, shift);
}

# Remove all items from the task list:
sub remove_all {
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data);

  # Remove all items:
  remove_selection(\@selected, \@data);
}

# Remove all finished items from the task list:
sub purge_all {
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data);

  # Purge all tasks:
  purge_selection(\@selected, \@data);
}

# Revert last action:
sub revert_last_action {
  # Try to restore data from the backup file:
  if (move("$savefile$backext", $savefile)) {
    # Report success:
    print "Last action has been successfully reverted.\n" if $verbose;
  }
  else {
    # If not present, we are probably at oldest change:
    print "Already at oldest change.\n" if $verbose;
  }
}

# Change selected items in the task list:
sub change_selection {
  my ($selected, $data, $args) = @_;

  # Check whether the selection is not empty:
  if (@$selected) {
    # Check whether the changed item is suplied:
    if (%$args) {
      # Process each item:
      foreach my $item (@$selected) {
        # Parse the task record:
        if ($item =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/) {
          # Use existing value when none is supplied:
          my $group    = $args->{group}    || $1;
          my $date     = $args->{date}     || $2;
          my $priority = $args->{priority} || $3;
          my $state    = $args->{state}    || $4;
          my $task     = $args->{task}     || $5;
          my $id       = $6;

          # Update the task record:
          push(@$data, "$group:$date:$priority:$state:$task:$id\n");
        }
      }
      
      # Store data to the save file:
      save_data($data);

      # Report success:
      print "Selected tasks have been successfully changed.\n" if $verbose;
    }
    else {
      # Report missing option:
      print "You have to specify what to change.\n" if $verbose;
    }
  }
  else {
    # Report empty selection:
    print "No matching task found.\n" if $verbose;
  }
}

# Remove selected items from the task list:
sub remove_selection {
  my ($selected, $data) = @_;

  # Check whether the selection is not empty:
  if (@$selected) {
    # Store data to the save file:
    save_data($data);

    # Report success:
    print "Selected tasks have been successfully removed.\n" if $verbose;
  }
  else {
    # Report empty selection:
    print "No matching task found.\n" if $verbose;
  }
}

# Remove all finished items in the selection:
sub purge_selection {
  my ($selected, $data) = @_;

  # Check whether the selection is not empty:
  if (@$selected) {
    # Process each item:
    foreach my $item (@$selected) {
      # Add unfinished tasks back to the list:
      if ($item =~ /^[^:]*:[^:]*:[1-5]:f:.*:\d+$/) {
        push(@$data, $item);
      }
    }

    # Store data to the save file:
    save_data($data);

    # Report success:
    print "Selected tasks have been successfully purged.\n" if $verbose;
  }
  else {
    # Report empty selection:
    print "No matching task found.\n" if $verbose;
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
}

# Load data with passed due date from the save file:
sub load_old {
  my ($selected, $rest) = @_;

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Process each line:
    while (my $line = <SAVEFILE>) {
      # Parse the task record:
      $line =~ /^[^:]*:([^:]*):[1-5]:[ft]:.*:\d+$/;

      # Check whether the line matches given pattern:
      if ("$1" lt date_to_string(time) && "$1" ne 'anytime') {
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
}

# Save data to the save file:
sub save_data {
  my $data = shift;

  # Backup the save file:
  copy($savefile, "$savefile$backext") if (-r $savefile);

  # Open the save file for writing:
  if (open(SAVEFILE, ">$savefile")) {
    # Process each item:
    foreach my $item (@$data) {
      # Write data to the save file:
      print SAVEFILE $item;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$savefile'.", 13);
  }
}

# Add data to the end of the save file:
sub add_data {
  my $data = shift;

  # Backup the save file:
  copy($savefile, "$savefile$backext") if (-r $savefile);

  # Open the save file for appending:
  if (open(SAVEFILE, ">>$savefile")) {
    # Process each item:
    foreach my $item (@$data) {
      # Write data to the save file:
      print SAVEFILE $item;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$savefile'.", 13);
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

# Choose first available ID:
sub choose_id {
  my @used   = ();
  my $chosen = 1;

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Build the list of used IDs:
    while (my $line = <SAVEFILE>) {
      push(@used, int($1)) if ($line =~ /:(\d+)$/);
    }

    # Close the save file:
    close(SAVEFILE);

    # Find first unused ID:
    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }
  }

  # Return the result:
  return $chosen;
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

# Draw progress bar:
sub draw_progressbar {
  my $percent = shift;
  my $pointer = ($percent > 0 && $percent < 100) ? '>' : '';
  return '[' . '=' x int($percent/10) . $pointer .
         ' ' x ($percent ? (9 - int($percent/10)) : 10) . ']';
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
  # Specifying options:
  'task|t=s'       => sub { $args{task}     = $_[1] },
  'group|g=s'      => sub { $args{group}    = $_[1] },
  'date|d=s'       => sub { $args{date}     = $_[1] },
  'priority|p=i'   => sub { $args{priority} = $_[1] },
  'finished|f'     => sub { $args{state}    = 't' },
  'unfinished|u'   => sub { $args{state}    = 'f' },

  # Additional options:
  'quiet|q'        => sub { $verbose             = 0 },
  'verbose|V'      => sub { $verbose             = 1 },
  'plain|P'        => sub { $coloured            = 0 },
  'colour|color|C' => sub { $coloured            = 1 },
  'savefile|s=s'   => sub { $savefile            = $_[1] },
  'width|w=i'      => sub { $Text::Wrap::columns = $_[1] },

  # General options:
  'list|l'         => sub { $action = 0 },
  'add|a=s'        => sub { $action = 1;  $args{task} = $_[1] },
  'change|c=i'     => sub { $action = 2;  $identifier = $_[1] },
  'remove|r=i'     => sub { $action = 3;  $identifier = $_[1] },

  'change-group=s' => sub { $action = 12; $identifier = $_[1] },
  'remove-group=s' => sub { $action = 13; $identifier = $_[1] },
  'purge-group=s'  => sub { $action = 14; $identifier = $_[1] },

  'change-date=s'  => sub { $action = 22; $identifier = $_[1] },
  'remove-date=s'  => sub { $action = 23; $identifier = $_[1] },
  'purge-date=s'   => sub { $action = 24; $identifier = $_[1] },

  'change-old'     => sub { $action = 32 },
  'remove-old'     => sub { $action = 33 },
  'purge-old'      => sub { $action = 34 },

  'change-all'     => sub { $action = 42 },
  'remove-all'     => sub { $action = 43 },
  'purge-all'      => sub { $action = 44 },

  'undo|U'         => sub { $action = 95 },
  'groups|G'       => sub { $action = 96 },
  'stats|S'        => sub { $action = 97 },

  'help|h'         => sub { display_help();    exit 0 },
  'version|v'      => sub { display_version(); exit 0 },
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
  if ($action == 0) { $args{date} = translate_mask($value) }
  else { $args{date} = translate_date($value) }
}

# Translate due date identifier:
if ($action >= 22 && $action <= 24) {
  $identifier = translate_mask($identifier);
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
if    ($action ==  0) { display_tasks(\%args) }
elsif ($action ==  1) { add_task(\%args) }
elsif ($action ==  2) { change_task($identifier, \%args) }
elsif ($action ==  3) { remove_task($identifier) }
elsif ($action == 12) { change_group($identifier, \%args) }
elsif ($action == 13) { remove_group($identifier) }
elsif ($action == 14) { purge_group($identifier) }
elsif ($action == 22) { change_date($identifier, \%args) }
elsif ($action == 23) { remove_date($identifier) }
elsif ($action == 24) { purge_date($identifier) }
elsif ($action == 32) { change_old(\%args) }
elsif ($action == 33) { remove_old() }
elsif ($action == 34) { purge_old() }
elsif ($action == 42) { change_all(\%args) }
elsif ($action == 43) { remove_all() }
elsif ($action == 44) { purge_all() }
elsif ($action == 95) { revert_last_action() }
elsif ($action == 96) { display_groups() }
elsif ($action == 97) { display_statistics() }

# Return success:
exit 0;

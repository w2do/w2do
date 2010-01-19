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
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use Getopt::Long;
use Term::ANSIColor;
use Text::Wrap;

# General script information:
use constant NAME    => basename($0, '.pl');       # Script name.
use constant VERSION => '2.2.3';                   # Script version.

# General script settings:
our $homedir         = $ENV{HOME}          || $ENV{USERPROFILE} || '.';
our $savefile        = $ENV{W2DO_SAVEFILE} || catfile($homedir, '.w2do');
our $backext         = '.bak';                     # Backup file extension.
our $verbose         = 1;                          # Verbosity level.
our $with_id         = 1;                          # Include ID?
our $with_group      = 1;                          # Include group name?
our $with_date       = 1;                          # Include due date?
our $with_pri        = 1;                          # Include priority?
our $with_state      = 1;                          # Include state?
our $bare            = 0;                          # Leave out the table
                                                   # header and separators?
# Appearance settings:
$Text::Wrap::columns = $ENV{W2DO_WIDTH}    || 75;  # Default table width.
our $coloured        = 0;                          # Use colourded output?

# Colours settings:
our $headcol         = 'bold white on_green';      # Header.
our $donecol         = 'green';                    # Finished tasks.
our $todaycol        = 'bold';                     # Unfinished tasks.

# Other command-line options:
my $identifier       = undef;                      # Task identifier.
my $action           = 0;                          # Default action.
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

# Save data to the save file:
sub save_data {
  my $data = shift || die 'Missing argument';

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
    # Report failure: and exit:
    print STDERR "Unable to write to `$savefile'.\n";

    # Return failure:
    return 0;
  }

  # Return success:
  return 1;
}

# Add data to the end of the save file:
sub add_data {
  my $data = shift || die 'Missing argument';

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
    # Report failure:
    print STDERR "Unable to write to `$savefile'.\n";

    # Return failure:
    return 0;
  }

  # Return success:
  return 1;
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
      if ("$1" lt date_to_string() && "$1" ne 'anytime') {
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
      save_data($data) or return 0;

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

  # Return success:
  return 1;
}

# Remove selected items from the task list:
sub remove_selection {
  my ($selected, $data) = @_;

  # Check whether the selection is not empty:
  if (@$selected) {
    # Store data to the save file:
    save_data($data) or return 0;

    # Report success:
    print "Selected tasks have been successfully removed.\n" if $verbose;
  }
  else {
    # Report empty selection:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
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
    save_data($data) or return 0;

    # Report success:
    print "Selected tasks have been successfully purged.\n" if $verbose;
  }
  else {
    # Report empty selection:
    print "No matching task found.\n" if $verbose;
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

# Choose first available ID:
sub choose_id {
  # Initialize required variables:
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

# Compose progress bar:
sub compose_progressbar {
  my $percent = shift || 0;

  # Decide which pointer to use:
  my $pointer = ($percent > 0 && $percent < 100) ? '>' : '';

  # Return the progress bar string:
  return '[' . '=' x int($percent/10) . $pointer .
         ' ' x ($percent ? (9 - int($percent/10)) : 10) . ']';
}

# Draw table header:
sub draw_header {
  # End here if the header is to be omitted:
  return 1 if $bare;

  # Prepare the header layout:
  my $border = '='x ($Text::Wrap::columns - 1);
  my $header = ' ';
  my $indent = 5;

  # Add enabled header items:
  $header .= 'id    '       and $indent += 6  if $with_id;
  $header .= 'group       ' and $indent += 12 if $with_group;
  $header .= 'date        ' and $indent += 12 if $with_date;
  $header .= 'pri  '        and $indent += 5  if $with_pri;
  $header .= 'sta  '        and $indent += 5  if $with_state;
  $header .= 'task' . ' 'x ($Text::Wrap::columns - 1 - $indent);

  # Check whether to use colours:
  unless ($coloured) {
    # Display plain table header:
    print "$border\n$header\n$border\n";
  }
  else {
    # Display coloured table header:
    print colored ($header, $headcol);
    print "\n";
  }

  # Return success:
  return 1;
}

# Draw table separator:
sub draw_separator {
  # End here if the separator is to be omitted:
  return 1 if $bare;

  # Prepare the separator layout:
  my $separator = '-'x ($Text::Wrap::columns - 1);
  my $header    = ' ';
  my $indent    = 5;

  # Add enabled header items:
  $header .= 'id    '       and $indent += 6  if $with_id;
  $header .= 'group       ' and $indent += 12 if $with_group;
  $header .= 'date        ' and $indent += 12 if $with_date;
  $header .= 'pri  '        and $indent += 5  if $with_pri;
  $header .= 'sta  '        and $indent += 5  if $with_state;
  $header .= 'task' . ' 'x ($Text::Wrap::columns - 1 - $indent);

  # Check whether to use colours:
  unless ($coloured) {
    # Display plain separator:
    print "$separator\n";
  }
  else {
    # Display coloured separator:
    print colored ($header, $headcol);
    print "\n";
  }

  # Return success:
  return 1;
}

# Draw table row:
sub draw_row {
  my ($id, $group, $date, $priority, $state, $task) = @_;

  # Initialize required variables:
  my $row    = ' ';
  my $indent = 1;

  # Add enabled items:
  $row .= sprintf("%-4s  ", $id)       and $indent += 6  if $with_id;
  $row .= sprintf("%-10s  ", $group)   and $indent += 12 if $with_group;
  $row .= sprintf("%-10s  ", $date)    and $indent += 12 if $with_date;
  $row .= sprintf(" %s   ", $priority) and $indent += 5  if $with_pri;
  $row .= sprintf(" %s   ", $state)    and $indent += 5  if $with_state;

  # Prepare the task entry:
  $task =  wrap(' 'x $indent, ' 'x $indent, $task);
  $task =~ s/\s+//;

  # Add the task entry:
  $row .= $task;

  # Check whether to use colours:
  unless ($coloured) {
    # Display the task entry:
    print "$row\n";
  }
  else {
    # Set up colours:
    print color $donecol  if $state eq 'f';
    print color $todaycol if $state ne 'f' && $date eq 'today';

    # Display the task entry:
    print "$row\n";

    # Reset colours:
    print color 'reset';
  }

  # Return success:
  return 1;
}

# Display usage information:
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

  --change-pri priority    change all items with selected priority
  --remove-pri priority    remove all items with selected priority
  --purge-pri priority     remove all finished items with selected priority

  --change-old             change all items with passed due date
  --remove-old             remove all items with passed due date
  --purge-old              remove all finished items with passed due date

  --change-all             change all items in the task list
  --remove-all             remove all items from the task list
  --purge-all              remove all finished items from the task list

  --undo                   revert last action
  --groups                 display list of groups in the task list
  --stats                  display detailed task list statistics

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
  -b, --bare               do not display table header and separators
  -I, --no-id              do not display ID column
  -G, --no-group           do not display group column
  -D, --no-date            do not display due date column
  -P, --no-priority        do not display priority column
  -S, --no-state           do not display state column
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

# Display a list of groups in the task list:
sub display_groups {
  # Initialize required variables:
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

  # Return success:
  return 1;
}

# Display detailed task list statistics:
sub display_statistics {
  # Initialize required variables:
  my $stats = {};
  my ($bar, $per, $rat);

  # Get task list statistics:
  my ($groups, $tasks, $undone) = get_stats($stats);
  my  $done = $tasks - $undone;

  # Display overall statistics:
  printf "%d group%s, %d task%s, %d unfinished\n",
         $groups, (($groups != 1) ? 's' : ''),
         $tasks,  (($tasks  != 1) ? 's' : ''),
         $undone;

  # End here when the task list is empty:
  return 1 unless $groups;

  # Process each group:
  foreach my $group (sort (keys %$stats)) {
    # Count group percentage:
    $per = int($stats->{$group}->{done} * 100 / $stats->{$group}->{tasks});

    # Prepare the progress bar:
    $bar = compose_progressbar($per);

    # Prepare the finished/all ratio:
    $rat = "($stats->{$group}->{done}/$stats->{$group}->{tasks})";

    # Display group progress:
    printf "\n%-11s %s %3d%% %s", "$group:", $bar, $per, $rat;
  }

  # Count overall percentage:
  $per = $tasks ? int($done * 100 / $tasks) : 0;

  # Prepare the progress bar:
  $bar = compose_progressbar($per);

  # Prepare the finished/all ratio:
  $rat = "($done/$tasks)";

  # Display overall progress:
  printf "\n---\n%-11s %s %3d%% %s\n", "total:", $bar, $per, $rat;

  # Return success:
  return 1;
}

# Display items in the task list:
sub display_tasks {
  my $args = shift;

  # Initialize required variables:
  my @data;

  # Load matching tasks:
  load_selection(\@data, undef, $args) or return 0;

  # Check whether the list is not empty:
  if (@data) {
    # Initialize required variables:
    my ($id, $group, $date, $priority, $state, $task);
    my $current = '';

    # Set up the line wrapper:
    $Text::Wrap::columns++;

    # Display the table header:
    draw_header();

    # Process each task:
    foreach my $line (sort @data) {
      # Parse the task record:
      $line =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):(\d+)$/;

      # Check whether the group has changed:
      if (lc($1) ne $current) {
        # Display the divider unless the first group is being listed:
        draw_separator() if $group;

        # Remember the current group:
        $current = lc($1);
      }

      # If possible, use relative date reference:
      if    ($2 eq date_to_string()) { $date = 'today'; }
      elsif ($2 eq date_to_string(time - 86400)) { $date = 'yesterday'; }
      elsif ($2 eq date_to_string(time + 86400)) { $date = 'tomorrow';  }
      else  { $date = $2; }

      # Prepare the rest of the task entry:
      $id       = $6;
      $group    = $1;
      $priority = $3;
      $state    = ($4 eq 'f') ? '-' : 'f';
      $task     = $5;

      # Display the task entry:
      draw_row($id, $group, $date, $priority, $state, $task);
    }
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
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
  add_data(\@data) or return 0;

  # Report success:
  print "Task has been successfully added with id $id.\n" if $verbose;

  # Return success:
  return 1;
}

# Change selected item in the task list:
sub change_task {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected task:
  load_selection(\@selected, \@data, { id => shift }) or return 0;

  # Change selected item:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove selected item from the task list:
sub remove_task {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected task:
  load_selection(\@selected, \@data, { id => shift }) or return 0;

  # Remove selected item:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Change all items in the selected group:
sub change_group {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift }) or return 0;

  # Change selected items:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove all items in the selected group:
sub remove_group {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift }) or return 0;

  # Remove selected items:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Remove all finished items in the selected group:
sub purge_group {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { group => shift }) or return 0;

  # Purge selected items:
  purge_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Change all items with selected due date:
sub change_date {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift }) or return 0;

  # Change selected items:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove all items with the selected due date:
sub remove_date {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift }) or return 0;

  # Remove selected items:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Remove all finished items with selected due date:
sub purge_date {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { date => shift }) or return 0;

  # Purge selected items:
  purge_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Change all items with selected priority:
sub change_priority {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { priority => shift }) or return 0;

  # Change selected items:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove all items with selected priority:
sub remove_priority {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { priority => shift }) or return 0;

  # Remove selected items:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Remove all finished items with selected priority:
sub purge_priority {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_selection(\@selected, \@data, { priority => shift }) or return 0;

  # Purge selected items:
  purge_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Change all items with passed due date:
sub change_old {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data) or return 0;

  # Change selected items:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove all items with passed due date:
sub remove_old {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data) or return 0;

  # Change selected items:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Purge all items with passed due date:
sub purge_old {
  # Initialize required variables:
  my (@selected, @data);

  # Load selected tasks:
  load_old(\@selected, \@data) or return 0;

  # Purge selected tasks:
  purge_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Change all items in the task list:
sub change_all {
  # Initialize required variables:
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data) or return 0;

  # Change all items:
  change_selection(\@selected, \@data, shift) or return 0;

  # Return success:
  return 1;
}

# Remove all items from the task list:
sub remove_all {
  # Initialize required variables:
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data) or return 0;

  # Remove all items:
  remove_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
}

# Remove all finished items from the task list:
sub purge_all {
  # Initialize required variables:
  my (@selected, @data);

  # Load all tasks:
  load_selection(\@selected, \@data) or return 0;

  # Purge all tasks:
  purge_selection(\@selected, \@data) or return 0;

  # Return success:
  return 1;
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
  my $date = shift || die 'Missing argument';

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
  # Specifying options:
  'task|t=s'             => sub { $args{task}     = $_[1] },
  'group|g=s'            => sub { $args{group}    = $_[1] },
  'date|d=s'             => sub { $args{date}     = $_[1] },
  'priority|p=i'         => sub { $args{priority} = $_[1] },
  'finished|f'           => sub { $args{state}    = 't' },
  'unfinished|u'         => sub { $args{state}    = 'f' },

  # Additional options:
  'savefile|s=s'         => sub { $savefile            = $_[1] },
  'width|w=i'            => sub { $Text::Wrap::columns = $_[1] },
  'quiet|q'              => sub { $verbose             = 0 },
  'verbose|V'            => sub { $verbose             = 1 },
  'no-colour|no-color|X' => sub { $coloured            = 0 },
  'colour|color|C'       => sub { $coloured            = 1 },
  'no-bare|B'            => sub { $bare                = 0 },
  'bare|b'               => sub { $bare                = 1 },
  'no-id|I'              => sub { $with_id             = 0 },
  'with-id'              => sub { $with_id             = 1 },
  'no-group|G'           => sub { $with_group          = 0 },
  'with-group'           => sub { $with_group          = 1 },
  'no-date|D'            => sub { $with_date           = 0 },
  'with-date'            => sub { $with_date           = 1 },
  'no-priority|P'        => sub { $with_pri            = 0 },
  'with-priority'        => sub { $with_pri            = 1 },
  'no-state|S'           => sub { $with_state          = 0 },
  'with-state'           => sub { $with_state          = 1 },

  # General options:
  'list|l'               => sub { $action = 0 },
  'add|a=s'              => sub { $action = 1;  $args{task} = $_[1] },
  'change|c=i'           => sub { $action = 2;  $identifier = $_[1] },
  'remove|r=i'           => sub { $action = 3;  $identifier = $_[1] },

  'change-group=s'       => sub { $action = 12; $identifier = $_[1] },
  'remove-group=s'       => sub { $action = 13; $identifier = $_[1] },
  'purge-group=s'        => sub { $action = 14; $identifier = $_[1] },

  'change-date=s'        => sub { $action = 22; $identifier = $_[1] },
  'remove-date=s'        => sub { $action = 23; $identifier = $_[1] },
  'purge-date=s'         => sub { $action = 24; $identifier = $_[1] },

  'change-pri=i'         => sub { $action = 32; $identifier = $_[1] },
  'remove-pri=i'         => sub { $action = 33; $identifier = $_[1] },
  'purge-pri=i'          => sub { $action = 34; $identifier = $_[1] },

  'change-old'           => sub { $action = 42 },
  'remove-old'           => sub { $action = 43 },
  'purge-old'            => sub { $action = 44 },

  'change-all'           => sub { $action = 52 },
  'remove-all'           => sub { $action = 53 },
  'purge-all'            => sub { $action = 54 },

  'undo'                 => sub { $action = 95 },
  'groups'               => sub { $action = 96 },
  'stats|stat'           => sub { $action = 97 },

  'help|h'               => sub { display_help();    exit 0 },
  'version|v'            => sub { display_version(); exit 0 },
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
  if ($action == 0) { $args{date} = translate_mask($value) }
  else { $args{date} = translate_date($value) }
}

# Translate the due date identifier:
if ($action >= 22 && $action <= 24) {
  $identifier = translate_mask($identifier);
}

# Check the priority option:
if (my $value = $args{priority}) {
  unless ($value =~ /^[1-5]$/) {
    exit_with_error("Invalid priority `$value'.", 22);
  }
}

# Check the priority identifier:
if ($action >= 32 && $action <= 34) {
  unless ($identifier =~ /^[1-5]$/) {
    exit_with_error("Invalid priority `$identifier'.", 22);
  }
}

# Check the line width option:
if ($Text::Wrap::columns < 75) {
  exit_with_error("Invalid line width `$Text::Wrap::columns'.", 22);
}

# Perform appropriate action:
if    ($action ==  0) {
  # Display items in the task list:
  display_tasks(\%args) or exit 1;
}
elsif ($action ==  1) {
  # Add new item to the task list:
  add_task(\%args) or exit 1;
}
elsif ($action ==  2) {
  # Change selected item in the task list:
  change_task($identifier, \%args) or exit 1;
}
elsif ($action ==  3) {
  # Remove selected item from the task list:
  remove_task($identifier) or exit 1;
}
elsif ($action == 12) {
  # Change all items in the selected group:
  change_group($identifier, \%args) or exit 1;
}
elsif ($action == 13) {
  # Remove all items from the selected group:
  remove_group($identifier) or exit 1;
}
elsif ($action == 14) {
  # Remove all finished items from the selected group:
  purge_group($identifier) or exit 1;
}
elsif ($action == 22) {
  # Change all items with selected due date:
  change_date($identifier, \%args) or exit 1;
}
elsif ($action == 23) {
  # Remove all items with selected due date:
  remove_date($identifier) or exit 1;
}
elsif ($action == 24) {
  # Remove all finished items with selected due date:
  purge_date($identifier) or exit 1;
}
elsif ($action == 32) {
  # Change all items with selected priority:
  change_priority($identifier, \%args) or exit 1;
}
elsif ($action == 33) {
  # Remove all items with selected priority:
  remove_priority($identifier) or exit 1;
}
elsif ($action == 34) {
  # Remove all finished items with selected priority:
  purge_priority($identifier) or exit 1;
}
elsif ($action == 42) {
  # Change all items with passed due date:
  change_old(\%args) or exit 1;
}
elsif ($action == 43) {
  # Remove all items with passed due date:
  remove_old() or exit 1;
}
elsif ($action == 44) {
  # Remove all finished items with passed due date:
  purge_old() or exit 1;
}
elsif ($action == 52) {
  # Change all items in the task list:
  change_all(\%args) or exit 1;
}
elsif ($action == 53) {
  # Remove all items from the task list:
  remove_all() or exit 1;
}
elsif ($action == 54) {
  # Remove all finished items from the task list:
  purge_all() or exit 1;
}
elsif ($action == 95) {
  # Revert last action:
  revert_last_action() or exit 1;
}
elsif ($action == 96) {
  # Display list of groups in the task list:
  display_groups() or exit 1;
}
elsif ($action == 97) {
  # Display detailed task list statistics:
  display_statistics() or exit 1;
}

# Return success:
exit 0;

__END__

=head1 NAME

w2do - a simple text-based todo manager

=head1 SYNOPSIS

B<w2do> [B<-l>] [B<-t> I<task>] [B<-g> I<group>] [B<-d> I<date>] [B<-p>
I<priority>] [B<-f>|B<-u>]

B<w2do> B<-a> I<task> [B<-g> I<group>] [B<-d> I<date>] [B<-p> I<priority>]
[B<-f>|B<-u>]

B<w2do> B<-c> I<id> [B<-t> I<task>] [B<-g> I<group>] [B<-d> I<date>] [B<-p>
I<priority>] [B<-f>|B<-u>]

B<w2do> B<-r> I<id>

B<w2do> [I<options>]

=head1 DESCRIPTION

B<w2do> is a simple to use yet efficient command-line todo manager written
in Perl 5.

=head1 OPTIONS

=head2 General Options

=over

=item B<-l>, B<--list>

Display items in the task list. All tasks are listed by default, but
desired subset can be easily selected via specifying options as well. Since
listing is the default action, this option can be safely omitted.

=item B<-a> I<task>, B<--add> I<task>

Add new item with selected I<task> name to the task list. When no
additional specifying options are given, the group B<general>, the due date
B<anytime> and the priority B<3> is used by default and the task is marked
as unfinished.

=item B<-c> I<id>, B<--change> I<id>

Change item with selected I<id> in the task list. Further specifying
options are required in order to take any effect.

=item B<-r> I<id>, B<--remove> I<id>

Remove item with selected I<id> from the task list.

=item B<--change-group> I<group>

Change all items in the selected I<group>. Further specifying options are
required in order to take any effect.

=item B<--remove-group> I<group>

Remove all items from the selected I<group>.

=item B<--purge-group> I<group>

Remove all finished items from the selected I<group>.

=item B<--change-date> I<date>

Change all items with selected due I<date>. Further specifying options are
required in order to take any effect.

=item B<--remove-date> I<date>

Remove all items with selected due I<date>.

=item B<--purge-date> I<date>

Remove all finished items with selected due I<date>.

=item B<--change-pri> I<priority>

Change all items with selected I<priority>. Further specifying options are
required in order to take any effect.

=item B<--remove-pri> I<priority>

Remove all items with selected I<priority>.

=item B<--purge-pri> I<priority>

Remove all finished items with selected I<priority>.

=item B<--change-old>

Change all items with passed due date. Further specifying options are
required in order to take any effect.

=item B<--remove-old>

Remove all items with passed due date.

=item B<--purge-old>

Remove all finished items with passed due date.

=item B<--change-all>

Change all items in the task list. Further specifying options are required
in order to take any effect.

=item B<--remove-all>

Remove all items from the task list.

=item B<--purge-all>

Remove all finished items from the task list.

=item B<--undo>

Revert last action. When invoked, the data are restored from the backup
file (i.e. C<~/.w2do.bak> by default), which is deleted at the same time.

=item B<--groups>

Display comma-delimited list of all groups in the task list.

=item B<--stats>

Display detailed task list statistics.

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

=item B<-s> I<file>, B<--savefile> I<file>

Use selected I<file> instead of the default C<~/.w2do> as a save file.

=item B<-w> I<width>, B<--width> I<width>

Use selected line I<width>; the minimal value is B<75>.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages; this is the default option.

=item B<-C>, B<--colour>, B<--color>

Use coloured output instead of the default plain text version.

=item B<-X>, B<--no-colour>, B<--no-color>

Use plain text output (no colours); this is the default option.

=item B<-b>, B<--bare>

Do not display table header and group separators.

=item B<-B>, B<--no-bare>

Display table header and group separators; the default option.

=item B<-I>, B<--no-id>

Do not display ID column in the listing.

=item B<--with-id>

Display ID column in the listing; the default option.

=item B<-G>, B<--no-group>

Do not display group column in the listing.

=item B<--with-group>

Display group column in the listing; the default option.

=item B<-D>, B<--no-date>

Do not display due date column in the listing.

=item B<--with-date>

Display due date column in the listing; the default option.

=item B<-P>, B<--no-priority>

Do not display priority column in the listing.

=item B<--with-priority>

Display priority column in the listing; the default option.

=item B<-S>, B<--no-state>

Do not display state column in the listing.

=item B<--with-state>

Display state column in the listing; the default option.

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

=item I<~/.w2do.bak>

Default backup file.

=back

=head1 SEE ALSO

B<w2html>(1), B<w2text>(1), B<perl>(1).

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

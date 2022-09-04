use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

# global vars
# so we don't have to keep writing $#{$board->[0]}
my $boardlength = 6;

## A game in memory like this
## [
##    [4,4,4,4,4,4,0],
##    [4,4,4,4,4,4,0]
## ]
##
## Looks like this on a real board
##
##                        PLAYER 0 (them)
##
## index     6    5    4    3    2    1    0 
##        +----+----+----+----+----+----+----+----+
##        |    |    |    |    |    |    |    |    |
##        |    |  4 |  4 |  4 |  4 |  4 |  4 |    |
##        |    |    |    |    |    |    |    |    |
##        |  0 +----+----+----+----+----+----+  0 |
##        |    |    |    |    |    |    |    |    |
##        |    |  4 |  4 |  4 |  4 |  4 |  4 |    |
##        |    |    |    |    |    |    |    |    |
##        +----+----+----+----+----+----+----+----+
## index          0    1    2    3    4    5    6
##
##                        PLAYER 1 (you)

play_game();
# test();

sub play_game {
    # computer is player 1
    my $computer_player = 1;
    my $human_player = 0;

    my $board = [
	[4,4,4,4,4,4,0],
	[4,4,4,4,4,4,0]
    ];

    my $current_player = 0;
    my $moves = possible_moves($board, $current_player);
    while (@$moves) {
	my $move;
	if ($current_player == $human_player) {
	    print_board($board);
	    $move = get_human_move();
	}
	else {
	    $move = get_computer_move($board, $current_player);
	    print "computer moves in $move\n";
	}
	($board, $current_player) = apply_move(
	    $board, $current_player, $move
	);
	$moves = possible_moves($board, $current_player);
    }

    print_victory($board, $computer_player, $human_player);
}

sub print_victory {
    my ($board, $computer_player, $human_player) = @_;

    my $human_score = $board->[$human_player][$boardlength];
    my $computer_score = $board->[$computer_player][$boardlength];

    print "score is: \n";
    print "\t human:    $human_score\n";
    print "\t computer: $computer_score\n\n";
    
    if ($human_score > $computer_score) {
	print "human wins!\n";
    }
    elsif ($computer_score > $human_score) {
	print "computer wins!\n";
    }
    else {
	print "tie???\n";
    }
}

sub get_human_move {
    print "\nplease select a move, 0-5\n";
    my $hasvalid = 0;
    my $move;
    while (!$hasvalid) {
	$move = <STDIN>;
	$move = int($move);
	unless ($move >= 0 && $move <= 5) {
	    print "please enter a number between 0 and 5\n";
	}
	else {
	    $hasvalid = 1;
	}
    }
    return $move;
}

sub get_random_move {
    my ($board, $player) = @_;
    
    # play randomly
    my $moves = possible_moves($board, $player);
    return $moves->[int(rand(@$moves))];
}

sub get_computer_move {
    my ($board, $player) = @_;
    return _min_max($board, $player, $player, 0);
}

sub _min_max {
    my ($board, $current_player, $computer_player, $depth) = @_;
    my $depthlimit = 8;

    my @moves = @{possible_moves($board, $current_player)};
    # if the game is over, return the score
    if (!@moves) {
	return score_board($board);
    }
    # if we have exceeded the depth limit, return the score so far
    if ($depth >= $depthlimit) {
	return score_board($board);
    }

    # move, score - [x,y]
    my @scores;
    for my $move (@moves) {
	my ($nextboard, $nextplayer) = apply_move(
	    $board, $current_player, $move
	);
	my $score = _min_max(
	    $nextboard, $nextplayer, $computer_player, ($depth + 1)
	);
	push @scores, [$move, $score];
    }
    # scores sorted from most favorable for opponent to least
    @scores = sort { $a->[1] <=> $b->[1] } @scores;
    if ($current_player == $computer_player) {
	# return the best move for the computer
	return $scores[-1][0];
    }
    else {
	# return the best move for the computer's opponent
	return $scores[0][0];
    }
}

sub score_board {
    my ($board) = @_;

    # score is positive is favorable to player 1,
    # negative if favorable to player 0
    return $board->[1][-1] - $board->[0][-1];
    
}

sub possible_moves {
    my ($board, $player) = @_;

    # the difference in the logic for each side reqires explanation
    # for side 1, move 0 is position 0 in the array, counting forwards
    # but for side 0, move 0 is position $boardlength - 1,
    # and counting backwards
    my @moves;
    for my $n (0..$boardlength - 1) {
	my $pos = $player == 1 ? $n : $boardlength - 1 - $n;
	if ($board->[$player][$pos] > 0) {
	    push @moves, $pos;
	}
    }
    return \@moves;
}

sub apply_move {
    my ($board, $player, $space) = @_;

    my $boardcopy = [[@{$board->[0]}], [@{$board->[1]}]];

    # the number of chips we are playing with
    my $val = $boardcopy->[$player][$space];
    # pick up all the chips
    $boardcopy->[$player][$space] = 0;
    # the cell we are playing in
    my $current = [$player, $space];

    # visit wells in a counter-clockwise circle,
    # adding a single chip to each, until there are no more chips
    while ($val > 0) {
	$current->[1]++;

	# if we would play off the end of one player's array
	# move to the next player, in the first space
	if ($current->[1] > $boardlength) {
	    $current->[0] = next_player($current->[0]);
	    $current->[1] = 0;
	}
	# add one chip
	$boardcopy->[$current->[0]][$current->[1]]++;
	$val--;
    }

    my $nextplayer = next_player($player);

    # if the player cleared their side,
    # they get all of their opponent's chips
    if (!@{possible_moves($boardcopy, $player)}) {
	for my $n (0..$boardlength-1) {
	    my $cellval = $boardcopy->[$nextplayer][$n];
	    $boardcopy->[$nextplayer][$n] = 0;
	    $boardcopy->[$player][-1] += $cellval;
	}
    }

    # if the player ended on their side, special things can happen
    if ($current->[0] == $player) {
	# the opposite of 0 is 5, 5 is 0, 1 is 4, 4 is 1, etc.
	my $opposite = $boardlength - ($current->[1] + 1);
	# if the last well played in was an end well,
	# the player gets an extra turn
	if ($current->[1] == $boardlength) {
	    $nextplayer = $player;
	}
	# if the well is not an end well, but was empty,
	# and the opposite side has chips,
	# the player gets all the chips in the well on the opposite side
	elsif (
	    $boardcopy->[$player][$current->[1]] == 1
	    && $boardcopy->[$nextplayer][$opposite]
	) {
	    # + 1 for the tile that landed in the empty well
	    $boardcopy->[$player][-1] += (
		$boardcopy->[$nextplayer][$opposite] + 1
	    );
	    $boardcopy->[$nextplayer][$opposite] = 0;
	    $boardcopy->[$player][$current->[1]] = 0;
	}
    }
    return ($boardcopy, $nextplayer);
}

sub next_player {
    my ($player) = @_;

    return ($player + 1) % 2;
}

sub print_board {
    my ($board) = @_;

    my $top = _print_top_bottom($board);
    my $cells = _print_cells($board);
    my $bottom = _print_top_bottom($board);

    print $top, $cells, $bottom;
}

sub _print_cells {
    my ($board) = @_;

    my $cells;
    # the player counter
    my $r = 0;
    for my $row (@$board) {
	# print the top space in the cells
	for my $n (0..$#$row + 1) {
	    $cells .= '|    ';
	}
	$cells .= "|\n";

	# print the space in the leftmost well
	$cells .= '|    ';
	# print the numbers in the interior cells
	for my $n (0..$#$row - 1) {
	    # the opposite player (top) is printed in reverse
	    if ($r == 0) {
		$n = $boardlength - ($n + 1);
	    }
	    $cells .= '|' . sprintf('%3d ',, $board->[$r][$n]);
	}
	# print the space in the rightmost well
	$cells .= "|    |\n";
	# print the bottom space in the cells
	for my $n (0..$#$row + 1) {
	    $cells .= '|    ';
	}
	$cells .= "|\n";

	# after the first row, print the border between the rows
	# and the values in the end wells
	if ($r == 0) {
	    # print the leftmost well and space
	    $cells .= '|' . sprintf('%3d ', $board->[0][-1]);
	    # then a border, similar to the top
	    $cells .= _print_top_bottom($board, 1);
	    # then the rightmost well and space
	    $cells .= '|' . sprintf('%3d ', $board->[1][-1]) . "|\n";
	}
	$r++;
    }
    return $cells;
}

sub _print_top_bottom {
    my ($board, $isinterior) = @_;

    my $printstr;
    # print the left end cell top / bottom
    if (!$isinterior) {
	$printstr .= '+----';
    }
    # print the interior cells
    for my $n (1..$boardlength) {
	$printstr .= '+----';
    }
    # print the right end cell top / bottom
    if (!$isinterior) {
	$printstr .= '+----';
	$printstr .= "+\n";
    }
    return $printstr;
}

# some test code
sub test {
    
}

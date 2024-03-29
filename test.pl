#!/usr/bin/perl

#	test suite

use Test::Simple tests => 20;

#	test for presence of player

my $count = 0;
for (split /:/, $ENV{PATH}) {
	$count++ if -x $_ . '/mpg123';
	}

ok($count, "finding player");

#	Find the test song!

my $f = './test.mp3';
$f = '../' . $f unless -f $f;
$f = '../' . $f unless -f $f;

ok(-f $f, "finding test track");
ok(-r $f, "read permissions");

use POE;
use POE::Component::Player::Mpg123;
ok(1, 'use PoCo::Player::Mpg123');

@events = qw/alive status info done died error stopped paused resumed ended/;
$s = POE::Session->create(
	package_states => ["main" => \@events],
	inline_states => {_start => sub { $_[KERNEL]->alias_set("main"); }}
	);

ok(defined($s), "session created");

$p = POE::Component::Player::Mpg123->new(
	debug => $ENV{DEBUG},
	);

ok(defined $p && $p->isa('POE::Component::Player::Mpg123')
	, "component instantiated"
	);

$w = $p->play($f);    # rip first track in CD
ok($w, "play issued");

# POEtry in motion

POE::Kernel->run();
ok(1, "done");

# --- event handlers ----------------------------------------------------------

$level = 0;

sub alive {
	return if $level;
	ok(1, "alive notification");
	}

$status = 0;
sub status {
	my ($fp, $fl, $sp, $sl) = @_[ARG0 .. $#_];

	if ($level == 0) {
		return if $status;
		ok(1, "status received");
		$p->pause();
		$status = 1;
		}

	if ($level == 1) {
		my $p = int(100 * $fp / ($fp + $fl));
		my $t = sprintf("%02d:%02d", ($sp / 60) % 60, $sp % 60);
		print " $p% [$fp] $t\r";
		}
	}

sub info {
	my $o = $_[ARG0];
	return if $level;

	my $ok = 0;
	if ($o->{type} eq 'filename') {
		ok($o->{filename} eq $f, "info: filename");
		}
	elsif ($o->{type} eq 'id3') {
        my @k = qw/album artist comment genre track type year/;
        my @v = ('Test Album', 'Test Artist', 'Test Comment'
			, 'Porn Groove', 'Test Title', 'id3', '4321'
			);

		for my $i (0 .. $#k) {
			$ok++ if $o->{$k[$i]} eq $v[$i];
			}
			
		ok($ok == @k, "info: id3");
		}
	elsif ($o->{type} eq 'stream') {
		my @k = qw/bitrate framesz channels copyrighted crc emphasis
			extension layer mode mode_extension samplerate mpegtype
			/;
		my @v = (128, 417, 2, 1, 1, 0, 0, 3, 'Joint-Stereo', 2, 44100, '1.0');

		for my $i (0 .. $#k) {
			$ok++ if $o->{$k[$i]} eq $v[$i];
			}

		ok($ok == @k, "info: stream");
		}
	}

sub paused {
	ok(1, "player paused");
	$p->resume();
	}

sub resumed {
	ok(1, "player resumed");
	$p->stop();
	}

sub stopped {
	ok(1, "player stopped");
	$p->xcmd("XCMD");
	}

sub ended {
	ok(1, "track ended");
	$p->quit();
	}

sub done {
	my ($kernel) = @_[KERNEL];
	ok(1, "player quit");
	$kernel->alias_remove("main");
	}

sub died {
	ok(1, "died tested");
	$p->start();	# restart
	$level = 1;
	$status = 0;
	ok(1, "wait for end");
	$p->play($f);
	}

sub error {
	my $args = $_[ARG1];
	my $msg = "error handler";
	$msg .= qq/ [$args->{err}]: "$args->{error}"/ if $args->{err} != -1;
	ok($args->{err} == -1, $msg);
	$args->{err} == -1 ? $p->kill() : exit;
	}

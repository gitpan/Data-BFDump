package Data::BFDump;
use Data::Dumper ();
use Data::BFDump;
use strict;
use warnings;
use Test::More ();

=head1 NAME

Data::BFDump::Test - Test framework for Data::BFDump

=head1 SYNOPSIS
	use Test::More tests=>1;

	use Data::BFDump::Test;
	{
		my $var=[];
		$BFDump->Test_Dump($BFDump->capture($var),
		                     "Simple Array",
		                     <<'	EXPECT_BF',<<'	EXPECT_DU');
		[]
		EXPECT_BF
		$VAR1 = [];
		EXPECT_DU
	}

=head1 DESCRIPTION

Used for testing Data::BFDump and for producing new tests for Data::BFDump.
This module is not, despite its name, a subclass. Instead using this package is identical
to using Data::BFDump but with one extra public method added (along with a number of
private methods as well).

Creating perl statements that will accurately recreate the given date structures is not
easy.  A module attempting to do so will almost certainly have some (hopefully rarely
encountered errors).  For instance while developing Data::BFDump I discovered a number
of errors in both Data::Dumper and Data::Dump.  This extension is intended to make testing
Data::BFDump as easy and as painless as possible while still being as thorough as possible.

The testing principle is to verify that the result of dumping the eval of a dump produces
the exact same result as the original.  For added peace of mind this is done in
combination with Data::Dumper (at least one bug I found in Data::Dump was serious enough
that I stopped testing against it).

When one call to Test_Dump is made a total of 10 tests are done.  These tests are done
from within the framework of Test::More so you must remember to

  use Test::More tests=>$Number_Tests*10;

or

  use Test::More qw(noplan);

before you use this module.

=head2 Test_Dump(ARRAYREF,[ARRAYREF],[OPTS])

Test_Dump performs a series of tests (using L<Test::More|Test::More>) on Data::BFDump,
comparing its results against L<Data::Dumper|Data::Dumper> as well as optionally against
user provied expectations.  If tests fail diagnostic results using L<Algorithm::Diff|Algorithm::Diff>
are provided.

The test sequence proceeds as follows.

=over 4

=item 1

Dump the vars (with the optional name settings) using both Data::BFDump and Data::Dumper.

If expectations for these are provided then test the results against the expectation.

If the testname contains 'devtest' in it then output the two results in a heredoc format for
inclusion in a new test.

=item 2

The two dumps are evaled and dumped using L<Data::Dumper|Data::Dumper> a second time.

The two second results are then compared both to each other and to the original dumper.
These tests are wrapped in a TODO block if it is known that they will fail and expectation
tests were both provided and passed successfully.  This is to avoid misleading failures that
are due to underlying perl semantics, but also provides lots of feedback while producing new
tests and fixing any bugs the tests turn up.

=back

=head1 CAVEAT

Since this module uses L<Data::Dumper|Data::Dumper> to test against it occasionally turns out that
a test failure indicates a bug in Data::Dumper and not in Data::BFDump, or even in both.  This is why
expectations for both Data::Dumper and Data::BFDump are provided. It also means that you should pay
careful attention to Data::Dumper's output when investigating a test failue.

=head2 EXPORT

None by default.

=head1 AUTHOR

Yves Orton, E<lt>demerphq@hotmail.comE<gt>

=head1 SEE ALSO

L<perl>, L<Test::More>, L<Data::Dumper>, L<Data::BFDump>

=cut

sub _test_eval_escape {
	my $self=shift;
	my $str=shift;
	$str=~s/([\%\@])/\\$1/g;
	return $str;
};

sub _test_dumper_eval {
	my $self   = shift;
	my $str    = shift;
	my $class  = shift;
	my $names  = shift;

	$class=($class eq "Dumper") ? "Data::Dumper" : "\$self";
	if ( $str !~ /\A\s*[\@\%\$]\w+/ ) {
		unless ($str =~s/(\n\s*)(\(.*\);\s*\n}\s*\z)/"$1\$self->capture".$self->_test_eval_escape($2)/se) {
			$str="\$self->capture($str)";
		}

	    $str = "\n".$class . "->Dump( $str ".($names?',$names':'').")\n";
	} elsif ($str) {
	    my @vars = $str =~ /^([\$\@\%]\w+) = /gm;
	    $str .= "\n".$class."->Dump(\$self->capture( " . $self->_test_eval_escape(join ( ",", @vars )) . " )".($names?',$names':'').")\n";
	    $str = "my (" . join ( ",", @vars ) . ");\n" . $str;
	}
	$str="package main;\n".$str;
	my $eval_dumper_ret = eval($str);
	if ($@) {
	    Test::More::diag "Failed eval!\n>--\n$@\n---\n$str\n---<\n";
	    return "$@";
	}
	return wantarray ? ($self->Test_Clean($eval_dumper_ret),$str) : $self->Test_Clean($eval_dumper_ret);
}

sub Test_Clean {
	my ( $s, $e, $db ) = @_;
	print "In=>$e\n" if $db;
	$e=~s/[\s\n]+\z//;
	if ( my ($ws) = $e =~ /\A(\s+)/ ) {
	    $e =~ s/^$ws//gm;
	}
	$e =~ s/\s+\n/\n/g;
	print "Out=>$e\n" if $db;
	return $e;
}


sub Test_Dump {
	my $self      = shift->_self_obj;
	my $vars      = shift;
	my $names     = shift;
	my $opts      = shift;
	($opts,$names)=($names,undef) if UNIVERSAL::isa($names,"HASH");
	$opts={} unless $opts;
	my $name      = $opts->{name} || "DevTest".(++$self->{devtest});
	my $expect_bf = $opts->{expect_bf} || "";
	my $expect_du = $opts->{expect_du} || "";
	our $TODO;
	our $SKIP;
	die "No parameter!" unless $vars;
	my @params=($vars);
	$names=[] unless $names;
	push @params,$names;
	# We test against Data::Dumper::Dump
	my $bfdump_ret = $self->Test_Clean( scalar $self->Dump(@params,$name) );
	my $dumper_ret = $self->Test_Clean( scalar Data::Dumper->Dump(@params) );
	my $devtest=0;
	if ( $name =~ /\bdevtest(\d+|\b)/i ) {
		$devtest=1;
	    Test::More::diag "$name\n";
	    $self->report;
	    ( my $bfd = $bfdump_ret ) =~ s/^/\t/gm;
	    ( my $dmp = $dumper_ret ) =~ s/^/\t/gm;
	    print "\n{\n\t\$BFDump->Test_Dump([],[],\n\t\t{name=>'$name',\n".
	          "\t\texpect_bf=><<'\tEXPECT_BF',expect_du=><<'\tEXPECT_DU'});\n";
	    print $bfd, "\n\tEXPECT_BF\n", $dmp . "\n\tEXPECT_DU\n}\n\n";
	}

	my ($ex_bf_ok,$ex_du_ok)=0;
	if ($expect_bf) {
	    $expect_bf = $self->Test_Clean($expect_bf);
	    Test::More::is( $bfdump_ret, $expect_bf, $name . " - Expect BF" );
	    if ( $bfdump_ret ne $expect_bf ) {
			Test::More::diag $self->_test_get_diff( $bfdump_ret, $expect_bf, "BFDump", "Expect BF" );
	    }
	   $ex_bf_ok = ( $bfdump_ret eq $expect_bf );
	} else {
		local $TODO="Test not implemented.";
		TODO:{
			Test::More::is( $bfdump_ret, $expect_bf, $name . " - Expect BF" );
		}
	}
	if ($expect_du) {
	    $expect_du = $self->Test_Clean($expect_du);
	    Test::More::is( $dumper_ret, $expect_du, $name . " - Expect DU" );
	    if ( $dumper_ret ne $expect_du ) {
			Test::More::diag $self->_test_get_diff( $dumper_ret,$expect_du, "Dumper", "Expect DU" );
	    }
	    $ex_du_ok = ( $dumper_ret eq $expect_du );
	} else {
		local $TODO="Test not implemented.";
		TODO:{
			Test::More::is( $dumper_ret, $expect_du, $name . ":Expect DU" );
		}
	}
	if ($opts->{expect_only}) {
		return $bfdump_ret;
	}

	my ($eval_du_bf,$eval_du_bf_str) = $self->_test_dumper_eval($bfdump_ret,'Dumper',$names);
	my ($eval_du_du,$eval_du_du_str) = $self->_test_dumper_eval($dumper_ret,'Dumper',$names);
	my ($eval_bf_bf,$eval_bf_bf_str) = $self->_test_dumper_eval($bfdump_ret,'BFDump',$names);
	my ($eval_bf_du,$eval_bf_du_str) = $self->_test_dumper_eval($dumper_ret,'BFDump',$names);

	my ($ok_eval_du_bf,$ok_eval_du_du,$ok_eval_du_eq)=(1,1,1);
	my ($ok_eval_bf_bf,$ok_eval_bf_du,$ok_eval_bf_eq)=(1,1,1);

	# First check dumper..
	unless ($dumper_ret eq $eval_du_du) {
		SKIP:{
			Test::More::skip("Broken Dumper?"." - Dumper eq Dumper Eval Dumper", 1);
			Test::More::is($eval_du_du,$dumper_ret, $name." - Dumper eq Dumper Eval Dumper");
		}
		$ok_eval_du_du=0;
		unless ($ex_du_ok) {
			Test::More::diag("Looks like Data::Dumper is broken. This could be subtle.");
			Test::More::diag($eval_du_du_str);
		} else {
			Test::More::diag("Looks like Data::Dumper is broken but produced expected results.");
			Test::More::diag($eval_du_du_str,"\n",$eval_du_du) if $devtest;
		}
	} else {
		Test::More::is( $eval_du_du, $dumper_ret, $name." - Dumper eq Dumper Eval Dumper");
	}
	unless ($dumper_ret eq $eval_du_bf) {
		unless ($ok_eval_du_du) {
			SKIP:{
				Test::More::skip ("Dumper didn't work correctly for this test.  - Dumper eq Dumper Eval Dumper",1);
				Test::More::is($eval_du_du,$dumper_ret, $name." - Dumper eq Dumper Eval Dumper");
			}
		} elsif ($ex_bf_ok) {
			TODO:{
				local $TODO="Expectation met, overlooking eval error.";
				Test::More::is($eval_du_bf ,$dumper_ret, $name." - Dumper eq Dumper Eval BFDump");
			}
		} else {
			Test::More::is($eval_du_bf ,$dumper_ret, $name." - Dumper eq Dumper Eval BFDump");
		}
		$ok_eval_du_bf=0;
		Test::More::diag($eval_du_bf_str."\n");
	} else {
		Test::More::is($dumper_ret,$eval_du_bf , $name." - Dumper eq Dumper Eval BFDump");
		Test::More::diag("Cool! Data::Dumper didnt get this one.")
			unless $ok_eval_du_du;
	}

	unless ($eval_du_bf eq $eval_du_du) {
		if ( $ok_eval_du_bf ) {
			SKIP:{
				Test::More::skip("Broken Dumper. - Dumper Eval BFDump eq Dumper Eval Dumper", 1);
				Test::More::is($eval_du_bf, $eval_du_du, $name." - Dumper Eval BFDump eq Dumper Eval Dumper");
			}
			#Test::More::diag("BFDump produces consistent results. But Dumper gets this wrong, invalid test.");
		} elsif (!$ok_eval_du_du) {
			SKIP:{
				Test::More::skip("Broken Dumper? - Dumper Eval BFDump eq Dumper Eval Dumper", 1);
				Test::More::is($eval_du_bf, $eval_du_du, $name." - Dumper Eval BFDump eq Dumper Eval Dumper");
			}
			Test::More::diag("Neither Dumper nor BFDump produce consistent results. Invalid test.");
		} elsif ($ex_bf_ok) {
			TODO:{
				local $TODO="Expectation met, 2nd level dump mismatch.";
				Test::More::is($eval_du_bf, $eval_du_du, $name." - Dumper Eval BFDump eq Dumper Eval Dumper");
			}
		} else {
			Test::More::is($eval_du_bf, $eval_du_du, $name." - Dumper Eval BFDump eq Dumper Eval Dumper");
		}
		$ok_eval_du_eq=0;
	} else {
		Test::More::is($eval_du_bf, $eval_du_du, $name." - Dumper Eval BFDump eq Dumper Eval Dumper");
		Test::More::diag("Dumper and BFDump are both buggy in the same way. Sigh.")
			unless $ok_eval_du_du;
	}
	unless ($opts->{has_sym}) {
		unless (Test::More::is( $eval_bf_bf,$bfdump_ret, $name." - BFDump eq BFDump Eval BFDump")){
			$ok_eval_bf_bf=0;
			print $eval_bf_bf_str,"\n"
		}
	} else {
		SKIP:{
			Test::More::skip("as it uses Symbol - BFDump eq BFDump Eval BFDump",1);
			Test::More::is( $eval_bf_bf,$bfdump_ret, $name." - BFDump eq BFDump Eval BFDump");
		}
	}
	if ($ok_eval_du_du) {
		if ($opts->{has_subs}) {
			SKIP:{
				Test::More::skip("Dumping subroutines. Dumper doesnt do this correctly. Invalid test.",2);
				unless (Test::More::is($eval_bf_du,$bfdump_ret,  $name." - BFDump eq BFDump Eval Dumper" )) {
					$ok_eval_bf_du=0;
					print $eval_bf_du_str,"\n"
				}
				unless (Test::More::is($eval_bf_bf, $eval_bf_du, $name." - BFDump Eval BFDump eq BFDump Eval Dumper")){
					$ok_eval_bf_eq=0;
					print $eval_bf_bf_str,"\n",$eval_bf_du_str,"\n"
				}
			}
		} else {
			unless (Test::More::is( $eval_bf_du,$bfdump_ret, $name." - BFDump eq BFDump Eval Dumper" )) {
				$ok_eval_bf_du=0;
				print $eval_bf_du_str,"\n"
			}
			unless (Test::More::is($eval_bf_bf, $eval_bf_du, $name." - BFDump Eval BFDump eq BFDump Eval Dumper")){
				$ok_eval_bf_eq=0;
				print $eval_bf_bf_str,"\n",$eval_bf_du_str,"\n"
			}
		}
	} else {
		if ($bfdump_ret ne $eval_bf_du) {
			SKIP:{
				Test::More::skip("Broken Dumper. Invalid test. - BFDump eq BFDump Eval Dumper",1);
				Test::More::isnt( $eval_bf_du,$bfdump_ret, $name." - BFDump eq BFDump Eval Dumper");
			}
		} else {
			Test::More::is( $eval_bf_du,$bfdump_ret, $name." - BFDump eq BFDump Eval Dumper");
			Test::More::diag("Why does Dumper get this one wrong?");
		}
		if ($eval_bf_bf ne $eval_bf_du) {
			SKIP:{
				Test::More::skip("Broken Dumper. Invalid test. - BFDump Eval BFDump eq BFDump Eval Dumper",1);
				Test::More::is($eval_bf_bf, $eval_bf_du, $name." - BFDump Eval BFDump eq BFDump Eval Dumper");
			}
		} else {
			Test::More::is($eval_bf_bf, $eval_bf_du, $name." - BFDump Eval BFDump eq BFDump Eval Dumper");
			Test::More::diag("Cool! Dumper got this one wrong but we didn't.");
		}
	}

	return $bfdump_ret;
}

sub _test_get_diff {
	my ( $self, $str1, $str2, $title1, $title2 ) = @_;
	$title1 ||= "BFDump";
	$title2 ||= "Dumper";

	#print $str1,"\n---\n",$str2;
	my @seq1 = split /\n/, $str1;
	my @seq2 = split /\n/, $str2;

	my @array;
	Algorithm::Diff::traverse_sequences(
	    \@seq1,
	    \@seq2,
	    {
			MATCH => sub {
			    my ( $t, $u ) = @_;
			    push @array, [ '=', $seq1[$t], $t, $u ];
			},
			DISCARD_A => sub {
			    my ( $t, $u ) = @_;
			    push @array, [ '-', $seq1[$t], $t, $u ];
			},
			DISCARD_B => sub {
			    my ( $t, $u ) = @_;
			    push @array, [ '+', $seq2[$u], $t, $u ];
			},
	    }
	);
	my $return = "-$title1\n+$title2\n";

	my ( $last, $skipped ) = ( "=", 1 );
	foreach ( 0 .. $#array ) {
	    my $elem = $array[$_];
	    my ( $do, $str, $pos, $eq ) = @$elem;

	    if ( $do eq $last
			&& $do eq '='
			&& ( $_ < $#array && $array[ $_ + 1 ][0] eq "=" || $_ == $#array ) )
	    {
			$skipped = 1;
			next;
	    }

	    $str .= "\n" unless $str =~ /\n\z/;
	    if ($skipped) {
			$return .= "\@$pos,$eq\n";
			$skipped = 0;
	    }
	    $last = $do;
	    $return .= join ( "", $do, "\t|", $str );
	}
	return $return

}

"4. Begin reading Chapter N. Do _not_ read the quotations that appear at the beginning of the chapter.";


#----------------------------------------------------------------
# Many thanks to Dan Brook (broquaint) for this module
#----------------------------------------------------------------
use Test::More tests => 66;
use strict;
use warnings;
use vars qw($Class $BFDump);
close STDERR;

BEGIN {
	$Class="Data::BFDump";
	use_ok( $Class."::Test" );

}

$BFDump = $Class->new();
isa_ok( $BFDump, $Class );

package foo;

sub new_hash  {
	my %hash;
	return bless \%hash,  'foo'
}

sub new_array {
	my @array;
	return bless \@array, 'foo'
}
sub new_scalar {
	my $scalar = "string";
	return bless \$scalar, 'foo'
}
sub new_re1 {
	my $re = qr/foo*bar?baz(?{ print "got it\n"})/;
	return bless \$re, 'foo';
}

sub new_re2 {
	my $re = qr/foo*bar?baz(?{ print "got it\n"})/;
	return bless $re, 'foo';
}

sub new_sub {
	return bless sub { $_[0]x2 }, 'foo';
}

sub new_fh {
	open( my $fh, $0 );
	return bless $fh, 'foo';
}

sub new_fh2 {
	open( FH, $0 );
	return bless \*FH, 'foo'
}

1;

package main;

my $class = 'foo';
{# 1 new hash
	$BFDump->Test_Dump(
		[ $class->new_hash() ], {name=>"new hash",
		expect_bf=>q[bless({},'foo')], expect_du=>qq[\$VAR1 = bless( {}, 'foo' );\n]}
	);
}
{# 2 new array
	$BFDump->Test_Dump(
		[ $class->new_array() ], {name=>"new array",
		expect_bf=>q[bless([],'foo')],      expect_du=>qq[\$VAR1 = bless( [], 'foo' );\n]}
	);
}
{# 3 new scalar
	no strict;
	$BFDump->Test_Dump( [ $class->new_scalar() ], {name=>"new scalar", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	bless(\do { my $itm = 'string' },'foo')
	EXPECT_BF
	$VAR1 = bless( do{\(my $o = 'string')}, 'foo' );
	EXPECT_DU
}
{# 4 new regexp1
	$BFDump->Test_Dump( [ $class->new_re1() ], {name=>"new regexp1", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $OBJ1 = bless(\do { my $itm = qr/foo*bar?baz(?{ print "got it\n"})/ },'foo');
		$OBJ1;
	}
	EXPECT_BF
	$VAR1 = bless( do{\(my $o = qr/(?-xism:foo*bar?baz(?{ print "got it\n"}))/)}, 'foo' );
	EXPECT_DU
}
{# 5 new regexp2
	$BFDump->Test_Dump( [ $class->new_re2() ], {name=>"new regexp2 (expected result is incorrect!)", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	bless(\do { my $itm = undef },'foo')
	EXPECT_BF
	$VAR1 = bless( do{\(my $o = undef)}, 'foo' );
	EXPECT_DU
}

{# 5 new sub
	$BFDump->Test_Dump( [ $class->new_sub() ], {has_subs=>1,name=>"new subroutine", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	bless(sub {
	              Carp::cluck('Using deparsed coderef');
	              package foo;
	              ($_[0] x 2);
	          },'foo')
	EXPECT_BF
	$VAR1 = bless( sub { "DUMMY" }, 'foo' );
	EXPECT_DU
}

TODO:{# 6 new file local
	$BFDump->Test_Dump( [ $class->new_fh() ], {has_sym=>1,name=>"new anonymous filehandle", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $OBJ1 = bless(\do { my $itm = Symbol::gensym() },'foo');
		$OBJ1;
	}
	EXPECT_BF
	$VAR1 = bless( \*{'foo::$fh'}, 'foo' );
	EXPECT_DU
}
{# 7 new file handle
	$BFDump->Test_Dump( [ $class->new_fh2() ], {name=>"new filehandle FH", expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $OBJ1 = bless(\*foo::FH,'foo');
		$OBJ1;
	}
	EXPECT_BF
	$VAR1 = bless( \*foo::FH, 'foo' );
	EXPECT_DU
}

__END__

#########################


use Test::More tests => 62;
use strict;
use warnings;
use vars qw/$Class $BFDump $a $b $c @c %b/;
BEGIN {
	$Class="Data::BFDump";
	use_ok( $Class."::Test" );

}
$BFDump=$Class->new();
isa_ok($BFDump, $Class);

#!./perl -w
#
# This test module adapted from the testsuite for Data::Dumper
# by the same name from the perl 5.6.1 release.
# Currently used without permission. Probably written by GSAR
# Everything after the __END__ marker has yet to be converted
# to a BFDump test. I anticipate that there are another 100 or
# so tests to be added in the file.

use Data::Dumper;

#############
#############

@c = ('c');
$c = \@c;
$b = {};
$a = [1, $b, $c];
$b->{a} = $a;
$b->{b} = $a->[1];
$b->{c} = $a->[2];

############# 1
##
{
	$BFDump->Test_Dump([$a,$b,$c], [qw(a b c)],
	                   {name=>"Named Vars Self Ref",
	                    expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $c = [ 'c' ];
		my $b = {
		             a => '$a',
		             b => '$b',
		             c => $c
		        };
		$b->{b} = $b;
		my $a = [ 1, $b, $c ];
		$b->{a} = $a;
		( $a, $b, $c );
	}
	EXPECT_BF
	$a = [
	       1,
	       {
	         'a' => [],
	         'b' => {},
	         'c' => [
	                  'c'
	                ]
	       },
	       []
	     ];
	$a->[1]{'a'} = $a;
	$a->[1]{'b'} = $a->[1];
	$a->[2] = $a->[1]{'c'};
	$b = $a->[1];
	$c = $a->[1]{'c'};
	EXPECT_DU
}

{
	$BFDump->Test_Dump([$a, $b], [qw(*a b)],
	                   {name=>"(\@a) Named Vars Self Ref",expect_only=>0,
	                    expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $b = {
		             a => '@a',
		             b => '$b',
		             c => [ 'c' ]
		        };
		$b->{b} = $b;
		my @a = ( 1, $b, $b->{c} );
		$b->{a} = \@a;
		( @a, $b );
	}
	EXPECT_BF
	@a = (
	       1,
	       {
	         'a' => [],
	         'b' => {},
	         'c' => [
	                  'c'
	                ]
	       },
	       []
	     );
	$a[1]{'a'} = \@a;
	$a[1]{'b'} = $a[1];
	$a[2] = $a[1]{'c'};
	$b = $a[1];
	EXPECT_DU
}

{
	$BFDump->Test_Dump([$a, $b], [qw(a *b)],
	                   {name=>"(\%b) Named Base Vars Self Ref",expect_only=>0,
	                    expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my %b = (
		             a => '$a',
		             b => '%b',
		             c => [ 'c' ]
		        );
		$b{b} = \%b;
		my $a = [ 1, \%b, $b{c} ];
		$b{a} = $a;
		( $a, %b );
	}
	EXPECT_BF
	$a = [
	       1,
	       {
	         'a' => [],
	         'b' => {},
	         'c' => [
	                  'c'
	                ]
	       },
	       []
	     ];
	$a->[1]{'a'} = $a;
	$a->[1]{'b'} = $a->[1];
	$a->[2] = $a->[1]{'c'};
	%b = %{$a->[1]};
	EXPECT_DU
}

{
	$BFDump->Test_Dump([$a, $b], [qw(*a *b)],
	                   {name=>"(\@a,\%b) Named Base Vars Self Ref",expect_only=>0,
	                    expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my %b = (
		             a => '@a',
		             b => '%b',
		             c => [ 'c' ]
		        );
		$b{b} = \%b;
		my @a = ( 1, \%b, $b{c} );
		$b{a} = \@a;
		( @a, %b );
	}
	EXPECT_BF
	@a = (
	       1,
	       {
	         'a' => [],
	         'b' => {},
	         'c' => [
	                  'c'
	                ]
	       },
	       []
	     );
	$a[1]{'a'} = \@a;
	$a[1]{'b'} = $a[1];
	$a[2] = $a[1]{'c'};
	%b = %{$a[1]};
	EXPECT_DU
}
{
	my $d = Data::BFDump->new([$a,$b], [qw(a b)]);
	$d->Seen({'*c' => $c});
	my $ret=$d->Dump;
	is($d->Test_Clean($ret),$d->Test_Clean(<<'	EXPECT_BF'),"Seen test");
	do{
		my $b = {
		             a => '$a',
		             b => '$b',
		             c => \@c
		        };
		$b->{b} = $b;
		my $a = [ 1, $b, \@c ];
		$b->{a} = $a;
		( $a, $b );
	}
	EXPECT_BF
}
{
	my $d = Data::BFDump->new([$a,$b], [qw(a b)]);
	$d->Seen({'*c' => $c});
	my $ret;
	$d->Indent(3);
	$d->Purity(0)->Quotekeys(0);
	$d->Reset;
	$ret=$d->Test_Clean($d->Dump);
	is($ret,$d->Test_Clean(<<'	EXPECT_BF'),"Indent(3), Purity(0), Quotekeys(0)");
	do{
		my $b = {
		             a => '$a',
		             b => '$b',
		             c => [ 'c' ]
		        };
		$b->{b} = $b;
		my $a = [
		             # 0
		             1,
		             # 1
		             $b,
		             # 2
		             $b->{c}
		        ];
		$b->{a} = $a;
		( $a, $b );
	}
	EXPECT_BF

	# Changed to a skip test cause harness doesnt recognize
	# todo tests for some reason. Must send Schwern a bug report.
	SKIP:{
	skip("Full Data::Dumper interface not implemented yet.",1);
	{
		Data::BFDump->Indent(1);
		$d->Reset;
		$ret=$d->Test_Clean($d->Dump);
	}
	is($ret,$d->Test_Clean(<<'	EXPECT_BF'),"Test \$Data::BFDump::Indent=1;");
	do{
		my $b = {
			a => '$a',
			b => '$b',
			c => \@c
		};
		$b->{b} = $b;
		my $a = [ 1, $b, \@c ];
		$b->{a} = $a;
		( $a, $b );
	}
	EXPECT_BF
	}#todo
}
{
	my $ret=Data::BFDump->Test_Clean(Data::BFDump::Dumper($a));
	is($ret,Data::BFDump->Test_Clean(<<'	EXPECT_BF'),"Test Data::BFDump::Dumper()");
	do{
		my $ARRAY1 = [
		                  1,
		                  {
		                       a => '$ARRAY1',
		                       b => '$ARRAY1->[1]',
		                       c => '$ARRAY1->[2]'
		                  },
		                  [ 'c' ]
		             ];
		$ARRAY1->[1]{a} = $ARRAY1;
		$ARRAY1->[1]{b} = $ARRAY1->[1];
		$ARRAY1->[1]{c} = $ARRAY1->[2];
		$ARRAY1;
	}
	EXPECT_BF
}
{
	my $foo = { "abc\000\'\efg" => "mno\000",
         "reftest" => \\1,
    };

	local $Data::Dumper::Useqq=1;
	$BFDump->Test_Dump([$foo],
	                   {name=>"hashkeys and quoting ",
	                   expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $HASH1 = {
		                 "abc\0'\efg" => "mno\0",
		                 reftest      => \do { my $itm = \do { my $itm = 1 } }
		            };
		$HASH1;
	}
	EXPECT_BF
	$VAR1 = {
	          "abc\0'\efg" => "mno\0",
	          "reftest" => \\1
	        };
	EXPECT_DU
	Test::More::diag("(Useqq is deprecated (meaningless) in BFDump, see Text::Quote)");
}
{
	package main;
	use Data::Dumper;
	our ($foo,@foo,%foo);
	$foo = 5;
	@foo = (-10,\*foo);
	%foo = (a=>1,b=>\$foo,c=>\@foo);
	$foo{d} = \%foo;
	$foo[2] = \%foo;

	local $Data::Dumper::Purity = 1;
	local $Data::Dumper::Indent = 3;
	Data::BFDump->Indent(3);

	Data::BFDump->Test_Dump([\\*foo, \\@foo, \\%foo], ['*foo', '*bar', '*baz'],
		{name=>'Funky globs with names',
		expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $bar = \do { my $itm = [
		                               # 0
		                               -10,
		                               # 1
		                               '${$foo}',
		                               # 2
		                               '${$baz}'
		                          ] };
		*::foo  = ${$bar};
		*::foo  = \do { my $itm = 5 };
		*::foo  = {
		               a => 1,
		               b => *foo{SCALAR},
		               c => ${$bar},
		               d => '*foo{HASH}'
		          };
		my $foo = \do { my $itm = \*main::foo };
		${$bar}->[1] = ${$foo};
		${$bar}->[2] = *foo{HASH};
		*foo{HASH}->{d} = *foo{HASH};
		my $baz = \*foo{HASH};
		( $foo, $bar, $baz );
	}
	EXPECT_BF
	$foo = \\*::foo;
	*::foo = \5;
	*::foo = [
	           #0
	           -10,
	           #1
	           do{my $o},
	           #2
	           {
	             'a' => 1,
	             'b' => do{my $o},
	             'c' => [],
	             'd' => {}
	           }
	         ];
	*::foo{ARRAY}->[1] = ${$foo};
	*::foo{ARRAY}->[2]{'b'} = *::foo{SCALAR};
	*::foo{ARRAY}->[2]{'c'} = *::foo{ARRAY};
	*::foo{ARRAY}->[2]{'d'} = *::foo{ARRAY}->[2];
	*::foo = *::foo{ARRAY}->[2];
	$bar = \[];
	${$bar} = *::foo{ARRAY};
	$baz = \{};
	${$baz} = *::foo{ARRAY}->[2];
	EXPECT_DU

	Data::BFDump->Test_Dump([\\*foo, \\@foo, \\%foo], [],
		{name=>'Funky globs no names',
		expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $REF2 = \do { my $itm = [
		                                # 0
		                                -10,
		                                # 1
		                                '${$REF1}',
		                                # 2
		                                '${$REF3}'
		                           ] };
		*::foo   = ${$REF2};
		*::foo   = \do { my $itm = 5 };
		*::foo   = {
		                a => 1,
		                b => *foo{SCALAR},
		                c => ${$REF2},
		                d => '*foo{HASH}'
		           };
		my $REF1 = \do { my $itm = \*main::foo };
		${$REF2}->[1] = ${$REF1};
		${$REF2}->[2] = *foo{HASH};
		*foo{HASH}->{d} = *foo{HASH};
		my $REF3 = \*foo{HASH};
		( $REF1, $REF2, $REF3 );
	}
	EXPECT_BF
	$VAR1 = \\*::foo;
	*::foo = \5;
	*::foo = [
	           #0
	           -10,
	           #1
	           do{my $o},
	           #2
	           {
	             'a' => 1,
	             'b' => do{my $o},
	             'c' => [],
	             'd' => {}
	           }
	         ];
	*::foo{ARRAY}->[1] = ${$VAR1};
	*::foo{ARRAY}->[2]{'b'} = *::foo{SCALAR};
	*::foo{ARRAY}->[2]{'c'} = *::foo{ARRAY};
	*::foo{ARRAY}->[2]{'d'} = *::foo{ARRAY}->[2];
	*::foo = *::foo{ARRAY}->[2];
	$VAR2 = \[];
	${$VAR2} = *::foo{ARRAY};
	$VAR3 = \{};
	${$VAR3} = *::foo{ARRAY}->[2];
	EXPECT_DU
}

__END__
#purity 0 means nothing to BFDump (yet)
############# 61
##
  $WANT = <<'EOT';
#@bar = (
#  -10,
#  \*::foo,
#  {}
#);
#*::foo = \5;
#*::foo = \@bar;
#*::foo = {
#  'a' => 1,
#  'b' => do{my $o},
#  'c' => [],
#  'd' => {}
#};
#*::foo{HASH}->{'b'} = *::foo{SCALAR};
#*::foo{HASH}->{'c'} = \@bar;
#*::foo{HASH}->{'d'} = *::foo{HASH};
#$bar[2] = *::foo{HASH};
#%baz = %{*::foo{HASH}};
#$foo = $bar[1];
EOT
  $Data::Dumper::Purity=0;

  TEST q(Data::Dumper->Dump([\\@foo, \\%foo, \\*foo], ['*bar', '*baz', '*foo']));
  TEST q(Data::Dumper->Dumpxs([\\@foo, \\%foo, \\*foo], ['*bar', '*baz', '*foo'])) if $XS;

#purity 0 means nothing to BFDump (yet)
############# 67
##
  $WANT = <<'EOT';
#$bar = [
#  -10,
#  \*::foo,
#  {}
#];
#*::foo = \5;
#*::foo = $bar;
#*::foo = {
#  'a' => 1,
#  'b' => do{my $o},
#  'c' => [],
#  'd' => {}
#};
#*::foo{HASH}->{'b'} = *::foo{SCALAR};
#*::foo{HASH}->{'c'} = $bar;
#*::foo{HASH}->{'d'} = *::foo{HASH};
#$bar->[2] = *::foo{HASH};
#$baz = *::foo{HASH};
#$foo = $bar->[1];
EOT

  TEST q(Data::Dumper->Dump([\\@foo, \\%foo, \\*foo], ['bar', 'baz', 'foo']));
  TEST q(Data::Dumper->Dumpxs([\\@foo, \\%foo, \\*foo], ['bar', 'baz', 'foo'])) if $XS;

#purity 0 means nothing to BFDump (yet)
############# 73
##
  $WANT = <<'EOT';
#$foo = \*::foo;
#@bar = (
#  -10,
#  $foo,
#  {
#    a => 1,
#    b => \5,
#    c => \@bar,
#    d => $bar[2]
#  }
#);
#%baz = %{$bar[2]};
EOT

  $Data::Dumper::Purity = 0;
  $Data::Dumper::Quotekeys = 0;
  TEST q(Data::Dumper->Dump([\\*foo, \\@foo, \\%foo], ['*foo', '*bar', '*baz']));
  TEST q(Data::Dumper->Dumpxs([\\*foo, \\@foo, \\%foo], ['*foo', '*bar', '*baz'])) if $XS;

#purity 0 means nothing to BFDump (yet)
############# 79
##
  $WANT = <<'EOT';
#$foo = \*::foo;
#$bar = [
#  -10,
#  $foo,
#  {
#    a => 1,
#    b => \5,
#    c => $bar,
#    d => $bar->[2]
#  }
#];
#$baz = $bar->[2];
EOT

  TEST q(Data::Dumper->Dump([\\*foo, \\@foo, \\%foo], ['foo', 'bar', 'baz']));
  TEST q(Data::Dumper->Dumpxs([\\*foo, \\@foo, \\%foo], ['foo', 'bar', 'baz'])) if $XS;

}

# This should be fine.
#############
#############
{
  package main;
  @dogs = ( 'Fido', 'Wags' );
  %kennel = (
            First => \$dogs[0],
            Second =>  \$dogs[1],
           );
  $dogs[2] = \%kennel;
  $mutts = \%kennel;
  $mutts = $mutts;         # avoid warning

############# 85
##
  $WANT = <<'EOT';
#%kennels = (
#  First => \'Fido',
#  Second => \'Wags'
#);
#@dogs = (
#  ${$kennels{First}},
#  ${$kennels{Second}},
#  \%kennels
#);
#%mutts = %kennels;
EOT

  TEST q(
	 $d = Data::Dumper->new([\\%kennel, \\@dogs, $mutts],
				[qw(*kennels *dogs *mutts)] );
	 $d->Dump;
	);
  if ($XS) {
    TEST q(
	   $d = Data::Dumper->new([\\%kennel, \\@dogs, $mutts],
				  [qw(*kennels *dogs *mutts)] );
	   $d->Dumpxs;
	  );
  }

#This should be fine.
############# 91
##
  $WANT = <<'EOT';
#%kennels = %kennels;
#@dogs = @dogs;
#%mutts = %kennels;
EOT

  TEST q($d->Dump);
  TEST q($d->Dumpxs) if $XS;

# This should be fine
############# 97
##
  $WANT = <<'EOT';
#%kennels = (
#  First => \'Fido',
#  Second => \'Wags'
#);
#@dogs = (
#  ${$kennels{First}},
#  ${$kennels{Second}},
#  \%kennels
#);
#%mutts = %kennels;
EOT


  TEST q($d->Reset; $d->Dump);
  if ($XS) {
    TEST q($d->Reset; $d->Dumpxs);
  }

# This should be fine
############# 103
##
  $WANT = <<'EOT';
#@dogs = (
#  'Fido',
#  'Wags',
#  {
#    First => \$dogs[0],
#    Second => \$dogs[1]
#  }
#);
#%kennels = %{$dogs[2]};
#%mutts = %{$dogs[2]};
EOT

  TEST q(
	 $d = Data::Dumper->new([\\@dogs, \\%kennel, $mutts],
				[qw(*dogs *kennels *mutts)] );
	 $d->Dump;
	);
  if ($XS) {
    TEST q(
	   $d = Data::Dumper->new([\\@dogs, \\%kennel, $mutts],
				  [qw(*dogs *kennels *mutts)] );
	   $d->Dumpxs;
	  );
  }

# This should be fine
############# 109
##
  TEST q($d->Reset->Dump);
  if ($XS) {
    TEST q($d->Reset->Dumpxs);
  }

# Deepcopy not supported by BFDump (so far)
############# 115
##
  $WANT = <<'EOT';
#@dogs = (
#  'Fido',
#  'Wags',
#  {
#    First => \'Fido',
#    Second => \'Wags'
#  }
#);
#%kennels = (
#  First => \'Fido',
#  Second => \'Wags'
#);
EOT

  TEST q(
	 $d = Data::Dumper->new( [\@dogs, \%kennel], [qw(*dogs *kennels)] );
	 $d->Deepcopy(1)->Dump;
	);
  if ($XS) {
    TEST q($d->Reset->Dumpxs);
  }

}

{

sub z { print "foo\n" }
$c = [ \&z ];

# This should be fine
############# 121
##
  $WANT = <<'EOT';
#$a = $b;
#$c = [
#  $b
#];
EOT

TEST q(Data::Dumper->new([\&z,$c],['a','c'])->Seen({'b' => \&z})->Dump;);
TEST q(Data::Dumper->new([\&z,$c],['a','c'])->Seen({'b' => \&z})->Dumpxs;)
	if $XS;

# This should be fine
############# 127
##
  $WANT = <<'EOT';
#$a = \&b;
#$c = [
#  \&b
#];
EOT

TEST q(Data::Dumper->new([\&z,$c],['a','c'])->Seen({'*b' => \&z})->Dump;);
TEST q(Data::Dumper->new([\&z,$c],['a','c'])->Seen({'*b' => \&z})->Dumpxs;)
	if $XS;

# This should be fine
############# 133
##
  $WANT = <<'EOT';
#*a = \&b;
#@c = (
#  \&b
#);
EOT

TEST q(Data::Dumper->new([\&z,$c],['*a','*c'])->Seen({'*b' => \&z})->Dump;);
TEST q(Data::Dumper->new([\&z,$c],['*a','*c'])->Seen({'*b' => \&z})->Dumpxs;)
	if $XS;

}

{
  $a = [];
  $a->[1] = \$a->[0];

# This should be fine
############# 139
##
  $WANT = <<'EOT';
#@a = (
#  undef,
#  do{my $o}
#);
#$a[1] = \$a[0];
EOT

TEST q(Data::Dumper->new([$a],['*a'])->Purity(1)->Dump;);
TEST q(Data::Dumper->new([$a],['*a'])->Purity(1)->Dumpxs;)
	if $XS;
}

{
  $a = \\\\\'foo';
  $b = $$$a;

# This should be fine
############# 145
##
  $WANT = <<'EOT';
#$a = \\\\\'foo';
#$b = ${${$a}};
EOT

TEST q(Data::Dumper->new([$a,$b],['a','b'])->Purity(1)->Dump;);
TEST q(Data::Dumper->new([$a,$b],['a','b'])->Purity(1)->Dumpxs;)
	if $XS;
}

{
  $a = [{ a => \$b }, { b => undef }];
  $b = [{ c => \$b }, { d => \$a }];

# This should be fine
############# 151
##
  $WANT = <<'EOT';
#$a = [
#  {
#    a => \[
#        {
#          c => do{my $o}
#        },
#        {
#          d => \[]
#        }
#      ]
#  },
#  {
#    b => undef
#  }
#];
#${$a->[0]{a}}->[0]->{c} = $a->[0]{a};
#${${$a->[0]{a}}->[1]->{d}} = $a;
#$b = ${$a->[0]{a}};
EOT

TEST q(Data::Dumper->new([$a,$b],['a','b'])->Purity(1)->Dump;);
TEST q(Data::Dumper->new([$a,$b],['a','b'])->Purity(1)->Dumpxs;)
	if $XS;
}

{
  $a = [[[[\\\\\'foo']]]];
  $b = $a->[0][0];
  $c = $${$b->[0][0]};

# This should be fine
############# 157
##
  $WANT = <<'EOT';
#$a = [
#  [
#    [
#      [
#        \\\\\'foo'
#      ]
#    ]
#  ]
#];
#$b = $a->[0][0];
#$c = ${${$a->[0][0][0][0]}};
EOT

TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Purity(1)->Dump;);
TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Purity(1)->Dumpxs;)
	if $XS;
}

{
    $f = "pearl";
    $e = [        $f ];
    $d = { 'e' => $e };
    $c = [        $d ];
    $b = { 'c' => $c };
    $a = { 'b' => $b };

# Maxdepth not implemented in BFDump
############# 163
##
  $WANT = <<'EOT';
#$a = {
#  b => {
#    c => [
#      {
#        e => 'ARRAY(0xdeadbeef)'
#      }
#    ]
#  }
#};
#$b = $a->{b};
#$c = $a->{b}{c};
EOT

TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Maxdepth(4)->Dump;);
TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Maxdepth(4)->Dumpxs;)
	if $XS;

# Maxdepth not implemented in BFDump
############# 169
##
  $WANT = <<'EOT';
#$a = {
#  b => 'HASH(0xdeadbeef)'
#};
#$b = $a->{b};
#$c = [
#  'HASH(0xdeadbeef)'
#];
EOT

TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Maxdepth(1)->Dump;);
TEST q(Data::Dumper->new([$a,$b,$c],['a','b','c'])->Maxdepth(1)->Dumpxs;)
	if $XS;
}

{
    $a = \$a;
    $b = [$a];
# Purity(0) means nothing in BFDump
############# 175
##
  $WANT = <<'EOT';
#$b = [
#  \$b->[0]
#];
EOT

TEST q(Data::Dumper->new([$b],['b'])->Purity(0)->Dump;);
TEST q(Data::Dumper->new([$b],['b'])->Purity(0)->Dumpxs;)
	if $XS;

# This should be fine.
############# 181
##
  $WANT = <<'EOT';
#$b = [
#  \do{my $o}
#];
#${$b->[0]} = $b->[0];
EOT


TEST q(Data::Dumper->new([$b],['b'])->Purity(1)->Dump;);
TEST q(Data::Dumper->new([$b],['b'])->Purity(1)->Dumpxs;)
	if $XS;
}

use Test::More tests => 83;
use strict;
use warnings;
use vars qw/$Class $BFDump/;
BEGIN {
	$Class="Data::BFDump";
	use_ok( $Class."::Test" );

}
$BFDump=$Class->new();
isa_ok($BFDump, $Class);

is($BFDump->Dump([]),"()","Empty list");

is($BFDump->Dump([[]]),"[]","Empty Arrary");

is($BFDump->Dump([{}]),"{}","Empty Hash");

is($BFDump->Dump(["Perlmonks"]),"'Perlmonks'","String");

is($BFDump->Dump([undef]),"undef","undef");

is($BFDump->Dump([undef,"Perlmonks"]),"( undef, 'Perlmonks' )","undef2");

is($BFDump->Dump([1..10]),"( 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 )","1..10");

is($BFDump->Dump(['A'..'G']),"( 'A', 'B', 'C', 'D', 'E', 'F', 'G' )","A..G");

is($BFDump->Dump([0]),"0","Returns 0");
{
	my $var=[];
	$BFDump->Test_Dump($BFDump->capture($var),
	                     {name=>"Simple Array",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	[]
	EXPECT_BF
	$VAR1 = [];
	EXPECT_DU
}
{
	my ($x,$y);
	$x=\$y;
	$y=\$x;
	$BFDump->Test_Dump($BFDump->capture([$x,$y]),
	                     {name=>"Scalar Cross",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $ARRAY1 = [ '$ARRAY1->[1]', '$ARRAY1->[0]' ];
		$ARRAY1->[0] = \$ARRAY1->[1];
		$ARRAY1->[1] = \$ARRAY1->[0];
		$ARRAY1;
	}
	EXPECT_BF
	$VAR1 = [
	          \\do{my $o},
	          do{my $o}
	        ];
	${${$VAR1->[0]}} = $VAR1->[0];
	$VAR1->[1] = ${$VAR1->[0]};
	EXPECT_DU
}
{
	my $VAR1      = 'Foo';
	my $HASH1     = { Foo => 'forward_ref' };
	#$BFDump->style('Dumper');
	my $ARRAY1    = $BFDump->capture($VAR1,$HASH1 );

	$HASH1->{Foo} = \$ARRAY1;
	my $test=$BFDump->capture( $ARRAY1, $VAR1, \$VAR1, $HASH1 );

	$BFDump->Test_Dump($test,
	                     {name=>"Variety",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $VAR1   = 'Foo';
		my $HASH1  = { Foo => '$ARRAY1' };
		my $ARRAY1 = Data::BFDump->capture( $VAR1, $HASH1 );
		$HASH1->{Foo} = \$ARRAY1;
		( $ARRAY1, $VAR1, \$VAR1, $HASH1 );
	}
	EXPECT_BF
	$VAR1 = [
	          'Foo',
	          {
	            'Foo' => \[]
	          }
	        ];
	${$VAR1->[1]{'Foo'}} = $VAR1;
	$VAR2 = ${\$VAR1->[0]};
	$VAR3 = \$VAR1->[0];
	$VAR4 = $VAR1->[1];
	EXPECT_DU
}

{
	my $var={};
	$BFDump->Test_Dump($BFDump->capture($var),
	                     {name=>"Simple Hash",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	{}
	EXPECT_BF
	$VAR1 = {};
	EXPECT_DU
}
{
	my $var=undef;
	my $rvar=\$var;
	$BFDump->Test_Dump($BFDump->capture($var,$rvar,1,2,3),
	                     {name=>"Ref to var(undef)",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $VAR1 = undef;
		( $VAR1, \$VAR1, 1, 2, 3 );
	}
	EXPECT_BF
	$VAR1 = undef;
	$VAR2 = \$VAR1;
	$VAR3 = 1;
	$VAR4 = 2;
	$VAR5 = 3;
	EXPECT_DU
}
{
	my $x = ['foo'];
	our $y;
	$x->[1] = \$y;
	$BFDump->Test_Dump($BFDump->capture($x,$y),
	                     {name=>"broquaint",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $VAR1   = undef;
		my $ARRAY1 = [ 'foo', \$VAR1 ];
		( $ARRAY1, $VAR1 );
	}
	EXPECT_BF
	$VAR1 = [
	          'foo',
	          \undef
	        ];
	$VAR2 = ${$VAR1->[1]};
	EXPECT_DU
}
{
	my $foo = 'Foo';
	my $bar = 'Bar';
	my @foobars= (\$foo,\$bar);
	my %foobars=(foo=>\$foo,bar=>\$bar);
	$BFDump->Test_Dump($BFDump->capture($foo,$bar,\@foobars,\%foobars),
	                     {name=>"merlyn var",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $VAR1   = 'Foo';
		my $VAR2   = 'Bar';
		my $ARRAY1 = [ \$VAR1, \$VAR2 ];
		(
		    $VAR1, $VAR2, $ARRAY1,
		    {
		         bar => $ARRAY1->[1],
		         foo => $ARRAY1->[0]
		    }
		);
	}
	EXPECT_BF
	$VAR1 = 'Foo';
	$VAR2 = 'Bar';
	$VAR3 = [
	          do{my $o},
	          do{my $o}
	        ];
	$VAR3->[0] = \$VAR1;
	$VAR3->[1] = \$VAR2;
	$VAR4 = {
	          'foo' => do{my $o},
	          'bar' => do{my $o}
	        };
	$VAR4->{'foo'} = \$VAR1;
	$VAR4->{'bar'} = \$VAR2;
	EXPECT_DU

	$BFDump->Test_Dump($BFDump->capture(\@foobars,\%foobars),
	                     {name=>"merlyn novar",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $ARRAY1 = [ \do { my $itm = 'Foo' }, \do { my $itm = 'Bar' } ];
		(
		    $ARRAY1,
		    {
		         bar => $ARRAY1->[1],
		         foo => $ARRAY1->[0]
		    }
		);
	}
	EXPECT_BF
	$VAR1 = [
	          \'Foo',
	          \'Bar'
	        ];
	$VAR2 = {
	          'foo' => do{my $o},
	          'bar' => do{my $o}
	        };
	$VAR2->{'foo'} = $VAR1->[0];
	$VAR2->{'bar'} = $VAR1->[1];
	EXPECT_DU

	$BFDump->Test_Dump($BFDump->capture(\%foobars,\@foobars),
	                    {name=>"merlyn novar reversed",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $HASH1 = {
		                 bar => \do { my $itm = 'Bar' },
		                 foo => \do { my $itm = 'Foo' }
		            };
		( $HASH1, [ $HASH1->{foo}, $HASH1->{bar} ] );
	}
	EXPECT_BF
	$VAR1 = {
	          'foo' => \'Foo',
	          'bar' => \'Bar'
	        };
	$VAR2 = [
	          do{my $o},
	          do{my $o}
	        ];
	$VAR2->[0] = $VAR1->{'foo'};
	$VAR2->[1] = $VAR1->{'bar'};
	EXPECT_DU
}
#########################





use Test::More tests => 18;
use strict;
use warnings;
use vars qw/$Class $BFDump $Glob %Glob @Glob/;

BEGIN {
	$Class="Data::BFDump";
	use_ok( $Class."::Test" );

}
$BFDump=$Class->new();
isa_ok($BFDump, $Class);

$Glob="This is a glob";

{
	$BFDump->Test_Dump([*Glob],
	                     {name=>"simple glob",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		*::Glob = [];
		*::Glob = \do { my $itm = 'This is a glob' };
		*::Glob = {};
		*main::Glob;
	}
	EXPECT_BF
	$VAR1 = *::Glob;
	*::Glob = \'This is a glob';
	*::Glob = [];
	*::Glob = {};
	EXPECT_DU
}
@Glob=(1..10);
{
	$BFDump->Test_Dump([*Glob],
	                     {name=>"Less simple glob",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		*::Glob = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
		*::Glob = \do { my $itm = 'This is a glob' };
		*::Glob = {};
		*main::Glob;
	}
	EXPECT_BF
	$VAR1 = *::Glob;
	*::Glob = \'This is a glob';
	*::Glob = [
	            1,
	            2,
	            3,
	            4,
	            5,
	            6,
	            7,
	            8,
	            9,
	            10
	          ];
	*::Glob = {};
	EXPECT_DU
}
__END__

#########################





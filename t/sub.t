use Test::More tests => 44;
use strict;
use warnings;
use vars qw/$Class $BFDump/;
close STDERR;
#*STDER=*STDOUT;

BEGIN {
	$Class="Data::BFDump";
	use_ok( $Class."::Test" );

}

$BFDump=$Class->new();
isa_ok($BFDump, $Class);
is($BFDump->coderef('warn',''),"Carp::cluck('Using deparsed coderef');","coderef('warn') set");
is($BFDump->coderef('stub'),"sub { Carp::cluck('Using coderef stub') }","coderef('stub') get");

my $Sub=sub{return "foo"};
my $Sub2=sub{if (@_) {
	        	print @_,"\n";
	        } else {
	        	print "Nothing\n";
	        }
	        };
my $hash={sub1=>$Sub,sub2=>$Sub2};
my $array=[$Sub,$Sub2];
{
	$BFDump->Test_Dump([$Sub],
	                     {has_subs=>1,name=>"simple sub",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	sub {
	        return('foo');
	    }
	EXPECT_BF
	$VAR1 = sub { "DUMMY" };
	EXPECT_DU
}
{
	$BFDump->Test_Dump([$Sub2],
	                     {has_subs=>1,name=>"less simple sub",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	sub {
	        if (@_) {
	            print(@_, "\n");
	        } else {
	            print("Nothing\n");
	        }
	    }
	EXPECT_BF
	$VAR1 = sub { "DUMMY" };
	EXPECT_DU
}
{
	$BFDump->Test_Dump([$hash],
	                     {has_subs=>1,name=>"hash of subs",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $HASH1 = {
		                 sub1 => sub {
		                                 return('foo');
		                             },
		                 sub2 => sub {
		                                 if (@_) {
		                                     print(@_, "\n");
		                                 } else {
		                                     print("Nothing\n");
		                                 }
		                             }
		            };
		$HASH1;
	}
	EXPECT_BF
	$VAR1 = {
	          'sub1' => sub { "DUMMY" },
	          'sub2' => sub { "DUMMY" }
	        };
	EXPECT_DU
}
{
	$BFDump->Test_Dump([$array],
	                     {has_subs=>1,name=>"array of subs",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $ARRAY1 = [
		                  sub {
		                          return('foo');
		                      },
		                  sub {
		                          if (@_) {
		                              print(@_, "\n");
		                          } else {
		                              print("Nothing\n");
		                          }
		                      }
		             ];
		$ARRAY1;
	}
	EXPECT_BF
	$VAR1 = [
	          sub { "DUMMY" },
	          sub { "DUMMY" }
	        ];
	EXPECT_DU
}
{#"devtest"||
	$BFDump->Test_Dump([[$array,$hash]],
	                    {has_subs=>1,name=>"double refed subs",
	                     expect_bf=><<'	EXPECT_BF',expect_du=><<'	EXPECT_DU'});
	do{
		my $ARRAY1 = [
		                  [
		                       sub {
		                               return('foo');
		                           },
		                       sub {
		                               if (@_) {
		                                   print(@_, "\n");
		                               } else {
		                                   print("Nothing\n");
		                               }
		                           }
		                  ],
		                  {
		                       sub1 => '$ARRAY1->[0][0]',
		                       sub2 => '$ARRAY1->[0][1]'
		                  }
		             ];
		$ARRAY1->[1]{sub1} = $ARRAY1->[0][0];
		$ARRAY1->[1]{sub2} = $ARRAY1->[0][1];
		$ARRAY1;
	}
	EXPECT_BF
	$VAR1 = [
	          [
	            sub { "DUMMY" },
	            sub { "DUMMY" }
	          ],
	          {
	            'sub1' => do{my $o},
	            'sub2' => do{my $o}
	          }
	        ];
	$VAR1->[1]{'sub1'} = $VAR1->[0][0];
	$VAR1->[1]{'sub2'} = $VAR1->[0][1];
	EXPECT_DU
}
__END__

#########################





package Data::BFDump;
use strict;
use warnings;
use warnings::register;
use base qw/Text::Quote Exporter/;
use vars qw/$VERSION @EXPORT_OK/;
use Devel::Peek ();
use B::Deparse ();
use overload ();
use Algorithm::Diff ();
use Symbol ();

use Carp ();
no  Carp::Assert;


use Test::More();
use Data::Dumper();

use constant IWIDTH     => 5;
use constant MKEYINDENT => 10;
use constant COLWIDTH   => 70;



BEGIN {
	$Data::Dumper::Purity = 1;
	$VERSION              = 0.3;
	@EXPORT_OK = qw(Dumper);
}

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new();
	$self->init();
	my @hashes=$self->bf_catalog(@_) if @_;
	$self->{cataloged}=\@hashes;
	return $self;
}

sub init {
	my $self = shift->_self_obj;
	$self->SUPER::init(@_);
	$self->_reset("INIT ALL");
	return $self;
}

sub Quotekeys {
	my $self=shift->_self_obj;
	$self->_warn_msg("Quotekeys() deprecated in BFDump. See Text::Quote->quote_prop for details. ('auto' is default)");
	if (@_) {
		$self->quote_prop("key_quote",shift);
	} else {
		return $self->quote_prop("key_quote");
	}
	return $self;
}

sub Indent {
	my $self=shift->_self_obj;
	$self->_warn_msg("Indent() deprecated in BFDump. Will be replaced by a style attribute (eventually)");
	if (@_) {
		my $val=shift;
		if ($val<2) {
			$self->_warn_msg("Indent($val) not implemented in BFDump (yet).");
		} elsif ($val == 2) {
			$self->_warn_msg("Indent(2) is default setting.")
				unless $self->{show_index};
			$self->{show_index}=0;
		} elsif ($val == 3) {
			$self->{show_index}=1;
		} else {
			$self->_warn_msg("Unknown value in Indent($val). Ignoring");
		}
	} else {
		return $self->{show_index} ? 3 : 2;
	}
	return $self;
}

sub Purity {
	my $self=shift->_self_obj;
	$self->_warn_msg("Purity not implemented yet. Ignoring.");
	return $self;
}



sub Reset {
	my $self=shift->_self_obj;
	foreach my $hash (values %{$self->{refs}},values %{$self->{scalars}}) {
		delete $hash->{df_defd} if exists($hash->{df_defd});
		delete $hash->{df_path} if exists($hash->{df_path});
	}
	return $self;
}

sub Seen {
	my $self=shift->_self_obj;
	my $hash=shift;
	unless ($hash) {
		die "No arg form of Seen() not implemented in BFDump at this time.";
	}
	foreach my $name (keys %$hash) {
		my ($reftype,$id)=$self->uber_ref($hash->{$name});
		my $item_hash=$self->_get_item_hash($id,$reftype);
		if ($item_hash) {
			if ($item_hash->{globname}) {
				$name=~s/^\*//;
				$name="*".$name;
			} elsif ($name=~/^\*/) {
				if ($reftype eq "ARRAY") {
					$name=~s/^\*/\@/;
				} elsif ($reftype eq "HASH") {
					$name=~s/^\*/\%/;
				} elsif ($reftype eq "CODE") {
					$name=~s/^\*/\&/;
				} else {
					$name=~s/^\*/\$/;
				}
			} else {
				$name='$'.$name;
			}
			$item_hash->{df_path}=$name;
			$item_hash->{df_defd}=\do{my$x=1};
		} else {
			$self->_warn_msg("Unknown item $name in Seen(), ignoring.");
		}
	}
	return $self;
}

#
# resets object parameters
#
# Each parameter can be _reset by name or the words "ALL", with the
# exception of the STYLE CODEREFWARN and CODREFSTUB properties which
# are only changed when the "INIT" word is provided. Thus
# _reset("INIT ALL")
# will default _all_ attributes. The confusion with the INIT words is
# due to the class interface. It would be annoying to have to set the
# style each time you want to dump a variable.
sub coderef {
	my $self=shift;
	my $type=shift;
	Carp::confess("Unknown type $type!")
		unless $type=~/warn|stub/;
	my $val=$self->{"coderef_".$type};
	if (@_) {
		$self->{"coderef_".$type}=shift;
	}
	return $val;
}


sub _reset {
	my $self = shift->_self_obj;
	my $opts = lc(shift) || "all";


	$self->{coderef_warn} = "Carp::cluck('Using deparsed coderef');"
	    if $opts && $opts =~ /\b(?:codref_warn|init)\b/i;
	$self->{coderef_stub} = "sub { Carp::cluck('Using coderef stub') }"
	    if $opts && $opts =~ /\b(?:coderef_stub|init)\b/i;
	$self->{dump_style} = "" if $opts && $opts =~ /\b(?:style|init)\b/i;

	$self->{cataloged}=0 if $opts && $opts =~ /\b(?:all|cataloged)\b/i;
	$self->{id} = 0 if $opts && $opts =~ /\b(?:all|seqnum)\b/i;
	$self->{queue}    = [] if $opts && $opts =~ /\b(?:all|queue)\b/i;
	$self->{refs}     = {} if $opts && $opts =~ /\b(?:all|refs)\b/i;
	$self->{scalars}  = {} if $opts && $opts =~ /\b(?:all|scalars)\b/i;
	$self->{reqs}     = {} if $opts && $opts =~ /\b(?:all|reqs)\b/i;
	$self->{fix}      = [] if $opts && $opts =~ /\b(?:all|fix)\b/i;
	$self->{name_ids} = {} if $opts && $opts =~ /\b(?:all|name_ids)\b/i;
	$self->{names}    = [] if $opts && $opts =~ /\b(?:all|names)\b/i;
	$self->{vars}     = [] if $opts && $opts =~ /\b(?:all|vars)\b/i;
	return $self;
}
#
# Capture. A utility sub to enable arrays to contain actual variables
# and not copies

sub capture {
	my $self = shift;
	return \@_;
}

#
# _report : Produces a text grid report of the passed bf_catalog hashes
#

sub _report {
	my $self   = shift->_self_obj;
	my $title  = 0;
	my @values = @_;
	my @f      = qw(
	    id name rid prid reftype type class globname gc
	    bf_depth bf_path df_depth df_defd df_path
	    hns sr +sr in +in orefs +orefs oscalars out +out root in_ids);

	my @w = map { 0 } @f;
	no warnings;

	foreach my $hash ( grep { ref $_ } @values ) {
	    foreach my $i ( 0 .. $#f ) {
			$w[$i] = length( $hash->{ $f[$i] } )
			    if $w[$i] <= length( $hash->{ $f[$i] } );
	    }
	}
	my $return;
	@f = map { $w[$_] > 0 ? $f[$_] : () } 0 .. $#f;
	@w = map { $_ ? $_ < 3 ? 3 : $_ : () } @w;
	my $pattern = "%-" . join ( "s | %-", @w ) . "s\n";
	$return = sprintf $pattern, map { substr $f[$_], 0, $w[$_] } 0 .. $#f;
	( my $t = $pattern ) =~ s/\|/+/g;
	my $divider = sprintf $t, map { "-" x $_ } @w;
	$return .= $divider;

	foreach my $hash (@values) {
	    if ( ref $hash ) {
			$return .= sprintf $pattern, @$hash{@f};
	    } elsif ( $hash eq '-' ) {
			$return .= $divider;
	    } else {
			$return .= sprintf $t, $hash, map { "?" x $_ } @w[ 0 .. $#w - 1 ];
	    }
	}

	$return .= $divider . "\n";
	return wantarray ? ($return) : defined(wantarray) ? $return : print $return;
}

#
# Report : Collects the two branches (scalars / refs) into one and then calls _report


sub report {
	my $self = shift->_self_obj;


	my @refs = map {
	    my $v = $self->{refs}{$_};
	    if ( ref($v) ) {
			$v = {%$v} if ref $v;
			$v->{rid} = $_ if !$v->{rid};
			$v->{in_ids} = join " ", keys %{ $v->{in_id} };
			$v->{df_defd} = $v->{df_defd} ? ${$v->{df_defd}} : 0;
	    }
	    $v || $_;
	} sort {
		$self->{refs}{$b}{in}<=>$self->{refs}{$a}{in}
		||
		$self->{refs}{$a}{id}<=>$self->{refs}{$b}{id}
	} keys %{ $self->{refs} };

	my @scalars = map {
	    my $v = $self->{scalars}{$_};
	    if ( ref($v) ) {
			$v = {%$v} if ref $v;
			$v->{rid} = $_ if !$v->{rid};
			$v->{in_ids} = join " ", keys %{ $v->{in_id} };
			$v->{df_defd} = $v->{df_defd} ? ${$v->{df_defd}} : 0;
	    }
	    $v || $_;
	} keys %{ $self->{scalars} };
	$self->_report( @refs, (@scalars) ? '-' : (), @scalars );
}

#
# Does a more complicated ref and extracts the underlying type
# as well as class, and does some catagorization. Knows

sub uber_ref {
	my $self = shift;
	my @ret;
	if ( defined $_[0] ) {
		my $ref = ref( $_[0] );
		if ($ref) {
		    my $sv = overload::StrVal( $_[0] );
		    if ( my ( $class, $reftype, $rid ) =
				( $sv =~ /^(?:([^=]+)=)?([A-Z]+)\(0x([^)]+)\)$/ ) )
		    {
				$class = "" unless $class;
				my $rid = 0 + $_[0];
				my $type;
				if ( "Regexp" eq $class && "SCALAR" eq $reftype ) { $type = "REGEXP"; }
				elsif ( $class eq $ref ) { $type = "OBJ"; }
				else { $type = $ref; }
				$class = "" if ( "Regexp" eq $class && "SCALAR" eq $reftype );
				@ret = ( $reftype, $rid, $type, $class );
		    } else {
				die "Can't parse " . $self->quote($sv);
		    }
		} else {
		    my $ref_v = \$_[0];
		    my ( $rtype, $rid ) = $self->uber_ref($ref_v);
		    my $globname = ( $rtype eq "GLOB" ) ? "$_[0]" : "";
		    @ret = ( "", 0 + $ref_v, $rtype, "", $globname );
		}
    } else {
		@ret = ( "", 0, 'undef' );
    }
	$ret[4] =~ s/main::// if $ret[4];
	return wantarray ? @ret : $ret[0];
}

#
# glob_data : takes a glob and returns its name and its defined parts in THING => $ref form
#

sub glob_data {
	my ( $s, $g ) = @_;

	if ( ref($g) ) {
	    die "Not expecting a reference!";
	} elsif ( ref( \$g ) ne "GLOB" ) {
	    warn "\t" . ref( \$g ) . "is not a GLOB\n" if DEBUG == 10;
	    return;
	}

	( my $name = "$g" ) =~ s/^\*main::/*::/;
	return $name unless wantarray;
	my %globhash;
	foreach my $thing (qw( SCALAR HASH ARRAY CODE)) {    # CODE IO GLOB # leave these out
	    my $v = *$g{$thing};
	    next unless defined *$g{$thing};
	    next if "SCALAR" eq $thing && !defined $$v;
	    $globhash{$thing} = $v;
	}
	return ( $name, %globhash );
}

#
# Sorts the keys of a hash. Needs optimizing. Should use [tye]s version.
#
# The sort order is something like dictionary order

sub _hashkey_sort {
	my $self = shift;
	my $hash = shift;
	my @keys = map { $$_[2] } sort {
	    defined $$a[0] && defined $$b[0] ? $$a[0] - $$b[0]
			|| $$a[1] cmp $$b[1] : !$$a[0]
			&& !$$b[0] ? $$a[1] cmp $$b[1] : !$$a[0]
			&& $$b[0] ? 1 : -1;
	    } map {
	    ( $b = lc ) =~ s/[^a-z]//g;
	    [ /^\s*(0|-?[1-9]\d{0,8})?/, $b || "", $_ ];
	    } keys %$hash;
	return wantarray ? @keys : \@keys;
}

sub _get_item_hash {
	my ( $self, $rid, $reftype ) = @_;
	die "No rid" unless defined($rid);
	my ( $refs, $scalars ) = @$self{ 'refs', 'scalars', };
	if (wantarray) {
	    return ( $refs->{$rid}, $scalars->{$rid} );
	} else {
	    return $reftype ? $refs->{$rid} : $scalars->{$rid};
	}
}

sub _recurse_percolate_up {
	my ( $self, $i, $o,$sr,$orefs, $item, $seen ) = @_;
	$item->{'+in'}  += $i;
	$item->{'+out'} += $o;
	$item->{'+sr'} += $sr;
	$item->{'+orefs'} += $orefs;
	my @keys;    #keys %{$item->{in_id}};
	push @keys, $item->{prid} if $item->{prid};
	foreach my $rid (@keys) {
	    my ( $r, $s ) = $self->_get_item_hash($rid);
	    if ( $r && !$seen->{ $r->{rid} }++ ) {
			$self->_recurse_percolate_up( $i, $o, $sr,$orefs,$r, $seen );
	    }
	    if ( $s && !$seen->{ $s->{rid} }++ ) {
			$self->_recurse_percolate_up( $i, $o,$sr,$orefs, $s, $seen );
	    }
	}
}

sub _percolate_up {
	my $self = shift;
	my $item = shift;
	my ( $in, $out,$sr,$orefs ) = @{$item}{ 'in', 'out','sr','orefs' };
	$self->_recurse_percolate_up( $in || 0, $out || 0,$sr || 0,$orefs || 0, $item, {} );
}

#
# _bf_register this is basically a co-routine to bf_catalog.
# This routine handles adding the object to the apropriate
# catalog, keeping track of how many times it has been mentioned
# and more importantly enqueing the items for bf_catalog to descend
# into.

sub _bf_register {
	my ( $self, $obj, $path, $depth, $from, $nofollow ) = @_;
	$from = {} unless $from;
	my ( $reftype, $rid, $type, $class, $globname ) = $self->uber_ref( $_[1] );
	my ( $queue, $refs, $scalars ) = @$self{
	    qw(queue refs scalars)
	};

	my $index = ($reftype) ? $refs : $scalars;
	$from->{ "o" . ( ($reftype) ? "refs" : "scalars" ) }++;
	$from->{"out"}++;
	my $name = $globname || "";
	my $autoname =
	    "\$" . ( $reftype ? $type : "VAR" ) . ( ++$self->{name_ids}{ $reftype ? $type : "VAR" } );
	if ( $depth == 0 && $path ) {
		my $no_ref=($path=~/^\*/);
	    $path =~ s/^[\$\@\%\*]//;
	    if ($name) {
			$path = '*' . $path;
	    } elsif($no_ref) {
	    	$path=($reftype eq "HASH") ? '%'.$path :
	    	      ($reftype eq "ARRAY") ? '@'.$path : '$'.$path;
	    } else {
			$path = '$' . $path;
	    }
	    $name = $path;
	} elsif ( $depth == 0 ) {
	    $path = $autoname;
	    $name = $path;
	} elsif ( !$path ) {
	    die "Weird. No path at depth>0";
	}

	unless ( exists $index->{$rid} ) {
	    my $ref = {
			id        => ++$self->{id},
			bf_path   => $path,
			bf_depth  => $depth,
			rid       => $rid,
			reftype   => $reftype,
			type      => $type,
			name      => $name,
			globname  => $globname,
			class     => $class,
			prid      => $from->{'rid'}  || "R",
			root      => $from->{'root'} || $rid,
			reference => \$_[1],
			df_path   => undef,
			df_depth  => undef,
			in        => 1,
	    };

	    if ( !$ref->{bf_path} && $depth == 0 ) { $ref->{bf_path} = $ref->{name}; }
	    return if (!$reftype && $depth>0 && !$globname);
    	$index->{$rid} = $ref;
	    push @$queue, $ref
			if ( !$nofollow && $reftype ) || $globname;
	} else {
	    warn "No rid!" unless defined $index->{$rid}{rid};
	    $index->{$rid}{in}++;
	    $from->{sr}++ if $index->{$rid}{root}==$from->{root};
	    # HasNamedScalar
	}
	if ( defined $from->{rid} ) {

	    $index->{$rid}{in_id}{ $from->{rid} }++;
	    $from->{hns}++ if !$index->{$rid}{reftype} && $index->{$rid}{name} && $index->{$rid}{type} ne 'GLOB';
	    $index->{$rid}{gc}++
	    	if !$from->{reftype} && $from->{type} eq "GLOB";
	} else {
	    $index->{$rid}{in_id}{R}++;
	}
	return $index->{$rid};
}

#
# bf_catalog : this does the breadth first traversal.
#

sub bf_catalog {
	my $self = shift->_self_obj;
	my $vars = shift || $self->{vars} || [];
	my $names = shift || [];
	$self->{cataloged}=1;
	my @ret;
	foreach my $i ( 0 .. @$vars - 1 ) {
	    push @ret, $self->_bf_register( $vars->[$i], $names->[$i], 0 );
	}
	my $queue = $self->{queue};
	while (@$queue) {
	    my $hash = shift @$queue;
	    my ( $rid, $reference, $reftype, $type, $depth, $path ) = @$hash{
			qw ( rid reference reftype type bf_depth bf_path )
			};
	    my $obj = $$reference;
	    if ( "SCALAR" eq $reftype ) {
			$self->_bf_register( $$obj, "\${$path}", $depth + 1, $hash );
	    } elsif ( "GLOB" eq $reftype ) {
			$self->_bf_register( $$obj, "\${$path}", $depth + 1, $hash );
	    } elsif ( "ARRAY" eq $reftype ) {
			foreach ( 0 .. @$obj - 1 ) {
			    $self->_bf_register( $obj->[$_], $path . "->[" . $_ . "]", $depth + 1, $hash );
			}
	    } elsif ( "HASH" eq $reftype ) {
			my $keys = $self->_hashkey_sort($obj);
			foreach (@$keys) {
			    $self->_bf_register( $obj->{$_}, $path . "->{" . $_ . "}", $depth + 1, $hash );
			}
	    } elsif ( "GLOB" eq $type ) {
			my ( $glob, %children ) = $self->glob_data($obj);
			while ( my ( $thing, $ref ) = each %children ) {
			    $self->_bf_register( $ref, $glob . "{" . $thing . "}", 1, $hash );
			}
	    } else {
			warn "Passing through $reftype,$type\n" if DEBUG;
			next;
	    }
	}

	#$self->report;
	foreach my $item ( values %{ $self->{scalars} }, values %{ $self->{refs} } ) {

	    #next unless $item->{prid};
	    $self->_percolate_up($item);
	}

	$self->report if DEBUG;
	my $testval = $self->style eq "Dumper" ? -1 : 1;
	foreach my $rid ( keys %{ $self->{scalars} } ) {

	    if (
			(
			    exists( $self->{refs}{$rid} )
			    && ( $self->{scalars}{$rid}{in} <= $self->{refs}{$rid}{in} )
			)
			|| !exists( $self->{refs}{$rid} )
			)
	    {
			next if ( $self->{scalars}{$rid}{name} && $self->{scalars}{$rid}{in} > $testval )
			;# || $self->{scalars}{$rid}{globname};

			print "Deleting $rid\n" if DEBUG;
			$self->{scalars}{$rid}{name} = "";
			delete $self->{scalars}{$rid};
	    }
	}
	return @ret;
}

#
# We do this to prevent a warning from occuring more than 1 time
#
STATIC: {
	my %warnings;

	sub _warn_msg {
	    my $self = shift;
	    my $msg = "Warning:" . join ( "", @_ );
	    unless ( $warnings{$msg}++ ) {

			#only warn once
			warnings::warnif $msg;
	    }
	}
}

sub style {
	my $self = shift->_self_obj;
	$self->{dump_style} = shift if (@_);
	return $self->{dump_style} || "";
}

sub _add_arrow {
	my $self=shift;
	my $path=shift;
	$path.='->' if $path=~/\A(\*[^\{]+\{\w+\}|\$(?:\w+|\{.*}))\z/;
	return $path
}

sub _df_dump_code {
	my $self = shift;
	my $obj  = shift;
	my $lm   = shift;
	return $self->{coderef_stub}
	    if $self->{no_deparse};

	my $body;
	my $deparse = B::Deparse->new( "-p", "-sC" );
	eval( '
    	$body = $deparse->coderef2text($obj);
    ' );
	if ( !$@ ) {
    	my $pat=quotemeta($self->{coderef_warn}||"");
    	if ($body!~/$pat/) {
			$body =~ s/(\n\s+)/$1.($self->{coderef_warn}||"").$1/e;
		}
	} elsif ( $@ =~ /^\QUsage: ->coderef2text(CODEREF)\E/ ) {
	    $self->_warn_msg(
			"You probably have a minor bug in your B::Deparse. \n"
			    . "Try modifing the method 'coderef2text' so that \n"
			    . "\tunless ref (\$sub) eq \"CODE\"';\n"
			    . "reads instead:\n"
			    . "\tunless UNIVERSAL::isa(\$sub,\"CODE\");\n"
			    . "Trying a risky workaround...\n\n" );

	    #So now we temporarily bless the object as a CODE
	    my $class = ref $obj;
	    bless $obj, "CODE";
	    eval( '
		    	$body = $deparse->coderef2text($obj);
		    ' );

	    # And then rebless it as whatever...
	    bless $obj, $class;
	    if ( !$@ ) {
	    	my $pat=quotemeta($self->{coderef_warn}||"");
	    	if ($body!~/$pat/) {
				$body =~ s/(\n\s+)/$1.($self->{coderef_warn}||"").$1/e;
			}
	    } else {
			$self->_warn_msg("Failed workaround. ($@) Using code stub\n");
			$body = $self->{coderef_stub};
	    }
	} else {
	    $self->_warn_msg("Error deparsing. Using code stub\n");
	    $body = $self->{coderef_stub};
	}

	my $indent = " " x ( $lm + 4 );
	$body =~ s/\n/\n$indent/g;
	$body = "sub {$body}" unless $body =~ /^\s*sub \{|^\s*\{/;
	$body = "sub " . $body unless $body =~ /^\s* sub/;
	return $body;
}

sub _df_dump_array {
	my ( $self, $hash, $obj, $defined, $path, $fix, $seen, $depth, $lm ) = @_;

	my ($start,$end);
	if ($path =~s/^\@/\$/) {
		($start,$end)=("(",")");
	} else {
		$start=($hash->{hns})? "Data::BFDump->capture(":'[';
		$end=($hash->{hns})? ")":']';
		$path=$self->_add_arrow($path);
	}
	my @ret;

	for my $i ( 0 .. $#$obj ) {
	    my ( $ret, $fixhash ) = $self->_df_dump(
			$obj->[$i], $defined,   $path . "[" . $i . "]", $fix,
			$seen,      $depth + 1, $lm + IWIDTH
	    );    # TODO Constant
	    if ($fixhash) {
			push @$fix, [ "F", $path . "[" . $i . "]", $fixhash ];
	    }
	    push @ret, $ret;
	}
	unless (@ret) {
		($start,$end)=("[","]") if $start=~/^Data::/;
		return "$start$end";
	}
	tie my ($lines), 'Tie::Scalar::Data::BFDump::Lines', COLWIDTH;

	foreach my $itm_num (0..$#ret) {
		my $itm=$ret[$itm_num];
	    $lines = ($self->{show_index} && @ret>1 ? "# $itm_num\n" : "").$itm . ", ".($self->{show_index} && $itm_num ne $#ret ? "\n" : "");
	}
	my $final = $lines;    #lose the tie;
	$final =~ s/,\s*\z//;
	$final =~ /\n/ && ( $final = "\n" . $final );
	my $ind = ( " " x ( $lm + IWIDTH ) );
	$final =~ s/\n(?!$ind)/"\n".$ind/gem;
	$self->{reqs}->{"Data::BFDump"}++ if $hash->{hns};

	$final = "$start $final";
	$final .= ( $final =~ /\n/ ) ? "\n$end" : " $end";
	return $final;
}



sub _df_dump_hash {
	my ( $self, $hash, $obj, $defined, $path, $fix, $seen, $depth, $lm ) = @_;
	my @ret;


	my @keys = map { [ $_, $self->quote_key($_) ] } $self->_hashkey_sort($obj);
	my ($start,$end);
	if ($path=~s/^\%/\$/) {
		($start,$end)=("(",")");
	} else {
		($start,$end)=("{","}");
		$path=$self->_add_arrow($path);
	}
	return ("$start$end") unless @keys;
	my $max_width = length($keys[0][1]);
	my $min_width = length($keys[0][1]);
	my $sum_width = 0;
	foreach my $k (@keys) {
		my $sum_width += length($k->[1]);
		if ( $max_width < length( $k->[1] )) {
	    	$max_width = length( $k->[1] );
	    } elsif ($min_width > length( $k->[1] )) {
	    	$min_width = length( $k->[1] )
	    }
	    my ( $ret, $fixhash ) = $self->_df_dump(
			$obj->{ $k->[0] }, $defined,   $path . "{" . $k->[1] . "}", $fix,
			$seen,             $depth + 1, $lm + IWIDTH
	    );
	    if ($fixhash) {
			push @$fix, [ "F", $path . "{" . $k->[1] . "}", $fixhash ];
	    }
	    push @ret, [ $k->[1], $ret ];
	}
	my $width=$max_width;
	if ( $max_width-$min_width > MKEYINDENT ) {
		my $avg_width=int($sum_width/@keys);
		if ( $avg_width > MKEYINDENT ) {
	    	$width = MKEYINDENT+$min_width;
	    } else {
	    	$width = $avg_width;
	    }
	}
	@ret = map {
	    $_->[1] =~ s/\n/"\n".(" " x ($width+4))/ge;
	    sprintf( "%-${width}s => %s", @$_ );
	} @ret;
	my $nl = "\n" . ( " " x ( $lm + IWIDTH ) );

	if ( @ret > 1 ) {
	    return ( $start . $nl . join ( "," . $nl, @ret ) . "\n" . ( " " x $lm ) . $end );
	} elsif ( @ret == 1 ) {
	    return ("$start @ret $end");
	} else {
	    return ("$start$end}");
	}
}

sub _df_dump_scalar_ref {
	my ( $self, $hash, $obj, $defined, $path, $fix, $seen, $depth, $lm ) = @_;
	my $return;
	my $scalars = $self->{scalars};
	if ( my $shash = $scalars->{ $hash->{rid} } ) {
	    if ( $shash->{df_defd} && ${ $shash->{df_defd} } ) {
			$return = "\\" . $shash->{df_path};
	    } else {

			#$shash->{df_path} = undef unless exists $shash->{df_path};
			push @$fix, [ "F", $path, undef, $shash ];

			#print ".....\n";
			# Todo? When blessed?
			$return = "'forward_scalar'";
	    }
	} elsif ( $hash->{type} eq "REGEXP" ) {
	    $return = $self->quote_regexp($obj);
	} else {
	    my ( $ret, $fixhash ) =
			$self->_df_dump( $$obj, $defined, "\${" . $path . "}", $fix, $seen, $depth + 1, $lm );
	    if ($fixhash) {
			push @$fix, [ "F", $hash, undef, $fixhash ];
			return ($ret);
	    }
	    unless ( $ret =~ /\A\s*[\$\@\%\*]/ ) {
			my $lstr = "\\do { my \$itm = ";
			$ret =~ s/\n/"\n".(" " x length($lstr))/ge;
			$return = $lstr . $ret . " }";
	    } else {
			$return = "\\" . $ret;
	    }
	}
	return $return;
}

sub _df_dump {
	my $self = shift;
	my ( $obj, $defined, $path, $fix, $seen, $depth, $lm ) = @_;
	my ( $reftype, $rid, $type, $class, $globname ) = $self->uber_ref( $_[0] );
	my ( $refs, $scalars ) = @$self{ 'refs', 'scalars', };

	my $hash = $self->_get_item_hash( $rid, $reftype );

	# We may not have a have a hash for this item if it is an
	# unreferenced scalar
	if ($hash) {

	    #Carp::carp("$reftype, $rid,$obj");

	    if ( $hash->{df_path} && ${ $hash->{df_defd} } ) {
	    	if ($hash->{df_path}=~/^[\@\%]/) {
	    		return ( "\\".$hash->{df_path});
	    	} else {
				return ( $hash->{df_path} );
			}
	    } elsif ( $hash->{df_path} || $hash->{bf_depth} < $depth ) {
			my $str = $hash->{df_path} || $hash->{bf_path};
			$str = $str || "forward_ref";
			return ( "'$str'", $hash );
	    }
	    if ( !$path && $hash->{bf_depth} == 0 ) {
			$path = $hash->{name};
	    }
	    Carp::confess "No Path! ( $reftype, $rid, $type, $class, $globname )"
			. Data::Dumper::Dumper($hash)
			unless $path;

	    die "Seen $rid!" if $seen->{$rid}++;
	    $hash->{df_path} = $path || $hash->{name};
		$hash->{df_defd}  = $defined unless $hash->{df_defd};
	    $hash->{df_depth} = $depth;
	}

	unless ($reftype) {

	    # Scalar?
	    return ('undef') if $type eq 'undef';
	    return ( $self->quote("$obj") )
			if ( $type eq "SCALAR" );

	    # Glob..
	    my ( $glob, %children ) = $self->glob_data($obj);
	    my @tmp_fix;

	    while ( my ( $thing, $ref ) = each %children ) {
	    	if (DEBUG) {
	    		print "Before $glob $thing\n";
	    		$self->report;
	    	}
			my $temp_def = 0;
			my ( $ret, $fixhash ) =
			    $self->_df_dump( $ref, \$temp_def, $globname . "{" . $thing . "}", \@tmp_fix, $seen, 0,
			    0 );
			if ($fixhash) {
				print "$glob returned hash\n" if DEBUG;
			    push @tmp_fix, [ "F", $glob, undef, $fixhash ];
			} else {
				print "$glob returned $ret\n" if DEBUG;
			    push @{$self->{results}}, [ "F", $glob, $ret ];
			}
			$temp_def = 1;
	    }
	    push @$fix,@tmp_fix;
	    my $ret = "$obj";
	    if ( $ret =~ /::\$/ ) {
			$self->{req}{Symbol}++;
			return "Symbol::gensym()";
	    }
	    return ($ret);
	}
	die "!!!$reftype-$rid-$type-$class-$globname"
	    if DEBUG && !$hash;
	my $ret;
	if ( $reftype eq "SCALAR" or $reftype eq "GLOB" ) {
	    $ret =
			$self->_df_dump_scalar_ref( $hash, $_[0], $defined, $path, $fix, $seen, $depth, $lm );
	} elsif ( $reftype eq "ARRAY" ) {
	    $ret = $self->_df_dump_array( $hash, $_[0], $defined, $path, $fix, $seen, $depth, $lm );
	} elsif ( $reftype eq "HASH" ) {
	    $ret = $self->_df_dump_hash( $hash, $_[0], $defined, $path, $fix, $seen, $depth, $lm );
	} elsif ( $reftype eq "CODE" ) {
	    $ret = $self->_df_dump_code( $_[0], $lm );
	} else {
	    die "$reftype isn't implemented yet?..";
	}
	if ( $class and $ret =~ /^(?:[\\{[]|\s*sub)/ ) {
	    $ret =~ s/\n/"\n".(" "x6)/ge;
	    return ( "bless(" . $ret . "," . $self->quote($class) . ")" );
	} else {
	    return ($ret);
	}
}


sub df_dump {
	my ( $self, $hashes ) = @_;

	my @results;
	my @fix;

	if (DEBUG) {
		print "Dumping...\n";
		$self->report;
	}

	my @predeclare=sort { $b->{in} <=> $a->{in} && $b->{id} <=> $a->{id}}
				   (grep { !$_->{name} && $_->{in}>2 && !$_->{'sr'}&& !$_->{gc} }(values  %{$self->{refs}}),
				    #grep { $_->{type}eq 'GLOB'}(values  %{$self->{scalars}})
				    );
	my (@singles) = grep { $_->{'+in'} <= 1 } @$hashes;
	my (@mults)   = grep { $_->{'+in'} > 1 } @$hashes;
	$self->{results}=\@results;
	foreach my $hash (
		@predeclare,
	    (
			sort {
			    $a->{'+out'} <=> $b->{'+out'}
					|| $b->{'+in'} <=> $a->{'+in'}
					|| $a->{'id'} <=> $b->{'id'};
			} @mults
	    ),
	    @singles
	    )
	{
	    my %seen      = ();
	    my @myfix     = ();
	    my $path      = "";
	    my $depth     = 0;
	    my $lm        = 0;
	    next if ($hash->{df_defd} && ${ $hash->{df_defd} } );
	    if (!$hash->{name} && !$hash->{globname}) {
	    	$hash->{name}='$PRE_'. $hash->{type} . ( ++$self->{name_ids}{ "PRE_".$hash->{type} } );
	    }
	    my $defined   = 0;
	    my $as_string =
			$self->_df_dump( ${ $hash->{reference} }, \$defined, $hash->{name}, \@myfix, \%seen,
			$depth, $lm );
	    $defined = 1;
	    #print "defined=".${$hash->{df_defd}}."\n";

	    if ( $self->style eq 'Dumper' || ( $hash->{name} && ( $hash->{'+in'} > 1 || @myfix ) ) ) {
			$hash->{final} = $hash->{name};
			push @results, [ "R", $hash->{name}, $as_string ]
			    if $hash->{name} !~ /^\*/;
	    } else {
			$hash->{final} = $as_string;
	    }
	    push @fix, @myfix;
	    @fix = map {
			my $not_defined;

			foreach my $ref (@$_) {
			    next unless ref $ref;
			    do { $not_defined = 1; last }
					unless $ref->{df_defd} && ${ $ref->{df_defd} };
			}
			unless ($not_defined) {
			    push @results, $_;
			    ();
			} else {
			    $_;
			}
	    } @fix;
	}
	delete $self->{results};

	my $width = 0;
	foreach my $stmt ( @results, @fix ) {
	    if ( ref $stmt->[3] ) {
			$stmt->[2] = "\\" . $stmt->[3]->{df_path};
			pop @$stmt;
	    }

	    my $type = shift @$stmt;
	    if (ref $stmt->[1]) {
	    	$stmt->[1] = $stmt->[1]{df_path};
	    	$stmt->[1] = "\\".$stmt->[1]
	    		if ($stmt->[1]=~/^[\@\%]/);
	    }
	    if ( $type eq 'F' && ref $stmt->[0] ) {
			$stmt->[1] = "bless(" . $stmt->[1] . "," . $self->quote( $stmt->[0]{class} ) . ")"
			    if $stmt->[0]{class};
	    }
	    $stmt->[0] = $stmt->[0]{df_path}
			if ref $stmt->[0];
		#$stmt->[0] =~s/->$//;
	    if ( $type eq "R" ) {
			$stmt->[0] = "my " . $stmt->[0]
			    if $self->style ne "Dumper";
			$width = length( $stmt->[0] ) if $width < length( $stmt->[0] );
	    }
	}

	my @ret = map {
	    $_->[1] =~ s/\n/"\n".(" "x($width+3))/ge;
	    sprintf( "%-${width}s = %s", @$_ );
	} @results, @fix;
	my $final = "";
	if ( @$hashes > 1 ) {
	    tie my ($final_lines), 'Tie::Scalar::Data::BFDump::Lines', COLWIDTH;
	    foreach (@$hashes) {
			$final_lines = $_->{final} . ", ";
			#delete $_->{final};
	    }
	    $final = $final_lines;    #lose the tie;
	    $final =~ s/,\s*\z//;                            #rtrim
	    $final =~ /\n/ && ( $final = "\n" . $final );    #add a newline
	    $final =~ s/\n/"\n".(" " x 4)/ge;                #add indentation
	    $final = "( " . $final;                          #
	    $final .= ( $final =~ /\n/ ) ? "\n)" : " )";
	} elsif ( @$hashes == 1 ) {
	    $final = $hashes->[0]->{final};
	    delete $hashes->[0]->{final};
	} else {
	    $final = '()';
	}
	push @ret, $final unless $self->style eq 'Dumper';
	my $ret = join ( ";\n", @ret );
	$ret .= ";\n" if $self->style eq 'Dumper';
	if ( @ret > 1 && $self->style ne 'Dumper' ) {
	    $ret =~ s/^/\t/gm;
	    $ret = "do{\n$ret;\n}\n";
	}
	return $ret;
}


sub Dump {
	my $self = shift->_self_obj;
	my @ret;
	if (@_) {
		my ( $vars, $names ) = (shift(@_),shift(@_));
		$names=[] unless $names;
		$self->_reset("All");
		Carp::croak "Usage:Data::BFDump->Dump(ARRAYREF, [ARRAYREF])\n"
	    	if ( ref $vars ne "ARRAY" ) || ( $names && ref $names ne "ARRAY" );
		return "()" unless @$vars;
		@ret = $self->bf_catalog( $vars, $names );
		$self->{cataloged}=\@ret;
		$self->report if (@_ and $_[0]=~/devtest/i);
	} elsif (!$self->{cataloged}) {
		Carp::croak "Usage:Data::BFDump->Dump(ARRAYREF, [ARRAYREF])\n";
	} else {
		@ret = @{$self->{cataloged}};
	}
	return "()" unless @ret;
	my $ret = $self->df_dump( \@ret );
	return $ret;
}

sub Dumper {
	return Data::BFDump->Dump( \@_ );
}


sub _context_diff {
	my ( $self, $str1, $str2, $title1, $title2 ) = @_;
	$title1 ||= "BFDump";
	$title2 ||= "Dumper";
	# TODO:
	# Eventually id like this to take "sections"
	# meaning have df_dump create a huge array of snippets of code
	# perhaps with only minimal additional formatting and perl punctuation
	# then diff the array. Ah well for another day

	#print $str1,"\n---\n",$str2;
	my @seq1 = split /\n/, $str1;
	my @seq2 = split /\n/, $str2;

	# im sure theres a more elegant way to do all this as well
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
	#especially this bit.
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

1;
#
# ! Replace with overload semantics and itll work out !
#

package Tie::Scalar::Data::BFDump::Lines;

sub TIESCALAR {
	my $classname = shift;
	my $width     = shift || 70;

	my $obj = bless [$width], $classname;
	$obj->STORE( join ( "", @_ ) ) if @_;
	return $obj;
}

sub FETCH {
	my $self = shift;
	return join ( "\n", @$self[ 1 .. $#$self ] );
}

sub STORE {
	my ( $self, $value ) = @_;
	chomp $value;
	if ( $value =~ /\n/ ) {
	    push @$self, $value;
	} else {
	    push @$self, "" if @$self == 1;
	    my $str = $self->[-1] . $value;
	    if ( length($str) < $self->[0] ) {
			$self->[-1] = $str;
	    } else {
			push @$self, $value;
	    }
	}
}
"9. Are you mathematically inclined?
    If math is all Greek to you, go to step 11;
    otherwise proceed to step 10.";
__END__




=head1 NAME

Data::BFDump - Class for dumping data structures in Breadth First order.

=head1 VERSION

Version '0.3'

=head1 SYNOPSIS

  use Data::BFDump;

  my $somevar=Some::Class->new();

  Data::BFDump->Dump([$somevar]);
  Data::BFDump->report;

  my $dumper=Data::BFDump->new();
  $dumper->Dump([$somevar]);
  $dumper->report;

=head1 DESCRIPTION

Data::BFDump is intended to be used for interpreting and understanding a data
structure.  Where L<Data::Dumper|Data::Dumper> and L<Data::Dump|Data::Dump> do
a depth first traversal of a data structure, B<Data::BFDump> does a breadth
first traversal. Often this produces a more intuitive looking structure as it
ensures that a given sub element will be first mentioned or displayed at a
position where its "path" from the root will be as short as possible.

=head1 WHEN TO USE THIS MODULE

This module is primarily design for dumping data structures so a developer can
read them and understand them, in other words for analytical purposes.  If you
are looking for a dumping module for persistancy purposes this module is not
ideal (although there is no reason you can't use it) as it will consume more memory
and will be slower than everything else out there.  On the other hand for
particularly insane data structures it is my intention that this module shall
be as accurate (see L<MUTABILITY>) as it comes.

=head2 MUTABILITY

Currently Data::BFDump will df_dump the data structure in such a way that it is as
mutable as possible.  This means that all references to string constants are treated
as references to variables equivelent to the string constant.  If I can find a useful
way to determine if a reference is indeed to an unmutable constant then I may change
this behaviour.

B<NOTE> L<Data::Dumper|Data::Dumper> seems to behave in the opposite manner. References
to variables containing a string constant are treated as references to a string constant
meaning that some parts of an evaled df_dump end up being unmutable.  This approach is however
more attractive and simpler to understand.

=head2 Whats the difference to Data::Dumper?

Data::BFDump was written to make figuring out complicated data structures
easier.  Where Data::Dumper will descend as far into the data structure
as possible BFDump ensures that an object is declared as close to root as
possible. What does this mean?  Well consider a class that models a collection
of people and their friends, like this

	package Person;
	use strict;

	our %People;

	sub population { \%People };
	sub name  { $_[0]->[0] }
	sub named { $People{$_[1]} }

	sub new {
		my $class = shift;
		my $name  = shift;
		# There can only be one person with any given name
		$People{$name}=bless [ $name , {} ],$class
			unless $People{$name};
		return $People{$name}
	}

	sub made_friend {
		my $self  =shift;
		my $friend=shift;
		$self->[1]->{$friend->name}=$friend;
		return $self;
	}
	1;

The hash %People stores all the people in the population keyed
by name.  Each person is represented as a blessed array containing
their name, and a hash containing their friends names and references to them.
(Admittedly this example is a bit contrived :-)  So if we add in a little
code to make some people and relationships like so

	my @names=("A".."D");
	for my $name (@names) {
		my $obj=Person->new($name);
	}
	for my $i (1..10) {
		Person->named($names[rand @names])->made_friend(Person->named($names[rand @names]));
	}

So now we want look at the population, which if we df_dump using Data::Dumper will produce something
like the following deeply nested and (IMO) confusing example.

	$VAR1 = {
	          'A' => bless( [
	                          'A',
	                          {
	                            'C' => bless( [
	                                            'C',
	                                            {
	                                              'A' => []
	                                            }
	                                          ], 'Person' ),
	                            'D' => bless( [
	                                            'D',
	                                            {
	                                              'A' => [],
	                                              'B' => bless( [
	                                                              'B',
	                                                              {
	                                                                'B' => [],
	                                                                'C' => [],
	                                                                'D' => []
	                                                              }
	                                                            ], 'Person' ),
	                                              'C' => []
	                                            }
	                                          ], 'Person' )
	                          }
	                        ], 'Person' ),
	          'B' => [],
	          'C' => [],
	          'D' => []
	        };
	$VAR1->{'A'}[1]{'C'}[1]{'A'} = $VAR1->{'A'};
	$VAR1->{'A'}[1]{'D'}[1]{'A'} = $VAR1->{'A'};
	$VAR1->{'A'}[1]{'D'}[1]{'B'}[1]{'B'} = $VAR1->{'A'}[1]{'D'}[1]{'B'};
	$VAR1->{'A'}[1]{'D'}[1]{'B'}[1]{'C'} = $VAR1->{'A'}[1]{'C'};
	$VAR1->{'A'}[1]{'D'}[1]{'B'}[1]{'D'} = $VAR1->{'A'}[1]{'D'};
	$VAR1->{'A'}[1]{'D'}[1]{'C'} = $VAR1->{'A'}[1]{'C'};
	$VAR1->{'B'} = $VAR1->{'A'}[1]{'D'}[1]{'B'};
	$VAR1->{'C'} = $VAR1->{'A'}[1]{'C'};
	$VAR1->{'D'} = $VAR1->{'A'}[1]{'D'};

the statements at the end (which I refer to as 'fix statements') are
eye-straining to say the least.  Whereas BFDumper will produce something a little more
intuitive like this

	do{
		my $HASH1             = {
		                             A => bless([
		                                             'A',
		                                             {
		                                                  C => '$HASH1->{C}',
		                                                  D => '$HASH1->{D}'
		                                             }
		                                   ],'Person'),
		                             B => bless([
		                                             'B',
		                                             {
		                                                  B => '$HASH1->{B}',
		                                                  C => '$HASH1->{C}',
		                                                  D => '$HASH1->{D}'
		                                             }
		                                   ],'Person'),
		                             C => bless([ 'C', { A => '$HASH1->{A}' } ],'Person'),
		                             D => bless([
		                                             'D',
		                                             {
		                                                  A => '$HASH1->{A}',
		                                                  B => '$HASH1->{B}',
		                                                  C => '$HASH1->{C}'
		                                             }
		                                   ],'Person')
		                        };
		$HASH1->{A}->[1]->{C} = $HASH1->{C};
		$HASH1->{A}->[1]->{D} = $HASH1->{D};
		$HASH1->{B}->[1]->{B} = $HASH1->{B};
		$HASH1->{B}->[1]->{C} = $HASH1->{C};
		$HASH1->{B}->[1]->{D} = $HASH1->{D};
		$HASH1->{C}->[1]->{A} = $HASH1->{A};
		$HASH1->{D}->[1]->{A} = $HASH1->{A};
		$HASH1->{D}->[1]->{B} = $HASH1->{B};
		$HASH1->{D}->[1]->{C} = $HASH1->{C};
		$HASH1;
	}

Here objects are printed out at the level that they are first mentioned, the fact that there is
a collection of objects which are themselves interlinked, and the precise nature of that linkage
is much easier to discern.

=head2 Funky Stuff

Data::BFDump can use the B::Deparse module to df_dump coderefs if they are present in your data.  In
fact this is currently the default behaviour.

=head2 So whats the catch?

Data::Dumper is faster and (currently :-) better tested and more flexible than Data::BFDump.
Furthermore Data::BFDump necessarily has to make a parallel datastructure for anything it has to df_dump.
This takes time and memory.  On the other hand this extra pass allows Data::BFDump to be more precise
than Data::Dumper in some situations, it also allows much more flexibility in terms of the way the data
is presented and offers potential for other analytical tools.  Unfortunately at present a lot of this is
unutilized.

However I do  intend to keep this module growing and to improve it as much as I can. I welcome
feedback, improvements, bug reports, fixes, and especially new tests. ;-)

=head2 Future Plans

Very very soon I will be adding code to allow complicated data to be sliced up in such a way as to reduce
forward references.

Eventualy I want to be able to support the full interface of Data::Dumper as well as the current Data::Dump
style output.

=head1 CALLING CONVENTIONS

All of the documented methods (not new!) in DATA::BFDump can be called as an object method or as a class method.
In the case where a class method call needs access to object base state information a singleton is used.  Once created
this singleton will not be destroyed until program termination.  If you are dumping large data structures using
class methods then you may want to call

  Data::BFDump->init();

To release that memory.  OTOH this means that Data::BFDump->report; will work as expected.

If you create new dumper objects using new() and use them for your dumping you dont need to worry about the singleton.

=head1 METHODS

=head2 new()

Build a new object.  Currently does not support parameters.

=head2 init()

Initializes the dumper back to empty. Same as calling _reset('ALL')
Returns the object.

=head2 _reset()

Resets the object.  Eventually this will be able to _reset various subsets of object attributes at once. Currently
it should only be used with the parameter 'ALL', wherupon it completely _reset the internal state of the object

=head2 capture(LIST)

Captures a set of values inside of an array.  The interesting thing is that dumping the following

  Data::BFDump->capture($x,$y,$z,$x)
  [$x,$y,$z,$x]

Will produce different results! (The first will show that the same variable has been passed twice, whereas the second
will show that two variables with the same value had been passed. This is because the array returned will actually be a
reference to a @_ which has special magic associated with it.  This is the OO equivelent of

  sub capture{\@_};

Only provided for really weird analysis situations. (See merlyns Data::Dumper bug.)

=head2 uber_ref(ITEM)

This is an up market reference, that also identifies non references as well.  In list context it returns a 5 element list

  ($reftype, $rid, $type, $class, $globname)

In scalar context it returns $reftype alone.

=over 4

=item $reftype

The underlying type of the object.  This may be GLOB SCALAR ARRAY HASH or an empty string
for a non reference.

=item  $rid

For a reference this is the numeric representation of the reference. For a non reference it is the numeric
value of a reference to the given item. (Thus $id alone cannot tell you if you have a reference or not)

=item $type

This maybe be one of the following standard types GLOB SCALAR ARRAY HASH CODE REF, or one of the following special
types OBJ, REGEXP.  The result of a qr// will be a REGEXP and a blessed object will be an OBJ.

=item $class

If a reference is blessed than this value will hold the name of the package

=item $globname

If the item is a glob (not a reference to a GLOB!) then this value will hold its name.

=back

=head2 glob_data(GLOB)

Takes a glob (not a glob reference!) and returns a list containing the name of the glob followed by
name value pairs for each of its 'things'.  Things being its SCALAR, HASH, ARRAY and CODE elements.

  ($name,%things)=glob_data(*Foo);

=head2 Dump(ARRAYREF,[ARRAYREF])

Takes an array of values to df_dump and optionally an array of names to use for them. Currently the second
argument is unsupported.

=head2 report()

Once an object has been dumped using the Dump method this method will produce a report about the contents of the
data structure.  In list and scalar context returns the string of the report. In void context this printed
to the currently selected filehandle.

=head1 EXPORTS

=head2 Dumper(LIST)

Simpler version of the Dump() method that can be optionally exported.

=head1 DEPENDENCIES

Data::BFDump uses the following pragmas, packages and classes.

=over 4

=item Pragmas Used

L<strict|strict> L<warnings|warnings> L<warnings::register|warnings::register> L<vars|vars> L<constant|constant>
L<overload|overload>

=item Modules Used

L<Carp|Carp> L<Carp::Assert|Carp::Assert> L<B::Deparse|B::Deparse> L<Text::Quote|Text::Quote>

=back

=head1 TODO

More Pod

More Tests

Accessor methods for attributes.

Variable slicing.

More tests.

=head1 THANKS

Gurusamy Sarathy for Perl 5.6 and Data::Dumper.

Gisle Aas for lots of stuff not least being Data::Dump.

Dan Brook for testing and encouragement.

Perlmonks for being an awesome place to learn perl from.

=head1 AUTHOR

Yves Orton L<E<lt>demerphq@hotmail.comE<gt>>

=head1 COPYRIGHT

Yves Orton 2002 -- This program is released under the same terms as perl itself.

=head1 SEE ALSO

L<perl>

=cut



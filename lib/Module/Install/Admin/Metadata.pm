package Module::Install::Admin::Metadata;

use strict;
use YAML::Tiny ();
use Module::Install::Base;

use vars qw{$VERSION @ISA};
BEGIN {
	$VERSION = '0.81_01';
	@ISA     = 'Module::Install::Base';
}

sub read_meta {
	# Admin time means no eval is needed
	require YAML::Tiny;

	my $self = shift;
	my @docs = YAML::Tiny::LoadFile('META.yml');
	return $docs[0];
}

sub meta_generated_by_us {
	my $self = shift;
	my $need = shift;
	my $meta = $self->read_meta;
	my $want = ref($self->_top);
	if ( defined $need ) {
		$want .= " version $need";
	}
	return $meta->{generated_by} =~ /^\Q$want\E/;
}

sub remove_meta {
	my $self = shift;
	my $ver  = $self->_top->VERSION;
	return unless -f 'META.yml';
	return unless $self->meta_generated_by_us($ver);
	unless (-w 'META.yml') {
		warn "Can't remove META.yml file. Not writable.\n";
		return;
	}
	warn "Removing auto-generated META.yml\n";
	unless ( unlink 'META.yml' ) {
		die "Couldn't unlink META.yml:\n$!";
	}
	return;
}

sub write_meta {
	my $self = shift;
	if ( -f "META.yml" ) {
		return unless $self->meta_generated_by_us();
	} else {
		$self->clean_files('META.yml');
	}
	print "Writing META.yml\n";
	Module::Install::_write("META.yml", $self->dump_meta);
	return;
}

sub dump_meta {
	my $self = shift;
	my $pkg  = ref( $self->_top );
	my $ver  = $self->_top->VERSION;
	my $val  = $self->Meta->{values};

	delete $val->{sign};

	my $perl_version = delete $val->{perl_version};
	if ( $perl_version ) {
		$val->{requires} ||= [];
		my $requires = $val->{requires};

		# Issue warnings for unversioned core modules that are
		# already satisfied by the Perl version dependency.
		require Module::CoreList;
		my $corelist = $Module::CoreList::version{$perl_version};
		if ( $corelist ) {
			my @bad = grep { exists $corelist->{$_} }
			          map  { $_->[0]   }
			          grep { ! $_->[1] }
			          @$requires;
			foreach ( @bad ) {
				# print "WARNING: Unversioned dependency on '$_' is pointless when Perl minimum version is $perl_version\n";
			}
		}

		# Canonicalize to three-dot version after Perl 5.6
		if ( $perl_version >= 5.006 ) {
			$perl_version =~ s{^(\d+)\.(\d\d\d)(\d*)}{join('.', $1, int($2||0), int($3||0))}e
		}
		unshift @$requires, [ perl => $perl_version ];
	}

	# Set a default 'unknown' license
	unless ( $val->{license} ) {
		warn "No license specified, setting license = 'unknown'\n";
		$val->{license} = 'unknown';
	}

	# Most distributions are modules
	$val->{distribution_type} ||= 'module';

	# Check and derive names
	if ( $val->{name} =~ /::/ ) {
		my $name = $val->{name};
		$name =~ s/::/-/g;
		die "Error in name(): '$val->{name}' should be '$name'!\n";
	}
	if ( $val->{module_name} and ! $val->{name} ) {
		$val->{name} = $val->{module_name};
		$val->{name} =~ s/::/-/g;
	}

	# Apply default no_index entries
	$val->{no_index}              ||= {};
	$val->{no_index}->{directory} ||= [];
	SCOPE: {
		my %seen = ();
		$val->{no_index}->{directory} = [
			sort
			grep { not $seen{$_}++ }
			grep { -d $_ } (
				@{$val->{no_index}->{directory}},
				qw{ share inc t examples demo },
			)
		];
	}

	# Generate the structure we'll be dumping
	my $meta = {
		resources => {},
		license   => $val->{license},
	};
	foreach my $key ( $self->Meta_ScalarKeys ) {
		next if $key eq 'installdirs';
		next if $key eq 'tests';
		$meta->{$key} = $val->{$key} if exists $val->{$key};
	}
	foreach my $key ( $self->Meta_ArrayKeys ) {
		$meta->{$key} = $val->{$key} if exists $val->{$key};
	}
	foreach my $key ( $self->Meta_TupleKeys ) {
		next unless exists $val->{$key};
		$meta->{$key} = { map { @$_ } @{ $val->{$key} } };
	}
	$meta->{provides}     = $val->{provides} if $val->{provides};
	$meta->{author}     &&= [ $meta->{author} ];
	$meta->{no_index}     = $val->{no_index};
	$meta->{generated_by} = "$pkg version $ver";
	$meta->{'meta-spec'}  = {
		version => 1.4,
		url     => 'http://module-build.sourceforge.net/META-spec-v1.4.html',
	};
	unless ( scalar keys %{$meta->{resources}} ) {
		delete $meta->{resources};
	}

	# Support version.pm versions
	if ( UNIVERSAL::isa($meta->{version}, 'version') ) {
		$meta->{version} = $meta->{version}->numify;
	}

	YAML::Tiny::Dump($meta);
}





######################################################################
# MYMETA.yml Support

sub WriteMyMeta {
	my $self = shift;
	$self->configure_requires( 'YAML::Tiny' => 1.36 );
	$self->write_mymeta;
	return 1;
}

1;

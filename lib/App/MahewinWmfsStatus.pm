package App::MahewinWmfsStatus;

use Moose;

use Config::IniFiles;
use Sys::Statistics::Linux;
use Sys::Statistics::Linux::DiskUsage;

#ABSTRACT: To display information in a wmfs status bar

has _file_path => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_file_path'
);

has _user_infos => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_user_infos'
);

has _config => (
    is      => 'ro',
    isa     => 'Config::IniFiles',
    lazy    => 1,
    builder => '_build_config'
);

has _lxs => (
    is      => 'ro',
    isa     => 'Sys::Statistics::Linux',
    lazy    => 1,
    builder => '_build_lxs',
);

sub _build_file_path {
    if ( exists $ENV{HOME} && defined $ENV{HOME} ) {
        return $ENV{HOME};
    }

    if ( $ENV{LOGDIR} ) {
        return $ENV{LOGDIR};
    }

    return '';
}

sub _build_user_infos {
    my @infos;

    open( PASSWD, "< /etc/passwd" );
    while (<PASSWD>) {
        @infos = split /:/;
        last if $infos[0] eq $ENV{LOGNAME};
    }
    close(PASSWD);

    return \@infos;
}

sub _build_config {
    my ($self) = @_;

    my $home = $self->_file_path;

    Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc" );
}

sub _build_lxs {
    Sys::Statistics::Linux->new( memstats => 1, );
}

sub run {
    my ($self) = @_;

    my $timing = $self->_config->val( 'misc', 'timing' ) || 1;

    while (1) {
        print 'Salut', "\n";
        sleep($timing);
        $self->status();
    }
}

sub status {
    my ($self) = @_;

    my $cfg = $self->_config;
    my @call;

    my @sections = $self->_config->Sections();
    my $dispatch = {
        memory => $self->free(),
        disk   => $self->disk_space(),
        date   => $self->time_date(),
        name   => $self->name()
    };

    foreach my $section (@sections) {
        next if $section eq 'misc';

        $call[ $cfg->val( $section, 'position' ) ] = $dispatch->{$section}
          if $cfg->val( $section, 'display' );
    }

    `wmfs -c status "default @call"`;
}

sub free {
    my ($self) = @_;

    my $stat     = $self->_lxs->get;
    my $memfree  = $stat->memstats->{memfree};
    my $memused  = $stat->memstats->{memused};
    my $memtotal = $stat->memstats->{memtotal};

    my $format = $self->_config->val( 'memory', 'format' ) || 'string';

    return $format eq 'percent'
      ? $self->_stringify(
        'memory',
        sprintf( "%0.2f",
            int( $memused / 1024 ) / int( $memtotal / 1024 ) * 100 )
          . '%'
      )
      : $self->_stringify( 'memory',
        int( $memfree / 1024 ) . '/' . int( $memused / 1024 ) );
}

sub disk_space {
    my ($self) = @_;

    my $disk_usage = Sys::Statistics::Linux::DiskUsage->new(
        cmd => {

            # This is the default
            df => 'df -hP 2>/dev/null',
        }
    );

    my $stat = $disk_usage->get;

    my $format    = $self->_config->val( 'disk', 'format' )    || 'string';
    my $disk_path = $self->_config->val( 'disk', 'disk_path' ) || '/dev/sda1';

    my $disk = $self->_stringify( 'disk',
            'Disk: '
          . $stat->{$disk_path}->{usage} . '/'
          . $stat->{$disk_path}->{free} );

    if ( $format eq 'percent' ) {
        my @usage = split( /G/, $stat->{$disk_path}->{usage} );
        my @total = split( /G/, $stat->{$disk_path}->{total} );
        $usage[0] =~ s/,/./;
        $total[0] =~ s/,/./;

        my $disk_usage = sprintf( "%0.2f", $usage[0] / $total[0] * 100 );
        $disk = $self->_stringify( 'disk', $disk_usage . '%' );
    }

    return $disk;
}

sub time_date {
    my ($self) = @_;

    my $format = $self->_config->val( 'date', 'format' )
      || '%Y/%m/%d %H:%M:%S';

    $self->_lxs->settime($format);

    return $self->_stringify( 'date', $self->_lxs->gettime );
}

sub name {
    my ($self) = @_;

    my $infos = $self->_user_infos;
    my @name = split( /,/, $infos->[4] );

    return $self->_stringify( 'name', $name[0] );
}

sub _stringify {
    my ( $self, $type, $string ) = @_;

    my $cfg = $self->_config;

    my $color =
        $cfg->val( $type,  'color' )
      ? $cfg->val( $type,  'color' )
      : $cfg->val( 'misc', 'color' );
    my $label = ( $cfg->val( $type, 'label' ) // ucfirst($type) ) . ':';

    return "^s[right;$color; $label $string ]";
}

1;

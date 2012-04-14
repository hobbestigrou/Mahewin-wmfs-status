#!/usr/bin/env perl

use strict;
use warnings;
use Sys::Statistics::Linux;
use Sys::Statistics::Linux::DiskUsage;
use Config::IniFiles;

sub _my_home {
    if ( exists $ENV{HOME} && defined $ENV{HOME} ) {
        return $ENV{HOME};
    }

    if ( $ENV{LOGDIR} ) {
        return $ENV{LOGDIR};
    }

    return undef;
}

sub _my_infos {
    my @infos;
    open (PASSWD, "< /etc/passwd");
    while (<PASSWD>) {
        @infos = split /:/;
        last if $infos[0] eq $ENV{LOGNAME};
    }
    close(PASSWD);

    return @infos;
}

sub free {
    my $lxs = Sys::Statistics::Linux->new(
        memstats  => 1,
    );

    my $stat     = $lxs->get;
    my $memfree  = $stat->memstats->{memfree};
    my $memused  = $stat->memstats->{memused};
    my $memtotal = $stat->memstats->{memtotal};

    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format = $cfg->val('memory', 'format') || 'string';
    my $color  = $cfg->val('memory', 'color')
        ? "\\" . $cfg->val('memory', 'color') . "\\"
        : '\\' . $cfg->val('misc', 'color') . '\\';

    my $free   = $color . 'Mem: ' . int($memfree / 1024) . '/' . int($memused / 1024);

    if ( $format eq 'percent' ) {
        my $free_usage = sprintf("%0.2f", int($memused / 1024) / int($memtotal / 1024 ) * 100);
        $free = $color . 'Mem: ' . $free_usage . '%';
    }

    return $free;
}

sub disk_space {
    my $disk_usage = Sys::Statistics::Linux::DiskUsage->new(
        cmd => {
            # This is the default
            df   => 'df -hP 2>/dev/null',
        }
    );

    my $stat = $disk_usage->get;
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format    = $cfg->val('disk', 'format') || 'string';
    my $disk_path = $cfg->val('disk', 'disk_path') || '/dev/sda1';
    my $color     = $cfg->val('disk', 'color')
        ? "\\" . $cfg->val('disk', 'color') . "\\"
        : '\\' . $cfg->val('misc', 'color') . '\\';
    my $disk      = $color . 'Disk: ' . $stat->{$disk_path}->{usage} . '/' . $stat->{$disk_path}->{free};

    if ( $format eq 'percent' ) {
        my @usage = split(/G/, $stat->{$disk_path}->{usage});
        my @total = split(/G/, $stat->{$disk_path}->{total});
        $usage[0] =~ s/,/./;
        $total[0] =~ s/,/./;

        my $disk_usage = sprintf("%0.2f", $usage[0] / $total[0] * 100);
        $disk = $color . 'Disk: ' . $disk_usage . '%';
    }

    return $disk;
}

sub time_date {
    my $lxs  = Sys::Statistics::Linux->new();
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );
    my $format = $cfg->val('date', 'format') || '%Y/%m/%d %H:%M:%S';
    my $color  = $cfg->val('date', 'color')
        ? "\\" . $cfg->val('date', 'color') . "\\"
        : '\\' . $cfg->val('misc', 'color') . '\\';

    $lxs->settime($format);
    my $date_time = $color . 'Date: ' . $lxs->gettime;

    return $date_time;
}

sub name {
    my @infos = _my_infos();
    my $home  = _my_home();
    my @name  = split(/,/, $infos[4]);
    my $cfg   = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );
    my $color = $cfg->val('name', 'color')
        ? "\\" . $cfg->val('name', 'color') . "\\"
        : '\\' . $cfg->val('misc', 'color') . '\\';

    return $color . $name[0];
}

sub status {
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my @call;

    my @sections = $cfg->Sections();
    my $dispatch = {
        memory => free(),
        disk   => disk_space(),
        date   => time_date(),
        name   => name()
    };

    foreach my $section (@sections) {
        next if $section eq 'misc';

        $call[$cfg->val($section, 'position')] = $dispatch->{$section}
            if $cfg->val($section, 'display');
    }

    `wmfs -c status "default @call"`;
}

my $home = _my_home();
my $cfg  = Config::IniFiles->new(
    -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
);

my $timing = $cfg->val('misc', 'timing') || 1;

while ( 1 ) {
    sleep( $timing );
    status();
}
